-- Tier 1 Task T1-2: should_notify helper and gated notification enqueue

CREATE OR REPLACE FUNCTION public.should_notify(p_user_id uuid, p_type text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT CASE p_type
    WHEN 'session_reminder_1h' THEN COALESCE(p.session_reminders, true)
    WHEN 'session_reminder_15m' THEN COALESCE(p.session_reminders, true)
    WHEN 'waitlist_promoted' THEN COALESCE(p.waitlist_promoted, true)
    WHEN 'session_cancelled' THEN COALESCE(p.session_cancelled, true)
    WHEN 'host_player_joined' THEN COALESCE(p.host_player_joined, true)
    WHEN 'host_session_reminder_1h' THEN COALESCE(p.host_session_reminder, true)
    WHEN 'chat_message' THEN COALESCE(p.chat_messages, true)
    ELSE true
  END
  FROM (SELECT 1) _
  LEFT JOIN public.notification_preferences p ON p.user_id = p_user_id;
$$;

CREATE OR REPLACE FUNCTION public.notify_session_cancelled()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  r record;
  v_sport text;
  v_location text;
BEGIN
  IF NEW.status <> 'cancelled' OR OLD.status = 'cancelled' THEN
    RETURN NEW;
  END IF;

  v_sport := NEW.sport::text;
  SELECT COALESCE(v.name, NEW.custom_location, 'campus')
  INTO v_location
  FROM public.venues v WHERE v.id = NEW.venue_id;

  FOR r IN
    SELECT sp.user_id
    FROM public.session_participants sp
    WHERE sp.session_id = NEW.id
      AND sp.status IN ('joined', 'waitlist')
  LOOP
    IF public.should_notify(r.user_id, 'session_cancelled') THEN
      PERFORM public.enqueue_notification(
        r.user_id,
        NEW.id,
        'session_cancelled',
        'Game cancelled',
        format('%s at %s was cancelled by the host.', v_sport, v_location),
        format('session_cancelled:%s:%s', NEW.id, r.user_id)
      );
    END IF;
  END LOOP;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.leave_session(p_session_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_prev_status participant_status;
  v_promoted_user uuid;
  v_sport text;
  v_location text;
BEGIN
  SELECT status INTO v_prev_status
  FROM public.session_participants
  WHERE session_id = p_session_id AND user_id = auth.uid();

  IF NOT FOUND THEN
    RETURN;
  END IF;

  UPDATE public.session_participants
  SET status = 'left'
  WHERE session_id = p_session_id AND user_id = auth.uid();

  IF v_prev_status = 'joined' THEN
    UPDATE public.sessions
    SET player_count = GREATEST(0, player_count - 1),
        status = 'open'
    WHERE id = p_session_id AND status = 'full';

    WITH next_wait AS (
      SELECT user_id FROM public.session_participants
      WHERE session_id = p_session_id AND status = 'waitlist'
      ORDER BY joined_at ASC
      LIMIT 1
    )
    UPDATE public.session_participants sp
    SET status = 'joined'
    FROM next_wait nw
    WHERE sp.session_id = p_session_id AND sp.user_id = nw.user_id
    RETURNING sp.user_id INTO v_promoted_user;

    UPDATE public.sessions
    SET player_count = player_count + 1,
        status = CASE
          WHEN player_count + 1 >= capacity THEN 'full'::session_status
          ELSE status
        END
    WHERE id = p_session_id
      AND v_promoted_user IS NOT NULL;

    IF v_promoted_user IS NOT NULL THEN
      SELECT s.sport::text, COALESCE(v.name, s.custom_location, 'campus')
      INTO v_sport, v_location
      FROM public.sessions s
      LEFT JOIN public.venues v ON v.id = s.venue_id
      WHERE s.id = p_session_id;

      IF public.should_notify(v_promoted_user, 'waitlist_promoted') THEN
        PERFORM public.enqueue_notification(
          v_promoted_user,
          p_session_id,
          'waitlist_promoted',
          'You''re in!',
          format('A spot opened for %s at %s.', v_sport, v_location),
          format('waitlist_promoted:%s:%s', p_session_id, v_promoted_user)
        );
      END IF;
    END IF;
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.enqueue_session_reminders(p_window text)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count int := 0;
  r record;
  v_type text;
  v_title text;
  v_body text;
  v_interval interval;
BEGIN
  IF p_window = '1h' THEN
    v_type := 'session_reminder_1h';
    v_title := 'Game in 1 hour';
    v_interval := interval '1 hour';
  ELSIF p_window = '15m' THEN
    v_type := 'session_reminder_15m';
    v_title := 'Game in 15 minutes';
    v_interval := interval '15 minutes';
  ELSE
    RAISE EXCEPTION 'invalid_window';
  END IF;

  FOR r IN
    SELECT s.id AS session_id, sp.user_id, s.sport::text AS sport,
           COALESCE(v.name, s.custom_location, 'campus') AS location
    FROM public.sessions s
    JOIN public.session_participants sp ON sp.session_id = s.id
    LEFT JOIN public.venues v ON v.id = s.venue_id
    WHERE s.status IN ('open', 'full')
      AND sp.status IN ('joined', 'waitlist')
      AND s.starts_at > now()
      AND s.starts_at <= now() + v_interval + interval '5 minutes'
      AND s.starts_at > now() + v_interval - interval '5 minutes'
  LOOP
    IF public.should_notify(r.user_id, v_type) THEN
      v_body := format('%s at %s starts soon.', r.sport, r.location);
      PERFORM public.enqueue_notification(
        r.user_id,
        r.session_id,
        v_type,
        v_title,
        v_body,
        format('%s:%s:%s', v_type, r.session_id, r.user_id)
      );
      v_count := v_count + 1;
    END IF;
  END LOOP;

  RETURN v_count;
END;
$$;
