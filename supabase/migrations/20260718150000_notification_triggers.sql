-- Notification triggers: session cancelled + waitlist promotion on leave

CREATE OR REPLACE FUNCTION public.notify_session_cancelled()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  r record;
  v_sport text;
  v_location text;
BEGIN
  IF NEW.status <> 'cancelled' OR OLD.status = 'cancelled' THEN
    RETURN NEW;
  END IF;

  v_sport := NEW.sport::text;
  SELECT COALESCE(v.name, NEW.custom_location, 'campus')
  INTO v_location
  FROM public.venues v WHERE v.id = NEW.venue_id;

  FOR r IN
    SELECT sp.user_id
    FROM public.session_participants sp
    WHERE sp.session_id = NEW.id
      AND sp.status IN ('joined', 'waitlist')
  LOOP
    PERFORM public.enqueue_notification(
      r.user_id,
      NEW.id,
      'session_cancelled',
      'Game cancelled',
      format('%s at %s was cancelled by the host.', v_sport, v_location),
      format('session_cancelled:%s:%s', NEW.id, r.user_id)
    );
  END LOOP;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_sessions_notify_cancelled
  AFTER UPDATE OF status ON public.sessions
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_session_cancelled();

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
    UPDATE public.sessions
    SET player_count = GREATEST(0, player_count - 1),
        status = 'open'
    WHERE id = p_session_id AND status = 'full';

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

    UPDATE public.sessions
    SET player_count = player_count + 1,
        status = CASE
          WHEN player_count + 1 >= capacity THEN 'full'::session_status
          ELSE status
        END
    WHERE id = p_session_id
      AND v_promoted_user IS NOT NULL;

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
