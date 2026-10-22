-- BETA-14: make leave retries share the session lock used by joins.
CREATE OR REPLACE FUNCTION public.leave_session(p_session_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_host_id uuid;
  v_prev_status participant_status;
  v_promoted_user uuid;
  v_sport text;
  v_location text;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  -- Same lock order as join_session: serialize membership reads and count changes.
  SELECT host_id INTO v_host_id FROM public.sessions WHERE id = p_session_id FOR UPDATE;
  IF NOT FOUND THEN RETURN; END IF;
  IF v_host_id = auth.uid() THEN RAISE EXCEPTION 'host_cannot_leave'; END IF;

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
    -- Always decrement; only revert 'full' → 'open' (leave 'open' alone).
    UPDATE public.sessions
    SET player_count = GREATEST(0, player_count - 1),
        status = CASE WHEN status = 'full' THEN 'open'::session_status ELSE status END
    WHERE id = p_session_id;

    -- Promote oldest waitlist player (if any).
    WITH next_wait AS (
      SELECT user_id FROM public.session_participants
      WHERE session_id = p_session_id AND status = 'waitlist'
        AND NOT public.users_are_blocked(v_host_id, user_id)
        AND NOT public.is_user_suspended(user_id)
        AND EXISTS (SELECT 1 FROM public.sessions s WHERE s.id = p_session_id
          AND s.status IN ('open', 'full') AND s.ends_at > now())
      ORDER BY joined_at ASC, user_id ASC
      LIMIT 1
    )
    UPDATE public.session_participants sp
    SET status = 'joined'
    FROM next_wait nw
    WHERE sp.session_id = p_session_id AND sp.user_id = nw.user_id
    RETURNING sp.user_id INTO v_promoted_user;

    -- Re-increment only when a waitlist player was actually promoted.
    UPDATE public.sessions
    SET player_count = player_count + 1,
        status = CASE
          WHEN player_count + 1 >= capacity THEN 'full'::session_status
          ELSE status
        END
    WHERE id = p_session_id
      AND v_promoted_user IS NOT NULL;

    -- Notify the promoted player.
    IF v_promoted_user IS NOT NULL AND public.should_notify(v_promoted_user, 'waitlist_promoted') THEN
      SELECT s.sport::text, COALESCE(v.name, s.custom_location, 'campus')
      INTO v_sport, v_location
      FROM public.sessions s
      LEFT JOIN public.venues v ON v.id = s.venue_id
      WHERE s.id = p_session_id;

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
END;
$$;
