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
