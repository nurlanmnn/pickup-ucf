-- Phase C Task C1: recurring session spawn via attendance + cron

-- spawn_next_recurring_session: count=3 series yields at most 2 spawns, +7 day dates
DO $$
DECLARE
  v_host_id uuid := gen_random_uuid();
  v_session1 uuid := gen_random_uuid();
  v_session2 uuid;
  v_session3 uuid;
  v_starts timestamptz := now() - interval '2 hours';
  v_ends timestamptz := now() - interval '1 hour';
  v_spawn_count int;
  v_starts_at timestamptz;
  v_recurrence_index int;
  v_recurrence_parent_id uuid;
  v_status session_status;
BEGIN
  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at
  ) VALUES (
    '00000000-0000-0000-0000-000000000000',
    v_host_id, 'authenticated', 'authenticated',
    'test-recurrence-host@knights.ucf.edu', '', now(), now(), now()
  );

  INSERT INTO public.profiles (id, display_name)
  VALUES (v_host_id, 'Recurrence Host');

  INSERT INTO public.sessions (
    id, host_id, sport, starts_at, ends_at, capacity, skill_level, status,
    recurrence_rule, recurrence_index
  ) VALUES (
    v_session1, v_host_id, 'basketball',
    v_starts, v_ends,
    10, 'any', 'open',
    '{"frequency":"weekly","count":3}', 1
  );

  INSERT INTO public.session_participants (session_id, user_id, role, status)
  VALUES (v_session1, v_host_id, 'host', 'joined');

  PERFORM set_config('request.jwt.claim.sub', v_host_id::text, true);

  PERFORM public.submit_session_attendance(v_session1, ARRAY[]::uuid[]);

  SELECT id INTO v_session2
  FROM public.sessions
  WHERE recurrence_parent_id = v_session1
    AND recurrence_index = 2;

  IF v_session2 IS NULL THEN
    RAISE EXCEPTION 'recurrence spawn failed: expected session index 2';
  END IF;

  SELECT starts_at, recurrence_index, recurrence_parent_id, status
  INTO v_starts_at, v_recurrence_index, v_recurrence_parent_id, v_status
  FROM public.sessions
  WHERE id = v_session2;

  IF v_starts_at <> v_starts + interval '7 days' THEN
    RAISE EXCEPTION 'recurrence spawn failed: session2 starts_at % expected %',
      v_starts_at, v_starts + interval '7 days';
  END IF;

  IF v_recurrence_index <> 2 OR v_recurrence_parent_id <> v_session1 OR v_status <> 'open' THEN
    RAISE EXCEPTION 'recurrence spawn failed: session2 metadata index=% parent=% status=%',
      v_recurrence_index, v_recurrence_parent_id, v_status;
  END IF;

  UPDATE public.sessions
  SET starts_at = now() - interval '2 hours',
      ends_at = now() - interval '1 hour',
      status = 'open'
  WHERE id = v_session2;

  SELECT starts_at INTO v_starts_at
  FROM public.sessions
  WHERE id = v_session2;

  PERFORM public.submit_session_attendance(v_session2, ARRAY[]::uuid[]);

  SELECT id INTO v_session3
  FROM public.sessions
  WHERE recurrence_parent_id = v_session1
    AND recurrence_index = 3;

  IF v_session3 IS NULL THEN
    RAISE EXCEPTION 'recurrence spawn failed: expected session index 3';
  END IF;

  IF (SELECT starts_at FROM public.sessions WHERE id = v_session3)
     <> v_starts_at + interval '7 days' THEN
    RAISE EXCEPTION 'recurrence spawn failed: session3 starts_at % expected %',
      (SELECT starts_at FROM public.sessions WHERE id = v_session3),
      v_starts_at + interval '7 days';
  END IF;

  UPDATE public.sessions
  SET starts_at = now() - interval '2 hours',
      ends_at = now() - interval '1 hour',
      status = 'open'
  WHERE id = v_session3;

  PERFORM public.submit_session_attendance(v_session3, ARRAY[]::uuid[]);

  SELECT count(*) INTO v_spawn_count
  FROM public.sessions
  WHERE recurrence_parent_id = v_session1;

  IF v_spawn_count <> 2 THEN
    RAISE EXCEPTION 'recurrence spawn failed: expected 2 spawned sessions, got %', v_spawn_count;
  END IF;

  DELETE FROM public.attendance
  WHERE session_id IN (v_session1, v_session2, v_session3);
  DELETE FROM public.session_participants
  WHERE session_id IN (v_session1, v_session2, v_session3);
  DELETE FROM public.sessions
  WHERE id IN (v_session1, v_session2, v_session3)
     OR recurrence_parent_id = v_session1;
  DELETE FROM public.profiles WHERE id = v_host_id;
  DELETE FROM auth.users WHERE id = v_host_id;

  PERFORM set_config('request.jwt.claim.sub', '', true);

  RAISE NOTICE 'phase_c_recurrence: submit_session_attendance spawn OK';
END $$;

-- complete_expired_sessions spawns next occurrence for recurring sessions
DO $$
DECLARE
  v_host_id uuid := gen_random_uuid();
  v_session1 uuid := gen_random_uuid();
  v_session2 uuid;
  v_starts timestamptz := now() - interval '3 hours';
  v_ends timestamptz := now() - interval '1 hour';
  v_count int;
BEGIN
  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at
  ) VALUES (
    '00000000-0000-0000-0000-000000000000',
    v_host_id, 'authenticated', 'authenticated',
    'test-recurrence-cron@knights.ucf.edu', '', now(), now(), now()
  );

  INSERT INTO public.profiles (id, display_name)
  VALUES (v_host_id, 'Recurrence Cron Host');

  INSERT INTO public.sessions (
    id, host_id, sport, starts_at, ends_at, capacity, skill_level, status,
    recurrence_rule, recurrence_index
  ) VALUES (
    v_session1, v_host_id, 'soccer',
    v_starts, v_ends,
    8, 'intermediate', 'open',
    '{"frequency":"weekly","count":3}', 1
  );

  INSERT INTO public.session_participants (session_id, user_id, role, status)
  VALUES (v_session1, v_host_id, 'host', 'joined');

  v_count := public.complete_expired_sessions();

  IF v_count < 1 THEN
    RAISE EXCEPTION 'complete_expired_sessions recurrence failed: expected >=1 completed, got %', v_count;
  END IF;

  SELECT id INTO v_session2
  FROM public.sessions
  WHERE recurrence_parent_id = v_session1
    AND recurrence_index = 2;

  IF v_session2 IS NULL THEN
    RAISE EXCEPTION 'complete_expired_sessions recurrence failed: no spawn for index 2';
  END IF;

  DELETE FROM public.session_participants
  WHERE session_id IN (v_session1, v_session2);
  DELETE FROM public.sessions
  WHERE id IN (v_session1, v_session2)
     OR recurrence_parent_id = v_session1;
  DELETE FROM public.profiles WHERE id = v_host_id;
  DELETE FROM auth.users WHERE id = v_host_id;

  RAISE NOTICE 'phase_c_recurrence: complete_expired_sessions spawn OK';
END $$;
