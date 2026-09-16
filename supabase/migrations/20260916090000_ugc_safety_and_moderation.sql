-- EXT-01: authoritative UGC policy, typed reports, broad blocking, and moderation.

CREATE TYPE public.report_target_type AS ENUM ('session', 'message', 'user');
CREATE TYPE public.report_category AS ENUM (
  'harassment', 'hate', 'threat', 'sexual_content', 'spam',
  'impersonation', 'unsafe_behavior', 'other'
);
CREATE TYPE public.moderation_report_status AS ENUM ('pending', 'in_review', 'resolved', 'dismissed');
CREATE TYPE public.moderation_action_type AS ENUM (
  'dismiss', 'remove_content', 'warn_user', 'suspend_user', 'resolve'
);

CREATE TABLE public.moderator_accounts (
  user_id uuid PRIMARY KEY REFERENCES public.profiles (id) ON DELETE CASCADE,
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.user_moderation_state (
  user_id uuid PRIMARY KEY REFERENCES public.profiles (id) ON DELETE CASCADE,
  suspended_until timestamptz,
  reason text CHECK (reason IS NULL OR length(reason) BETWEEN 10 AND 500),
  updated_by uuid,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.moderation_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id uuid NOT NULL,
  target_type public.report_target_type NOT NULL,
  target_session_id uuid,
  target_message_id uuid,
  target_user_id uuid,
  subject_user_id uuid,
  category public.report_category NOT NULL,
  context text CHECK (context IS NULL OR length(context) BETWEEN 10 AND 500),
  target_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
  status public.moderation_report_status NOT NULL DEFAULT 'pending',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (
    (target_type = 'session' AND target_session_id IS NOT NULL AND target_message_id IS NULL AND target_user_id IS NULL)
    OR (target_type = 'message' AND target_session_id IS NULL AND target_message_id IS NOT NULL AND target_user_id IS NULL)
    OR (target_type = 'user' AND target_session_id IS NULL AND target_message_id IS NULL AND target_user_id IS NOT NULL)
  )
);

CREATE UNIQUE INDEX moderation_reports_open_session_unique
  ON public.moderation_reports (reporter_id, target_session_id)
  WHERE target_type = 'session' AND status IN ('pending', 'in_review');
CREATE UNIQUE INDEX moderation_reports_open_message_unique
  ON public.moderation_reports (reporter_id, target_message_id)
  WHERE target_type = 'message' AND status IN ('pending', 'in_review');
CREATE UNIQUE INDEX moderation_reports_open_user_unique
  ON public.moderation_reports (reporter_id, target_user_id)
  WHERE target_type = 'user' AND status IN ('pending', 'in_review');
CREATE INDEX moderation_reports_queue_idx ON public.moderation_reports (status, created_at);
CREATE INDEX moderation_reports_reporter_rate_idx ON public.moderation_reports (reporter_id, created_at);

CREATE TABLE public.moderation_actions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id uuid NOT NULL REFERENCES public.moderation_reports (id) ON DELETE CASCADE,
  moderator_id uuid NOT NULL,
  action public.moderation_action_type NOT NULL,
  reason text NOT NULL CHECK (length(reason) BETWEEN 10 AND 500),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.user_moderation_notices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  report_id uuid REFERENCES public.moderation_reports (id) ON DELETE SET NULL,
  kind public.moderation_action_type NOT NULL CHECK (kind IN ('warn_user', 'suspend_user')),
  message text NOT NULL CHECK (length(message) BETWEEN 10 AND 500),
  created_at timestamptz NOT NULL DEFAULT now(),
  acknowledged_at timestamptz
);

ALTER TABLE public.moderator_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_moderation_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.moderation_reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.moderation_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_moderation_notices ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.moderator_accounts FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.user_moderation_state FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.moderation_reports FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.moderation_actions FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.user_moderation_notices FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.is_current_user_moderator()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT auth.uid() IS NOT NULL
    AND EXISTS (SELECT 1 FROM public.moderator_accounts WHERE user_id = auth.uid());
$$;

REVOKE ALL ON FUNCTION public.is_current_user_moderator() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_current_user_moderator() TO authenticated;

CREATE OR REPLACE FUNCTION public.is_user_suspended(p_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_moderation_state
    WHERE user_id = p_user_id AND suspended_until > now()
  );
