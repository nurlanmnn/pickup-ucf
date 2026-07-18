-- Core loop reliability: notifications, attendance, session lifecycle

CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions;

-- Notification outbox (service role / Edge Function only)
CREATE TABLE public.notification_outbox (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  session_id uuid REFERENCES public.sessions (id) ON DELETE CASCADE,
  type text NOT NULL,
  title text NOT NULL,
  body text NOT NULL,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  dedupe_key text NOT NULL,
  sent_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT notification_outbox_dedupe_key_unique UNIQUE (dedupe_key)
);

CREATE INDEX idx_notification_outbox_pending
  ON public.notification_outbox (created_at)
  WHERE sent_at IS NULL;

ALTER TABLE public.notification_outbox ENABLE ROW LEVEL SECURITY;
-- No policies: clients cannot read/write outbox

-- Attendance RLS (reads only; writes via RPC)
CREATE POLICY attendance_select ON public.attendance
  FOR SELECT TO authenticated
  USING (
    public.is_ucf_email()
    AND public.is_session_participant(session_id)
  );

-- Enqueue helper (SECURITY DEFINER)
CREATE OR REPLACE FUNCTION public.enqueue_notification(
  p_user_id uuid,
  p_session_id uuid,
  p_type text,
  p_title text,
  p_body text,
  p_dedupe_key text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.notification_outbox (
    user_id, session_id, type, title, body, payload, dedupe_key
  )
  VALUES (
    p_user_id,
    p_session_id,
    p_type,
    p_title,
    p_body,
    jsonb_build_object('session_id', p_session_id),
    p_dedupe_key
  )
  ON CONFLICT (dedupe_key) DO NOTHING;
END;
$$;

REVOKE ALL ON FUNCTION public.enqueue_notification(uuid, uuid, text, text, text, text) FROM PUBLIC;

-- Auto-complete sessions past end time
CREATE OR REPLACE FUNCTION public.complete_expired_sessions()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count int;
BEGIN
  UPDATE public.sessions
  SET status = 'completed', updated_at = now()
  WHERE status IN ('open', 'full')
    AND ends_at < now();
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

-- Host marks attendance within 24h after session ends
CREATE OR REPLACE FUNCTION public.submit_session_attendance(
  p_session_id uuid,
  p_attended_user_ids uuid[]
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_host_id uuid;
  v_starts_at timestamptz;
  v_ends_at timestamptz;
  v_status session_status;
  v_old_attended uuid[];
  v_new_attended uuid[];
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  SELECT host_id, starts_at, ends_at, status
  INTO v_host_id, v_starts_at, v_ends_at, v_status
  FROM public.sessions
  WHERE id = p_session_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'session_not_found';
  END IF;

  IF v_host_id <> auth.uid() THEN
    RAISE EXCEPTION 'not_host';
  END IF;

  IF v_status = 'cancelled' THEN
    RAISE EXCEPTION 'session_cancelled';
  END IF;

  IF v_starts_at > now() THEN
    RAISE EXCEPTION 'session_not_started';
  END IF;

  IF now() > v_ends_at + interval '24 hours' THEN
    RAISE EXCEPTION 'attendance_window_closed';
  END IF;

  -- Capture existing attendance before replace (for idempotent stat updates)
  SELECT COALESCE(array_agg(user_id ORDER BY user_id), ARRAY[]::uuid[])
  INTO v_old_attended
  FROM public.attendance
  WHERE session_id = p_session_id;

  -- Normalize new attended set to joined participants only
  SELECT COALESCE(array_agg(uid ORDER BY uid), ARRAY[]::uuid[])
  INTO v_new_attended
  FROM unnest(COALESCE(p_attended_user_ids, ARRAY[]::uuid[])) AS uid
  WHERE EXISTS (
    SELECT 1 FROM public.session_participants sp
    WHERE sp.session_id = p_session_id
      AND sp.user_id = uid
      AND sp.status = 'joined'
  );

  -- No-op when attendance unchanged on an already-completed session
  IF v_status = 'completed' AND v_old_attended = v_new_attended THEN
    RETURN;
  END IF;

  -- Replace attendance rows for this session
  DELETE FROM public.attendance WHERE session_id = p_session_id;

  INSERT INTO public.attendance (session_id, user_id)
  SELECT p_session_id, uid
  FROM unnest(v_new_attended) AS uid;

  -- Newly attended: increment games_played + streak
  UPDATE public.profiles p
  SET
    games_played = games_played + 1,
    show_up_streak = show_up_streak + 1,
    updated_at = now()
  WHERE p.id = ANY(v_new_attended)
    AND NOT (p.id = ANY(v_old_attended));

  -- Streak reset: attended→absent changes, or first submission no-shows
  UPDATE public.profiles p
  SET show_up_streak = 0, updated_at = now()
  WHERE EXISTS (
    SELECT 1 FROM public.session_participants sp
    WHERE sp.session_id = p_session_id
      AND sp.user_id = p.id
      AND sp.status = 'joined'
  )
  AND NOT (p.id = ANY(v_new_attended))
  AND (
    p.id = ANY(v_old_attended)
    OR cardinality(v_old_attended) = 0
  );

  UPDATE public.sessions
  SET status = 'completed', updated_at = now()
  WHERE id = p_session_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_session_attendance(uuid, uuid[]) TO authenticated;
