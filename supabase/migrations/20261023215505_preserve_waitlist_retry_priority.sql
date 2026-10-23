-- BETA-14: unchanged waitlist membership is an idempotent retry.
-- BETA-09/14: keep new memberships and hosted games outside deletion cleanup.
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
  -- Deletion takes this row FOR UPDATE before enumerating any session rows.
  PERFORM 1 FROM auth.users WHERE id=auth.uid() FOR KEY SHARE;
  IF NOT FOUND OR NOT public.is_ucf_email() THEN RAISE EXCEPTION 'not_authenticated'; END IF;
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
  -- A response retry while still full must not reset FIFO waitlist priority.
  ON CONFLICT (session_id, user_id) DO UPDATE SET status = 'waitlist', joined_at = now()
    WHERE session_participants.status IS DISTINCT FROM 'waitlist';
  RETURN 'waitlist'::public.participant_status;
END;
$$;


