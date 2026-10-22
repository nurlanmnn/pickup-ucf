-- BETA-09: retain hosted games with an anonymized host; preserve other players' chat.
-- Requires the nullable-host iOS candidate before deployment.
ALTER TABLE public.sessions ALTER COLUMN host_id DROP NOT NULL;
ALTER TABLE public.sessions DROP CONSTRAINT sessions_host_id_fkey;
ALTER TABLE public.sessions ADD CONSTRAINT sessions_host_id_fkey
  FOREIGN KEY (host_id) REFERENCES public.profiles(id) ON DELETE SET NULL;

CREATE OR REPLACE FUNCTION public.delete_own_account()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_user uuid := auth.uid();
  v_session uuid;
BEGIN
  IF v_user IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  -- Idempotent retry after the account has already been removed.
  PERFORM 1 FROM auth.users WHERE id=v_user FOR UPDATE;
  IF NOT FOUND THEN RETURN; END IF;

  -- Serialize against join/leave and other deletions, always in the same order.
  PERFORM s.id FROM public.sessions s
  WHERE s.host_id=v_user OR EXISTS (
    SELECT 1 FROM public.session_participants p WHERE p.session_id=s.id
      AND p.user_id=v_user AND p.status IN ('joined','waitlist')
  ) ORDER BY s.id FOR UPDATE;

  UPDATE public.sessions SET status='cancelled',updated_at=now()
    WHERE host_id=v_user AND status IN ('open','full');
  -- Historical recurrence metadata cannot spawn new games for a removed host.
  UPDATE public.sessions SET recurrence_rule=NULL WHERE host_id=v_user;
  FOR v_session IN
    SELECT s.id FROM public.sessions s JOIN public.session_participants p ON p.session_id=s.id
    WHERE p.user_id=v_user AND p.status IN ('joined','waitlist')
      AND s.host_id IS DISTINCT FROM v_user ORDER BY s.id
  LOOP
    PERFORM public.leave_session(v_session);
  END LOOP;

  -- Remove the host membership while the profile still exists; reconcile retained
  -- games rather than leaving their count dependent on a later cascading delete.
  DELETE FROM public.session_participants p USING public.sessions s
    WHERE p.session_id=s.id AND s.host_id=v_user AND p.user_id=v_user;
  UPDATE public.sessions s SET player_count=(
    SELECT count(*) FROM public.session_participants p WHERE p.session_id=s.id AND p.status='joined'
  ) WHERE s.host_id=v_user;

  -- Authored preview rows can contain the deleted person's name or message body.
  -- Fixed cancellation notifications for other players remain queued.
  DELETE FROM public.notification_outbox WHERE payload->>'actor_user_id'=v_user::text;
  DELETE FROM auth.users WHERE id=v_user;
END;
$$;
REVOKE ALL ON FUNCTION public.delete_own_account() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.delete_own_account() TO authenticated;

-- NULL is never a host authorization match on retained games.
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

  IF v_host_id IS DISTINCT FROM auth.uid() THEN
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

  SELECT COALESCE(array_agg(user_id ORDER BY user_id), ARRAY[]::uuid[])
  INTO v_old_attended
  FROM public.attendance
  WHERE session_id = p_session_id;

  SELECT COALESCE(array_agg(uid ORDER BY uid), ARRAY[]::uuid[])
  INTO v_new_attended
  FROM unnest(COALESCE(p_attended_user_ids, ARRAY[]::uuid[])) AS uid
  WHERE EXISTS (
    SELECT 1 FROM public.session_participants sp
    WHERE sp.session_id = p_session_id
      AND sp.user_id = uid
      AND sp.status = 'joined'
  );

  IF v_status = 'completed' AND v_old_attended = v_new_attended THEN
    RETURN;
  END IF;

  DELETE FROM public.attendance WHERE session_id = p_session_id;

  INSERT INTO public.attendance (session_id, user_id)
  SELECT p_session_id, uid
  FROM unnest(v_new_attended) AS uid;

  UPDATE public.profiles p
  SET
    games_played = games_played + 1,
    show_up_streak = show_up_streak + 1,
    updated_at = now()
  WHERE p.id = ANY(v_new_attended)
    AND NOT (p.id = ANY(v_old_attended));

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

  IF v_status <> 'completed' THEN
    PERFORM public.spawn_next_recurring_session(p_session_id);
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_session_attendance(uuid, uuid[]) TO authenticated;
