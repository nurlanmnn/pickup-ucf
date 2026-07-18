-- Phase A Task 1: enqueue_notification dedupe
DO $$
DECLARE
  v_user_id uuid := gen_random_uuid();
  v_dedupe_key text := 'test:dedupe:' || v_user_id::text;
  v_count int;
BEGIN
  INSERT INTO auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    created_at,
    updated_at
  ) VALUES (
    '00000000-0000-0000-0000-000000000000',
    v_user_id,
    'authenticated',
    'authenticated',
    'test-dedupe@knights.ucf.edu',
    '',
    now(),
    now(),
    now()
  );

  INSERT INTO public.profiles (id, display_name)
  VALUES (v_user_id, 'Dedupe Test User');

  PERFORM public.enqueue_notification(
    v_user_id,
    NULL,
    'test',
    'Test title',
    'Test body',
    v_dedupe_key
  );

  PERFORM public.enqueue_notification(
    v_user_id,
    NULL,
    'test',
    'Test title duplicate',
    'Test body duplicate',
    v_dedupe_key
  );

  SELECT count(*) INTO v_count
  FROM public.notification_outbox
  WHERE dedupe_key = v_dedupe_key;

  IF v_count <> 1 THEN
    RAISE EXCEPTION 'enqueue_notification dedupe failed: expected 1 row, got %', v_count;
  END IF;

  DELETE FROM public.notification_outbox WHERE dedupe_key = v_dedupe_key;
  DELETE FROM public.profiles WHERE id = v_user_id;
  DELETE FROM auth.users WHERE id = v_user_id;

  RAISE NOTICE 'phase_a_notifications: enqueue_notification dedupe OK';
END $$;

-- Phase A Task 2: complete_expired_sessions
DO $$
DECLARE
  v_host_id uuid := gen_random_uuid();
  v_expired_open uuid := gen_random_uuid();
  v_expired_full uuid := gen_random_uuid();
  v_future uuid := gen_random_uuid();
  v_cancelled uuid := gen_random_uuid();
  v_completed uuid := gen_random_uuid();
  v_count int;
  v_status session_status;
BEGIN
  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at
  ) VALUES (
    '00000000-0000-0000-0000-000000000000',
    v_host_id, 'authenticated', 'authenticated',
    'test-expired-host@knights.ucf.edu', '', now(), now(), now()
  );

  INSERT INTO public.profiles (id, display_name)
  VALUES (v_host_id, 'Expired Session Host');

  INSERT INTO public.sessions (
    id, host_id, sport, starts_at, ends_at, capacity, skill_level, status
  ) VALUES
    (
      v_expired_open, v_host_id, 'basketball',
      now() - interval '2 hours', now() - interval '1 hour',
      10, 'any', 'open'
    ),
    (
      v_expired_full, v_host_id, 'soccer',
      now() - interval '3 hours', now() - interval '2 hours',
      8, 'intermediate', 'full'
    ),
    (
      v_future, v_host_id, 'tennis',
      now() + interval '1 hour', now() + interval '2 hours',
      4, 'beginner', 'open'
    ),
    (
      v_cancelled, v_host_id, 'volleyball',
      now() - interval '2 hours', now() - interval '1 hour',
      12, 'any', 'cancelled'
    ),
    (
      v_completed, v_host_id, 'football',
      now() - interval '4 hours', now() - interval '3 hours',
      22, 'advanced', 'completed'
    );

  v_count := public.complete_expired_sessions();

  IF v_count < 2 THEN
    RAISE EXCEPTION 'complete_expired_sessions failed: expected at least 2 rows, got %', v_count;
  END IF;

  SELECT status INTO v_status FROM public.sessions WHERE id = v_expired_open;
  IF v_status <> 'completed' THEN
    RAISE EXCEPTION 'complete_expired_sessions failed: expired open session status %', v_status;
  END IF;

  SELECT status INTO v_status FROM public.sessions WHERE id = v_expired_full;
  IF v_status <> 'completed' THEN
    RAISE EXCEPTION 'complete_expired_sessions failed: expired full session status %', v_status;
  END IF;

  SELECT status INTO v_status FROM public.sessions WHERE id = v_future;
  IF v_status <> 'open' THEN
    RAISE EXCEPTION 'complete_expired_sessions failed: future session changed to %', v_status;
  END IF;

  SELECT status INTO v_status FROM public.sessions WHERE id = v_cancelled;
  IF v_status <> 'cancelled' THEN
    RAISE EXCEPTION 'complete_expired_sessions failed: cancelled session changed to %', v_status;
  END IF;

  SELECT status INTO v_status FROM public.sessions WHERE id = v_completed;
  IF v_status <> 'completed' THEN
    RAISE EXCEPTION 'complete_expired_sessions failed: already-completed session changed to %', v_status;
  END IF;

  DELETE FROM public.sessions
  WHERE id IN (v_expired_open, v_expired_full, v_future, v_cancelled, v_completed);
  DELETE FROM public.profiles WHERE id = v_host_id;
  DELETE FROM auth.users WHERE id = v_host_id;

  RAISE NOTICE 'phase_a_notifications: complete_expired_sessions OK';
