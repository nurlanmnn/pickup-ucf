-- Phase C Task C1: weekly recurring session spawn

ALTER TABLE public.sessions
  ADD COLUMN IF NOT EXISTS recurrence_parent_id uuid REFERENCES public.sessions (id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS recurrence_index int NOT NULL DEFAULT 1 CHECK (recurrence_index >= 1);

CREATE OR REPLACE FUNCTION public.spawn_next_recurring_session(p_completed_session_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_src public.sessions%ROWTYPE;
  v_rule jsonb;
  v_count int;
  v_next_starts timestamptz;
  v_next_ends interval;
  v_new_id uuid;
BEGIN
  SELECT * INTO v_src FROM public.sessions WHERE id = p_completed_session_id;
  IF NOT FOUND OR v_src.recurrence_rule IS NULL THEN RETURN NULL; END IF;

  v_rule := v_src.recurrence_rule::jsonb;
  v_count := (v_rule->>'count')::int;
  IF v_src.recurrence_index >= v_count THEN RETURN NULL; END IF;

  v_next_starts := v_src.starts_at + interval '7 days';
  v_next_ends := v_src.ends_at - v_src.starts_at;

  INSERT INTO public.sessions (
    host_id, sport, venue_id, custom_location, custom_lat, custom_lng,
    starts_at, ends_at, capacity, player_count, skill_level, notes, status,
    recurrence_rule, recurrence_parent_id, recurrence_index
  )
  VALUES (
    v_src.host_id, v_src.sport, v_src.venue_id, v_src.custom_location,
    v_src.custom_lat, v_src.custom_lng,
    v_next_starts, v_next_starts + v_next_ends, v_src.capacity, 1,
    v_src.skill_level, v_src.notes, 'open',
    v_src.recurrence_rule,
    COALESCE(v_src.recurrence_parent_id, v_src.id),
    v_src.recurrence_index + 1
  )
  RETURNING id INTO v_new_id;

  INSERT INTO public.session_participants (session_id, user_id, role, status)
  VALUES (v_new_id, v_src.host_id, 'host', 'joined');

  RETURN v_new_id;
END;
$$;

REVOKE ALL ON FUNCTION public.spawn_next_recurring_session(uuid) FROM PUBLIC;

CREATE OR REPLACE FUNCTION public.complete_expired_sessions()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count int := 0;
  v_session_id uuid;
BEGIN
  FOR v_session_id IN
    UPDATE public.sessions
    SET status = 'completed', updated_at = now()
    WHERE status IN ('open', 'full')
      AND ends_at < now()
    RETURNING id
  LOOP
    v_count := v_count + 1;
    PERFORM public.spawn_next_recurring_session(v_session_id);
  END LOOP;

  RETURN v_count;
END;
$$;

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

  IF v_host_id <> auth.uid() THEN
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
