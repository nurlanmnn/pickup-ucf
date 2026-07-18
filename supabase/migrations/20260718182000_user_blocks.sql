-- Phase C Task C5: user blocks table, RPCs, join_session enforcement

CREATE TABLE public.user_blocks (
  blocker_id uuid NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  blocked_id uuid NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (blocker_id, blocked_id),
  CHECK (blocker_id <> blocked_id)
);

ALTER TABLE public.user_blocks ENABLE ROW LEVEL SECURITY;

CREATE POLICY user_blocks_own ON public.user_blocks
  FOR ALL TO authenticated
  USING (blocker_id = auth.uid())
  WITH CHECK (blocker_id = auth.uid());

CREATE OR REPLACE FUNCTION public.block_user(p_blocked_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  IF p_blocked_id IS NULL OR p_blocked_id = auth.uid() THEN
    RAISE EXCEPTION 'invalid_block_target';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_blocked_id) THEN
    RAISE EXCEPTION 'user_not_found';
  END IF;

  INSERT INTO public.user_blocks (blocker_id, blocked_id)
  VALUES (auth.uid(), p_blocked_id)
  ON CONFLICT (blocker_id, blocked_id) DO NOTHING;
END;
$$;

CREATE OR REPLACE FUNCTION public.unblock_user(p_blocked_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  DELETE FROM public.user_blocks
  WHERE blocker_id = auth.uid()
    AND blocked_id = p_blocked_id;
END;
$$;

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
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  SELECT capacity, player_count, status, host_id
  INTO v_capacity, v_count, v_session_status, v_host_id
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
    SELECT 1
    FROM public.user_blocks
    WHERE (blocker_id = v_host_id AND blocked_id = auth.uid())
       OR (blocker_id = auth.uid() AND blocked_id = v_host_id)
  ) THEN
    RAISE EXCEPTION 'user_blocked';
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

GRANT EXECUTE ON FUNCTION public.block_user(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.unblock_user(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.join_session(uuid) TO authenticated;