END $$;

-- Phase A Task 2: submit_session_attendance
DO $$
DECLARE
  v_host_id uuid := gen_random_uuid();
  v_player_attended uuid := gen_random_uuid();
  v_player_noshow uuid := gen_random_uuid();
  v_session_id uuid := gen_random_uuid();
  v_attendance_count int;
  v_games_played int;
  v_streak int;
  v_status session_status;
BEGIN
  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at
  ) VALUES
    (
      '00000000-0000-0000-0000-000000000000',
      v_host_id, 'authenticated', 'authenticated',
      'test-attendance-host@knights.ucf.edu', '', now(), now(), now()
    ),
    (
      '00000000-0000-0000-0000-000000000000',
      v_player_attended, 'authenticated', 'authenticated',
      'test-attendance-yes@knights.ucf.edu', '', now(), now(), now()
    ),
    (
      '00000000-0000-0000-0000-000000000000',
      v_player_noshow, 'authenticated', 'authenticated',
      'test-attendance-no@knights.ucf.edu', '', now(), now(), now()
    );

  INSERT INTO public.profiles (id, display_name, games_played, show_up_streak)
  VALUES
    (v_host_id, 'Attendance Host', 0, 0),
    (v_player_attended, 'Attended Player', 5, 3),
    (v_player_noshow, 'No-show Player', 2, 2);

  INSERT INTO public.sessions (
    id, host_id, sport, starts_at, ends_at, capacity, skill_level, status
  ) VALUES (
    v_session_id, v_host_id, 'basketball',
    now() - interval '2 hours', now() - interval '1 hour',
    10, 'any', 'open'
  );

  INSERT INTO public.session_participants (session_id, user_id, role, status)
  VALUES
    (v_session_id, v_player_attended, 'player', 'joined'),
    (v_session_id, v_player_noshow, 'player', 'joined');

  PERFORM set_config('request.jwt.claim.sub', v_host_id::text, true);

  PERFORM public.submit_session_attendance(
    v_session_id,
    ARRAY[v_player_attended]
  );

  SELECT count(*) INTO v_attendance_count
  FROM public.attendance
  WHERE session_id = v_session_id;

  IF v_attendance_count <> 1 THEN
    RAISE EXCEPTION 'submit_session_attendance failed: expected 1 attendance row, got %', v_attendance_count;
  END IF;

  SELECT games_played, show_up_streak
  INTO v_games_played, v_streak
  FROM public.profiles
  WHERE id = v_player_attended;

  IF v_games_played <> 6 OR v_streak <> 4 THEN
    RAISE EXCEPTION
      'submit_session_attendance failed: attended player stats games=% streak=%',
      v_games_played, v_streak;
  END IF;

  SELECT show_up_streak INTO v_streak
  FROM public.profiles
  WHERE id = v_player_noshow;

  IF v_streak <> 0 THEN
    RAISE EXCEPTION 'submit_session_attendance failed: no-show streak reset to %', v_streak;
  END IF;

  SELECT status INTO v_status FROM public.sessions WHERE id = v_session_id;
  IF v_status <> 'completed' THEN
    RAISE EXCEPTION 'submit_session_attendance failed: session status %', v_status;
  END IF;

  DELETE FROM public.attendance WHERE session_id = v_session_id;
  DELETE FROM public.session_participants WHERE session_id = v_session_id;
  DELETE FROM public.sessions WHERE id = v_session_id;
  DELETE FROM public.profiles
  WHERE id IN (v_host_id, v_player_attended, v_player_noshow);
  DELETE FROM auth.users
  WHERE id IN (v_host_id, v_player_attended, v_player_noshow);

  PERFORM set_config('request.jwt.claim.sub', '', true);

  RAISE NOTICE 'phase_a_notifications: submit_session_attendance OK';
END $$;

-- Phase A Task 2: submit_session_attendance idempotent double-submit
DO $$
DECLARE
  v_host_id uuid := gen_random_uuid();
  v_player_attended uuid := gen_random_uuid();
  v_player_noshow uuid := gen_random_uuid();
  v_session_id uuid := gen_random_uuid();
  v_games_played int;
  v_streak int;
