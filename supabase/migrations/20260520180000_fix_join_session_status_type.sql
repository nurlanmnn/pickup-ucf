-- join_session mistakenly declared v_status as participant_status while reading sessions.status (session_status enum).
CREATE OR REPLACE FUNCTION public.join_session(p_session_id uuid)
RETURNS participant_status
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_capacity int;
  v_count int;
  v_session_status session_status;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  SELECT capacity, player_count, status
  INTO v_capacity, v_count, v_session_status
  FROM public.sessions
  WHERE id = p_session_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'session_not_found';
  END IF;

  IF v_session_status NOT IN ('open', 'full') THEN
    RAISE EXCEPTION 'session_not_joinable';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.session_participants
    WHERE session_id = p_session_id AND user_id = auth.uid() AND status = 'joined'
  ) THEN
    RETURN 'joined';
  END IF;

  IF v_count < v_capacity THEN
    INSERT INTO public.session_participants (session_id, user_id, role, status)
    VALUES (p_session_id, auth.uid(), 'player', 'joined')
    ON CONFLICT (session_id, user_id)
    DO UPDATE SET status = 'joined', joined_at = now();

    UPDATE public.sessions
    SET player_count = player_count + 1,
        status = CASE WHEN player_count + 1 >= capacity THEN 'full'::session_status ELSE status END
    WHERE id = p_session_id;

    RETURN 'joined';
  END IF;

  INSERT INTO public.session_participants (session_id, user_id, role, status)
  VALUES (p_session_id, auth.uid(), 'player', 'waitlist')
  ON CONFLICT (session_id, user_id)
  DO UPDATE SET status = 'waitlist';

  RETURN 'waitlist';
END;
$$;
