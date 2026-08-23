-- Fix: leave_session did not decrement player_count when session status was 'open'.
--
-- Root cause (20260718150000_notification_triggers.sql):
--
--   UPDATE public.sessions
--   SET player_count = GREATEST(0, player_count - 1), status = 'open'
--   WHERE id = p_session_id AND status = 'full';   ← only fires for full sessions
--
-- When a joined player leaves an open (non-full) session the WHERE clause never
-- matches, so player_count is never decremented. The count badge therefore shows
-- a stale inflated number (e.g. 3/4 with only 2 players visible).
--
-- Fix: always decrement player_count; only flip status → 'open' when it was 'full'.
-- Everything else (waitlist promotion, notifications) is unchanged.

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
    -- Always decrement; only revert 'full' → 'open' (leave 'open' alone).
    UPDATE public.sessions
    SET player_count = GREATEST(0, player_count - 1),
        status = CASE WHEN status = 'full' THEN 'open'::session_status ELSE status END
    WHERE id = p_session_id;

    -- Promote oldest waitlist player (if any).
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
    IF v_promoted_user IS NOT NULL THEN
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