BEGIN
  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at
  ) VALUES
    (
      '00000000-0000-0000-0000-000000000000',
      v_host_id, 'authenticated', 'authenticated',
      'test-idempotent-host@knights.ucf.edu', '', now(), now(), now()
    ),
    (
      '00000000-0000-0000-0000-000000000000',
      v_player_attended, 'authenticated', 'authenticated',
      'test-idempotent-yes@knights.ucf.edu', '', now(), now(), now()
    ),
    (
      '00000000-0000-0000-0000-000000000000',
      v_player_noshow, 'authenticated', 'authenticated',
      'test-idempotent-no@knights.ucf.edu', '', now(), now(), now()
    );

  INSERT INTO public.profiles (id, display_name, games_played, show_up_streak)
  VALUES
    (v_host_id, 'Idempotent Host', 0, 0),
    (v_player_attended, 'Idempotent Attended', 5, 3),
    (v_player_noshow, 'Idempotent No-show', 2, 2);

  INSERT INTO public.sessions (
    id, host_id, sport, starts_at, ends_at, capacity, skill_level, status
  ) VALUES (
    v_session_id, v_host_id, 'basketball',
    now() - interval '2 hours', now() - interval '1 hour',
    10, 'any', 'open'
  );

  INSERT INTO public.session_participants (session_id, user_id, role, status)
  VALUES
    (v_session_id, v_player_attended, 'player', 'joined'),
    (v_session_id, v_player_noshow, 'player', 'joined');

  PERFORM set_config('request.jwt.claim.sub', v_host_id::text, true);

  PERFORM public.submit_session_attendance(
    v_session_id,
    ARRAY[v_player_attended]
  );

  PERFORM public.submit_session_attendance(
    v_session_id,
    ARRAY[v_player_attended]
  );

  SELECT games_played, show_up_streak
  INTO v_games_played, v_streak
  FROM public.profiles
  WHERE id = v_player_attended;

  IF v_games_played <> 6 OR v_streak <> 4 THEN
    RAISE EXCEPTION
      'submit_session_attendance idempotent failed: attended player stats games=% streak=% after double submit',
      v_games_played, v_streak;
  END IF;

  DELETE FROM public.attendance WHERE session_id = v_session_id;
  DELETE FROM public.session_participants WHERE session_id = v_session_id;
  DELETE FROM public.sessions WHERE id = v_session_id;
  DELETE FROM public.profiles
  WHERE id IN (v_host_id, v_player_attended, v_player_noshow);
  DELETE FROM auth.users
  WHERE id IN (v_host_id, v_player_attended, v_player_noshow);

  PERFORM set_config('request.jwt.claim.sub', '', true);

  RAISE NOTICE 'phase_a_notifications: submit_session_attendance idempotent OK';
END $$;

-- Phase A Task 2: submit_session_attendance guard rails
DO $$
DECLARE
  v_host_id uuid := gen_random_uuid();
  v_other_host uuid := gen_random_uuid();
  v_session_id uuid := gen_random_uuid();
  v_closed_session_id uuid := gen_random_uuid();
BEGIN
  PERFORM set_config('request.jwt.claim.sub', '', true);
  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at
  ) VALUES
    (
      '00000000-0000-0000-0000-000000000000',
      v_host_id, 'authenticated', 'authenticated',
      'test-guard-host@knights.ucf.edu', '', now(), now(), now()
    ),
    (
      '00000000-0000-0000-0000-000000000000',
      v_other_host, 'authenticated', 'authenticated',
      'test-guard-other@knights.ucf.edu', '', now(), now(), now()
    );

  INSERT INTO public.profiles (id, display_name)
  VALUES
    (v_host_id, 'Guard Host'),
    (v_other_host, 'Other Host');

  INSERT INTO public.sessions (
    id, host_id, sport, starts_at, ends_at, capacity, skill_level, status
  ) VALUES
    (
      v_session_id, v_host_id, 'soccer',
      now() - interval '2 hours', now() - interval '1 hour',
      10, 'any', 'open'
    ),
    (
      v_closed_session_id, v_host_id, 'tennis',
      now() - interval '30 hours', now() - interval '25 hours',
      4, 'beginner', 'open'
    );

  BEGIN
    PERFORM public.submit_session_attendance(v_session_id, ARRAY[]::uuid[]);
    RAISE EXCEPTION 'submit_session_attendance failed: expected not_authenticated';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%not_authenticated%' THEN
        RAISE;
      END IF;
  END;

  PERFORM set_config('request.jwt.claim.sub', v_other_host::text, true);

  BEGIN
    PERFORM public.submit_session_attendance(v_session_id, ARRAY[]::uuid[]);
    RAISE EXCEPTION 'submit_session_attendance failed: expected not_host';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%not_host%' THEN
        RAISE;
      END IF;
  END;

  PERFORM set_config('request.jwt.claim.sub', v_host_id::text, true);

  BEGIN
    PERFORM public.submit_session_attendance(v_closed_session_id, ARRAY[]::uuid[]);
    RAISE EXCEPTION 'submit_session_attendance failed: expected attendance_window_closed';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%attendance_window_closed%' THEN
        RAISE;
      END IF;
  END;

  DELETE FROM public.sessions WHERE id IN (v_session_id, v_closed_session_id);
  DELETE FROM public.profiles WHERE id IN (v_host_id, v_other_host);
  DELETE FROM auth.users WHERE id IN (v_host_id, v_other_host);

  RAISE NOTICE 'phase_a_notifications: submit_session_attendance guards OK';
END $$;
