-- Serialize Live Activity eligibility and insertion with session lifecycle changes.
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

  -- Eligibility must see commits made while waiting for lifecycle locks.
  -- PostgREST uses READ COMMITTED; transaction-wide snapshots fail closed.
  IF current_setting('transaction_isolation') NOT IN ('read committed', 'read uncommitted') THEN
    RAISE EXCEPTION USING ERRCODE = '40001',
      MESSAGE = 'live_activity_requires_read_committed';
  END IF;

  -- Match account deletion's account-before-session order. A concurrent deletion
  -- cannot remove the caller/profile while this registration inserts its FK.
  PERFORM 1 FROM auth.users WHERE id = v_user_id FOR KEY SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION 'not_authenticated'; END IF;

  -- Registrations share this lock; edits, cancellation, join/leave and deletion
  -- wait until token insertion commits. Keep the eligibility SELECT separate so
  -- membership subqueries take a fresh snapshot after a lifecycle action commits.
  PERFORM 1 FROM public.sessions WHERE id = p_session_id FOR SHARE;

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