$$;

CREATE OR REPLACE FUNCTION public.users_are_blocked(p_first uuid, p_second uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT p_first IS NOT NULL AND p_second IS NOT NULL AND p_first <> p_second
    AND EXISTS (
      SELECT 1 FROM public.user_blocks
      WHERE (blocker_id = p_first AND blocked_id = p_second)
         OR (blocker_id = p_second AND blocked_id = p_first)
    );
$$;

REVOKE ALL ON FUNCTION public.is_user_suspended(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.users_are_blocked(uuid, uuid) FROM PUBLIC;

CREATE OR REPLACE FUNCTION public.assert_user_content(p_value text, p_field text)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public
AS $$
DECLARE
  v_value text;
  v_folded text;
  v_max int;
BEGIN
  IF p_value IS NULL THEN RETURN NULL; END IF;
  v_value := regexp_replace(trim(p_value), '[[:space:]]+', ' ', 'g');
  v_max := CASE p_field
    WHEN 'display_name' THEN 80
    WHEN 'session_notes' THEN 1000
    WHEN 'custom_sport' THEN 40
    WHEN 'custom_location' THEN 120
    WHEN 'chat_message' THEN 500
    WHEN 'report_context' THEN 500
    ELSE 500
  END;
  IF length(v_value) > v_max OR v_value ~ '[[:cntrl:]]' THEN
    RAISE EXCEPTION 'user_content_rejected';
  END IF;

  v_folded := lower(translate(v_value, '013', 'oie'));
  IF v_folded ~ '(i|we) (will|am going to|are going to|gonna) (kill|hurt|shoot|stab) (you|u|him|her|them)'
     OR v_folded ~ '(send|show) (me )?(nude|nudes|explicit photos)'
     OR v_folded ~ '(n[i1]gg+[e3]r|f[a@]gg+[o0]t|k[i1]k[e3])'
     OR lower(v_value) ~ 'https?://|www\.'
     OR lower(v_value) ~ '(text|call) me (at )?[+]?[0-9][0-9 ().-]{8,}[0-9]' THEN
    RAISE EXCEPTION 'user_content_rejected';
  END IF;
  RETURN v_value;
END;
$$;

REVOKE ALL ON FUNCTION public.assert_user_content(text, text) FROM PUBLIC;

CREATE OR REPLACE FUNCTION public.enforce_user_content()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF public.is_user_suspended(auth.uid()) THEN RAISE EXCEPTION 'account_suspended'; END IF;

  IF TG_TABLE_NAME = 'profiles' THEN
    NEW.display_name := public.assert_user_content(NEW.display_name, 'display_name');
  ELSIF TG_TABLE_NAME = 'sessions' THEN
    NEW.notes := public.assert_user_content(NEW.notes, 'session_notes');
    NEW.custom_sport_name := public.assert_user_content(NEW.custom_sport_name, 'custom_sport');
    NEW.custom_location := public.assert_user_content(NEW.custom_location, 'custom_location');
  ELSIF TG_TABLE_NAME = 'messages' THEN
    NEW.body := public.assert_user_content(NEW.body, 'chat_message');
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER profiles_enforce_user_content
  BEFORE INSERT OR UPDATE OF display_name ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.enforce_user_content();
CREATE TRIGGER sessions_enforce_user_content
  BEFORE INSERT OR UPDATE OF notes, custom_sport_name, custom_location ON public.sessions
  FOR EACH ROW EXECUTE FUNCTION public.enforce_user_content();
CREATE TRIGGER messages_enforce_user_content
  BEFORE INSERT OR UPDATE OF body ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.enforce_user_content();

DROP POLICY IF EXISTS profiles_select ON public.profiles;
CREATE POLICY profiles_select ON public.profiles
  FOR SELECT TO authenticated
  USING (
    public.is_ucf_email()
    AND (id = auth.uid() OR NOT public.users_are_blocked(auth.uid(), id))
  );

DROP POLICY IF EXISTS profiles_insert ON public.profiles;
CREATE POLICY profiles_insert ON public.profiles
  FOR INSERT TO authenticated
  WITH CHECK (
    id = auth.uid() AND public.is_ucf_email()
    AND NOT public.is_user_suspended(auth.uid())
  );

DROP POLICY IF EXISTS profiles_update ON public.profiles;
CREATE POLICY profiles_update ON public.profiles
  FOR UPDATE TO authenticated
  USING (id = auth.uid() AND NOT public.is_user_suspended(auth.uid()))
  WITH CHECK (id = auth.uid() AND NOT public.is_user_suspended(auth.uid()));

DROP POLICY IF EXISTS sessions_select ON public.sessions;
CREATE POLICY sessions_select ON public.sessions
  FOR SELECT TO authenticated
  USING (
    public.is_ucf_email()
    AND NOT public.users_are_blocked(auth.uid(), host_id)
    AND (
      (status IN ('open', 'full') AND starts_at > now())
      OR host_id = auth.uid()
      OR public.is_session_participant(id)
    )
  );

DROP POLICY IF EXISTS sessions_insert ON public.sessions;
CREATE POLICY sessions_insert ON public.sessions
  FOR INSERT TO authenticated
  WITH CHECK (
    host_id = auth.uid() AND public.is_ucf_email()
    AND NOT public.is_user_suspended(auth.uid())
  );

DROP POLICY IF EXISTS sessions_update ON public.sessions;
CREATE POLICY sessions_update ON public.sessions
  FOR UPDATE TO authenticated
  USING (host_id = auth.uid() AND NOT public.is_user_suspended(auth.uid()))
  WITH CHECK (host_id = auth.uid() AND NOT public.is_user_suspended(auth.uid()));

DROP POLICY IF EXISTS participants_select ON public.session_participants;
CREATE POLICY participants_select ON public.session_participants
  FOR SELECT TO authenticated
  USING (
    public.is_ucf_email()
    AND NOT public.users_are_blocked(auth.uid(), user_id)
  );

DROP POLICY IF EXISTS participants_insert ON public.session_participants;
CREATE POLICY participants_insert ON public.session_participants
  FOR INSERT TO authenticated
  WITH CHECK (
    user_id = auth.uid()
    AND NOT public.is_user_suspended(auth.uid())
    AND NOT EXISTS (
      SELECT 1 FROM public.sessions s
      WHERE s.id = session_id AND public.users_are_blocked(auth.uid(), s.host_id)
    )
  );

DROP POLICY IF EXISTS messages_select ON public.messages;
CREATE POLICY messages_select ON public.messages
  FOR SELECT TO authenticated
  USING (
    public.is_session_participant(session_id)
    AND NOT public.users_are_blocked(auth.uid(), user_id)
    AND NOT EXISTS (
      SELECT 1 FROM public.sessions s
      WHERE s.id = session_id AND public.users_are_blocked(auth.uid(), s.host_id)
    )
  );

DROP POLICY IF EXISTS messages_insert ON public.messages;
CREATE POLICY messages_insert ON public.messages
  FOR INSERT TO authenticated
  WITH CHECK (
    user_id = auth.uid()
    AND NOT public.is_user_suspended(auth.uid())
    AND public.is_session_participant(session_id)
    AND NOT EXISTS (
      SELECT 1 FROM public.sessions s
      WHERE s.id = session_id AND public.users_are_blocked(auth.uid(), s.host_id)
    )
  );

CREATE OR REPLACE FUNCTION public.list_blocked_users()
RETURNS TABLE (id uuid, display_name text, username text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT p.id, p.display_name, p.username
  FROM public.user_blocks b
  JOIN public.profiles p ON p.id = b.blocked_id
  WHERE b.blocker_id = auth.uid()
  ORDER BY b.created_at DESC;
$$;
REVOKE ALL ON FUNCTION public.list_blocked_users() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.list_blocked_users() TO authenticated;

CREATE OR REPLACE FUNCTION public.submit_moderation_report(
  p_target_type public.report_target_type,
  p_target_id uuid,
  p_category public.report_category,
  p_context text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_report_id uuid;
  v_context text;
  v_subject_user_id uuid;
  v_snapshot jsonb;
  v_hour_count int;
  v_day_count int;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  IF public.is_user_suspended(auth.uid()) THEN RAISE EXCEPTION 'account_suspended'; END IF;
  IF p_target_id IS NULL THEN RAISE EXCEPTION 'invalid_report_target'; END IF;

  v_context := public.assert_user_content(p_context, 'report_context');
  IF v_context IS NOT NULL AND length(v_context) < 10 THEN RAISE EXCEPTION 'report_context_too_short'; END IF;

  SELECT count(*) FILTER (WHERE created_at > now() - interval '1 hour'),
         count(*) FILTER (WHERE created_at > now() - interval '1 day')
  INTO v_hour_count, v_day_count
  FROM public.moderation_reports WHERE reporter_id = auth.uid();
  IF v_hour_count >= 5 OR v_day_count >= 20 THEN RAISE EXCEPTION 'report_rate_limited'; END IF;

  IF p_target_type = 'session' THEN
    SELECT host_id,
           jsonb_build_object('sport', sport::text, 'notes', left(COALESCE(notes, ''), 500), 'status', status::text)
    INTO v_subject_user_id, v_snapshot FROM public.sessions WHERE id = p_target_id;
  ELSIF p_target_type = 'message' THEN
    SELECT user_id,
           jsonb_build_object('session_id', session_id, 'body', left(body, 500), 'created_at', created_at)
    INTO v_subject_user_id, v_snapshot FROM public.messages WHERE id = p_target_id;
  ELSE
    SELECT id, jsonb_build_object('display_name', display_name, 'username', username)
    INTO v_subject_user_id, v_snapshot FROM public.profiles WHERE id = p_target_id;
  END IF;

  IF v_subject_user_id IS NULL THEN RAISE EXCEPTION 'report_target_not_found'; END IF;
  IF v_subject_user_id = auth.uid() THEN RAISE EXCEPTION 'invalid_report_target'; END IF;

  INSERT INTO public.moderation_reports (
    reporter_id, target_type, target_session_id, target_message_id, target_user_id,
    subject_user_id, category, context, target_snapshot
  ) VALUES (
    auth.uid(), p_target_type,
    CASE WHEN p_target_type = 'session' THEN p_target_id END,
    CASE WHEN p_target_type = 'message' THEN p_target_id END,
    CASE WHEN p_target_type = 'user' THEN p_target_id END,
    v_subject_user_id, p_category, v_context, v_snapshot
  ) RETURNING id INTO v_report_id;

  RETURN v_report_id;
EXCEPTION
  WHEN unique_violation THEN RAISE EXCEPTION 'report_already_submitted';
END;
$$;

CREATE OR REPLACE FUNCTION public.list_my_moderation_reports()
RETURNS TABLE (id uuid, target_type public.report_target_type, category public.report_category, status public.moderation_report_status, created_at timestamptz)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT r.id, r.target_type, r.category, r.status, r.created_at
  FROM public.moderation_reports r
  WHERE r.reporter_id = auth.uid()
  ORDER BY r.created_at DESC;
$$;

CREATE OR REPLACE FUNCTION public.list_moderation_reports(p_limit int DEFAULT 50)
RETURNS TABLE (
  id uuid, target_type public.report_target_type, target_id uuid,
  category public.report_category, context text, target_summary text,
  status public.moderation_report_status, subject_user_id uuid, created_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_current_user_moderator() THEN RAISE EXCEPTION 'moderator_required'; END IF;
  RETURN QUERY
  SELECT r.id, r.target_type,
         COALESCE(r.target_session_id, r.target_message_id, r.target_user_id),
         r.category, r.context,
         COALESCE(
           r.target_snapshot ->> 'body',
           r.target_snapshot ->> 'display_name',
           r.target_snapshot ->> 'sport',
           'Content unavailable'
         ),
         r.status, r.subject_user_id, r.created_at
  FROM public.moderation_reports r
  WHERE r.status IN ('pending', 'in_review')
  ORDER BY r.created_at ASC
  LIMIT LEAST(GREATEST(COALESCE(p_limit, 50), 1), 100);
END;
$$;

CREATE OR REPLACE FUNCTION public.list_my_moderation_notices()
RETURNS TABLE (id uuid, kind public.moderation_action_type, message text, created_at timestamptz)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT n.id, n.kind, n.message, n.created_at
  FROM public.user_moderation_notices n
  WHERE n.user_id = auth.uid() AND n.acknowledged_at IS NULL
  ORDER BY n.created_at ASC;
$$;

CREATE OR REPLACE FUNCTION public.acknowledge_moderation_notice(p_notice_id uuid)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  UPDATE public.user_moderation_notices
  SET acknowledged_at = now()
  WHERE id = p_notice_id AND user_id = auth.uid();
$$;

CREATE OR REPLACE FUNCTION public.moderate_report(
  p_report_id uuid,
  p_action public.moderation_action_type,
  p_reason text,
  p_suspension_hours int DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_report public.moderation_reports%ROWTYPE;
  v_reason text;
BEGIN
  IF NOT public.is_current_user_moderator() THEN RAISE EXCEPTION 'moderator_required'; END IF;
  v_reason := public.assert_user_content(p_reason, 'report_context');
  IF v_reason IS NULL OR length(v_reason) < 10 THEN RAISE EXCEPTION 'moderation_reason_required'; END IF;

  SELECT * INTO v_report FROM public.moderation_reports WHERE id = p_report_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'report_not_found'; END IF;
  IF v_report.status IN ('resolved', 'dismissed') THEN RAISE EXCEPTION 'report_already_closed'; END IF;

  IF p_action = 'remove_content' THEN
    IF v_report.target_type = 'message' THEN
      DELETE FROM public.messages WHERE id = v_report.target_message_id;
    ELSIF v_report.target_type = 'session' THEN
      UPDATE public.sessions SET notes = NULL, status = 'cancelled' WHERE id = v_report.target_session_id;
    ELSE
      UPDATE public.profiles SET display_name = 'PickUp UCF User', username = NULL WHERE id = v_report.target_user_id;
    END IF;
  ELSIF p_action = 'warn_user' THEN
    INSERT INTO public.user_moderation_notices (user_id, report_id, kind, message)
    VALUES (v_report.subject_user_id, v_report.id, p_action, v_reason);
  ELSIF p_action = 'suspend_user' THEN
    IF p_suspension_hours IS NULL OR p_suspension_hours NOT BETWEEN 1 AND 2160 THEN
      RAISE EXCEPTION 'invalid_suspension_duration';
    END IF;
    INSERT INTO public.user_moderation_state (user_id, suspended_until, reason, updated_by, updated_at)
    VALUES (v_report.subject_user_id, now() + make_interval(hours => p_suspension_hours), v_reason, auth.uid(), now())
    ON CONFLICT (user_id) DO UPDATE SET
      suspended_until = EXCLUDED.suspended_until,
      reason = EXCLUDED.reason,
      updated_by = EXCLUDED.updated_by,
      updated_at = now();
    INSERT INTO public.user_moderation_notices (user_id, report_id, kind, message)
    VALUES (v_report.subject_user_id, v_report.id, p_action, v_reason);
  END IF;

  INSERT INTO public.moderation_actions (report_id, moderator_id, action, reason)
  VALUES (v_report.id, auth.uid(), p_action, v_reason);
  UPDATE public.moderation_reports
  SET status = CASE WHEN p_action = 'dismiss' THEN 'dismissed'::public.moderation_report_status ELSE 'resolved'::public.moderation_report_status END,
      updated_at = now()
  WHERE id = v_report.id;
END;
$$;

REVOKE ALL ON FUNCTION public.submit_moderation_report(public.report_target_type, uuid, public.report_category, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.list_my_moderation_reports() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.list_moderation_reports(int) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.list_my_moderation_notices() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.acknowledge_moderation_notice(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.moderate_report(uuid, public.moderation_action_type, text, int) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_moderation_report(public.report_target_type, uuid, public.report_category, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_my_moderation_reports() TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_moderation_reports(int) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_my_moderation_notices() TO authenticated;
GRANT EXECUTE ON FUNCTION public.acknowledge_moderation_notice(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.moderate_report(uuid, public.moderation_action_type, text, int) TO authenticated;

CREATE OR REPLACE FUNCTION public.join_session(p_session_id uuid)
RETURNS participant_status
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_capacity int;
  v_count int;
  v_host_id uuid;
  v_session_status session_status;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  IF public.is_user_suspended(auth.uid()) THEN RAISE EXCEPTION 'account_suspended'; END IF;

  SELECT capacity, player_count, status, host_id
  INTO v_capacity, v_count, v_session_status, v_host_id
  FROM public.sessions WHERE id = p_session_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'session_not_found'; END IF;
  IF v_session_status NOT IN ('open', 'full') THEN RAISE EXCEPTION 'session_not_joinable'; END IF;
  IF public.users_are_blocked(v_host_id, auth.uid()) THEN RAISE EXCEPTION 'user_blocked'; END IF;

  IF EXISTS (
    SELECT 1 FROM public.session_participants
    WHERE session_id = p_session_id AND user_id = auth.uid() AND status = 'joined'
  ) THEN RETURN 'joined'::public.participant_status; END IF;

  IF v_count < v_capacity THEN
    INSERT INTO public.session_participants (session_id, user_id, role, status)
    VALUES (p_session_id, auth.uid(), 'player', 'joined')
    ON CONFLICT (session_id, user_id) DO UPDATE SET status = 'joined', joined_at = now();
    UPDATE public.sessions
    SET player_count = player_count + 1,
        status = CASE WHEN player_count + 1 >= capacity THEN 'full'::session_status ELSE status END
    WHERE id = p_session_id;
    RETURN 'joined'::public.participant_status;
  END IF;

  INSERT INTO public.session_participants (session_id, user_id, role, status)
  VALUES (p_session_id, auth.uid(), 'player', 'waitlist')
  ON CONFLICT (session_id, user_id) DO UPDATE SET status = 'waitlist', joined_at = now();
  RETURN 'waitlist'::public.participant_status;
END;
$$;

CREATE OR REPLACE FUNCTION public.guard_blocked_notification()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor uuid;
BEGIN
  v_actor := NULLIF(NEW.payload ->> 'actor_user_id', '')::uuid;
  IF v_actor IS NULL AND NEW.session_id IS NOT NULL THEN
    SELECT host_id INTO v_actor FROM public.sessions WHERE id = NEW.session_id;
  END IF;
  IF public.is_user_suspended(v_actor)
     OR public.users_are_blocked(NEW.user_id, v_actor) THEN RETURN NULL; END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER notification_outbox_block_guard
  BEFORE INSERT ON public.notification_outbox
  FOR EACH ROW EXECUTE FUNCTION public.guard_blocked_notification();

CREATE OR REPLACE FUNCTION public.notify_chat_message()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  r record;
  v_sender_name text;
  v_sport text;
BEGIN
  SELECT display_name INTO v_sender_name FROM public.profiles WHERE id = NEW.user_id;
  SELECT sport::text INTO v_sport FROM public.sessions WHERE id = NEW.session_id;
  FOR r IN
    SELECT sp.user_id FROM public.session_participants sp
    WHERE sp.session_id = NEW.session_id AND sp.status IN ('joined', 'waitlist') AND sp.user_id <> NEW.user_id
  LOOP
    IF public.should_notify(r.user_id, 'chat_message') THEN
      PERFORM public.enqueue_notification(
        r.user_id, NEW.session_id, 'chat_message',
        format('New message · %s', COALESCE(v_sport, 'Session')),
        format('%s: %s', COALESCE(v_sender_name, 'Someone'), left(NEW.body, 80)),
        format('chat_message:%s:%s', NEW.session_id, NEW.id),
        jsonb_build_object('message_id', NEW.id, 'open_chat', true, 'actor_user_id', NEW.user_id)
      );
    END IF;
  END LOOP;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.notify_host_player_joined()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_host_id uuid;
  v_joiner_name text;
  v_sport text;
BEGIN
  IF NEW.status <> 'joined' OR NEW.role = 'host' THEN RETURN NEW; END IF;
  SELECT s.host_id, s.sport::text INTO v_host_id, v_sport FROM public.sessions s WHERE s.id = NEW.session_id;
  IF v_host_id IS NULL OR v_host_id = NEW.user_id THEN RETURN NEW; END IF;
  SELECT display_name INTO v_joiner_name FROM public.profiles WHERE id = NEW.user_id;
  IF public.should_notify(v_host_id, 'host_player_joined') THEN
    PERFORM public.enqueue_notification(
      v_host_id, NEW.session_id, 'host_player_joined', 'Player joined',
      format('%s joined your %s game.', COALESCE(v_joiner_name, 'Someone'), v_sport),
      format('host_player_joined:%s:%s:%s', NEW.session_id, NEW.user_id, NEW.joined_at),
      jsonb_build_object('actor_user_id', NEW.user_id)
    );
  END IF;
  RETURN NEW;
END;
$$;
