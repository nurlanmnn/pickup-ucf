-- Keep every device's activity token and push schedule/start/end changes silently.
ALTER TABLE public.live_activity_tokens DROP CONSTRAINT live_activity_tokens_pkey;
ALTER TABLE public.live_activity_tokens ADD PRIMARY KEY (apns_token);
CREATE INDEX idx_live_activity_tokens_owner_session
  ON public.live_activity_tokens (user_id, session_id);
ALTER TABLE public.live_activity_tokens
  ADD COLUMN needs_update boolean NOT NULL DEFAULT true,
  ADD COLUMN started_at timestamptz;

-- End activities registered under the previous 24-hour/waitlist policy too.
UPDATE public.live_activity_tokens t
SET ends_at = now(), needs_update = true, updated_at = now()
WHERE ended_at IS NULL AND NOT EXISTS (
  SELECT 1 FROM public.sessions s
  WHERE s.id = t.session_id AND s.status IN ('open', 'full')
    AND s.ends_at > now() AND s.starts_at <= now() + interval '1 hour'
    AND (s.host_id = t.user_id OR EXISTS (
      SELECT 1 FROM public.session_participants sp
      WHERE sp.session_id = s.id AND sp.user_id = t.user_id AND sp.status = 'joined'
    ))
);

CREATE OR REPLACE FUNCTION public.register_live_activity_token(
  p_session_id uuid,
  p_apns_token text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_session public.sessions%ROWTYPE;
  v_token text := lower(trim(p_apns_token));
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  IF v_token IS NULL
     OR length(v_token) < 32
     OR length(v_token) > 512
     OR length(v_token) % 2 <> 0
     OR v_token !~ '^[0-9a-f]+$' THEN
    RAISE EXCEPTION 'invalid_live_activity_token';
  END IF;

  SELECT s.*
  INTO v_session
  FROM public.sessions s
  WHERE s.id = p_session_id
    AND s.status IN ('open', 'full')
    AND s.ends_at > now()
    AND s.starts_at <= now() + interval '1 hour'
    AND (
      s.host_id = v_user_id
      OR EXISTS (
        SELECT 1
        FROM public.session_participants sp
        WHERE sp.session_id = s.id
          AND sp.user_id = v_user_id
          AND sp.status = 'joined'
      )
    );

  IF NOT FOUND THEN
    RAISE EXCEPTION 'live_activity_session_not_available';
  END IF;

  IF EXISTS (SELECT 1 FROM public.live_activity_tokens
    WHERE apns_token = v_token AND (user_id <> v_user_id OR session_id <> p_session_id)) THEN
    RAISE EXCEPTION 'invalid_live_activity_token';
  END IF;

  INSERT INTO public.live_activity_tokens (
    user_id,
    session_id,
    apns_token,
    starts_at,
    ends_at,
    ended_at,
    updated_at
  ) VALUES (
    v_user_id,
    v_session.id,
    v_token,
    v_session.starts_at,
    v_session.ends_at,
    NULL,
    now()
  )
  ON CONFLICT (apns_token) DO UPDATE
  SET apns_token = EXCLUDED.apns_token,
      starts_at = EXCLUDED.starts_at,
      ends_at = EXCLUDED.ends_at,
      needs_update = true,
      started_at = NULL,
      updated_at = now()
  WHERE live_activity_tokens.user_id = v_user_id
    AND live_activity_tokens.session_id = p_session_id
    AND live_activity_tokens.ended_at IS NULL
    AND live_activity_tokens.ends_at > now()
    AND (live_activity_tokens.starts_at, live_activity_tokens.ends_at)
        IS DISTINCT FROM (EXCLUDED.starts_at, EXCLUDED.ends_at);
END;
$$;

REVOKE ALL ON FUNCTION public.register_live_activity_token(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.register_live_activity_token(uuid, text) TO authenticated;


CREATE OR REPLACE FUNCTION public.sync_live_activity_session_schedule()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE public.live_activity_tokens
  SET starts_at = NEW.starts_at,
      ends_at = CASE
        WHEN live_activity_tokens.ends_at <= now()
          OR NEW.status IN ('cancelled', 'completed')
          OR NOT (NEW.host_id = live_activity_tokens.user_id OR EXISTS (
            SELECT 1 FROM public.session_participants sp
            WHERE sp.session_id = NEW.id AND sp.user_id = live_activity_tokens.user_id
              AND sp.status = 'joined'
          ))
          OR NEW.starts_at > now() + interval '1 hour'
          OR (NEW.sport, NEW.custom_sport_name, NEW.venue_id, NEW.custom_location)
             IS DISTINCT FROM (OLD.sport, OLD.custom_sport_name, OLD.venue_id, OLD.custom_location)
        THEN now()
        ELSE NEW.ends_at
      END,
      needs_update = true,
      started_at = NULL,
      updated_at = now()
  WHERE session_id = NEW.id AND ended_at IS NULL;

  -- Keep unsent reminders tied to the current schedule.
  UPDATE public.notification_outbox
  SET payload = payload || jsonb_build_object(
    'session_starts_at', NEW.starts_at, 'session_ends_at', NEW.ends_at)
  WHERE session_id = NEW.id AND sent_at IS NULL;
  IF NEW.status IN ('cancelled', 'completed') THEN
    DELETE FROM public.notification_outbox
    WHERE session_id = NEW.id AND sent_at IS NULL
      AND type IN ('session_reminder_1h', 'host_session_reminder_1h', 'session_reminder_15m');
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER sync_live_activity_session_schedule ON public.sessions;
CREATE TRIGGER sync_live_activity_session_schedule
  AFTER UPDATE OF starts_at, ends_at, status, sport, custom_sport_name, venue_id, custom_location
  ON public.sessions FOR EACH ROW
  WHEN ((OLD.starts_at, OLD.ends_at, OLD.status, OLD.sport, OLD.custom_sport_name, OLD.venue_id, OLD.custom_location)
    IS DISTINCT FROM (NEW.starts_at, NEW.ends_at, NEW.status, NEW.sport, NEW.custom_sport_name, NEW.venue_id, NEW.custom_location))
  EXECUTE FUNCTION public.sync_live_activity_session_schedule();

CREATE FUNCTION public.end_departed_player_activities()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE public.live_activity_tokens
  SET ends_at = now(), needs_update = true, updated_at = now()
  WHERE session_id = OLD.session_id AND user_id = OLD.user_id AND ended_at IS NULL;
  DELETE FROM public.notification_outbox
  WHERE session_id = OLD.session_id AND user_id = OLD.user_id AND sent_at IS NULL
    AND type IN ('session_reminder_1h', 'session_reminder_15m');
  RETURN NULL;
END;
$$;
REVOKE ALL ON FUNCTION public.end_departed_player_activities() FROM PUBLIC;
CREATE TRIGGER end_departed_player_activities_update
  AFTER UPDATE OF status ON public.session_participants FOR EACH ROW
  WHEN (OLD.status = 'joined' AND NEW.status <> 'joined')
  EXECUTE FUNCTION public.end_departed_player_activities();
CREATE TRIGGER end_departed_player_activities_delete
  AFTER DELETE ON public.session_participants FOR EACH ROW
  EXECUTE FUNCTION public.end_departed_player_activities();

DROP FUNCTION IF EXISTS public.enqueue_notification(uuid, uuid, text, text, text, text);
CREATE OR REPLACE FUNCTION public.enqueue_notification(
  p_user_id uuid, p_session_id uuid, p_type text, p_title text, p_body text, p_dedupe_key text,
  p_payload_extras jsonb DEFAULT '{}'::jsonb
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.notification_outbox (user_id, session_id, type, title, body, payload, dedupe_key)
  VALUES (p_user_id, p_session_id, p_type, p_title, p_body,
    p_payload_extras || jsonb_build_object('session_id', p_session_id) || COALESCE((
      SELECT jsonb_build_object('session_starts_at', starts_at, 'session_ends_at', ends_at)
      FROM public.sessions WHERE id = p_session_id
    ), '{}'::jsonb), p_dedupe_key)
  ON CONFLICT (dedupe_key) DO NOTHING;
END;
$$;

REVOKE ALL ON FUNCTION public.enqueue_notification(uuid, uuid, text, text, text, text, jsonb) FROM PUBLIC;

-- Give already-queued notifications the same canonical timestamps as new ones.
UPDATE public.notification_outbox n
SET payload = n.payload || jsonb_build_object(
  'session_starts_at', s.starts_at, 'session_ends_at', s.ends_at)
FROM public.sessions s
WHERE n.session_id = s.id AND n.sent_at IS NULL;

-- Silent cleanup supplements local foreground cleanup; it does not show an alert.
CREATE FUNCTION public.enqueue_finished_session_cleanup()
RETURNS int LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_count int;
BEGIN
  INSERT INTO public.notification_outbox (user_id, session_id, type, title, body, payload, dedupe_key)
  SELECT recipients.user_id, s.id, 'session_finished', '', '',
    jsonb_build_object('session_id', s.id, 'session_ends_at', s.ends_at),
    format('session_finished:%s:%s', s.id, recipients.user_id)
  FROM public.sessions s
  CROSS JOIN LATERAL (
    SELECT s.host_id AS user_id
    UNION SELECT user_id FROM public.session_participants WHERE session_id = s.id
    UNION SELECT user_id FROM public.notification_outbox WHERE session_id = s.id AND type <> 'session_finished'
  ) recipients
  WHERE (s.ends_at <= now() OR s.status IN ('completed', 'cancelled'))
    AND s.ends_at > now() - interval '1 day'
  ON CONFLICT (dedupe_key) DO NOTHING;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;
REVOKE ALL ON FUNCTION public.enqueue_finished_session_cleanup() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.enqueue_finished_session_cleanup() TO service_role;
SELECT cron.schedule('pickup-session-cleanup', '* * * * *',
  'SELECT public.complete_expired_sessions(); SELECT public.enqueue_finished_session_cleanup();');
