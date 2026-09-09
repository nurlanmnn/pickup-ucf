CREATE TABLE public.live_activity_tokens (
  user_id uuid NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  session_id uuid NOT NULL REFERENCES public.sessions (id) ON DELETE CASCADE,
  apns_token text NOT NULL UNIQUE,
  starts_at timestamptz NOT NULL,
  ends_at timestamptz NOT NULL,
  ended_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, session_id)
);

CREATE INDEX idx_live_activity_tokens_due
  ON public.live_activity_tokens (ends_at)
  WHERE ended_at IS NULL;

ALTER TABLE public.live_activity_tokens ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.live_activity_tokens FROM anon, authenticated;
GRANT ALL ON public.live_activity_tokens TO service_role;

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
    AND (
      s.host_id = v_user_id
      OR EXISTS (
        SELECT 1
        FROM public.session_participants sp
        WHERE sp.session_id = s.id
          AND sp.user_id = v_user_id
          AND sp.status IN ('joined', 'waitlist')
      )
    );

  IF NOT FOUND THEN
    RAISE EXCEPTION 'live_activity_session_not_available';
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
  ON CONFLICT (user_id, session_id) DO UPDATE
  SET apns_token = EXCLUDED.apns_token,
      starts_at = EXCLUDED.starts_at,
      ends_at = EXCLUDED.ends_at,
      ended_at = NULL,
      updated_at = now();
END;
$$;

REVOKE ALL ON FUNCTION public.register_live_activity_token(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.register_live_activity_token(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.sync_live_activity_session_schedule()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.live_activity_tokens
  SET starts_at = NEW.starts_at,
      ends_at = CASE
        WHEN NEW.status IN ('cancelled', 'completed') THEN now()
        ELSE NEW.ends_at
      END,
      updated_at = now()
  WHERE session_id = NEW.id
    AND ended_at IS NULL;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.sync_live_activity_session_schedule() FROM PUBLIC;

CREATE TRIGGER sync_live_activity_session_schedule
  AFTER UPDATE OF starts_at, ends_at, status ON public.sessions
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_live_activity_session_schedule();
