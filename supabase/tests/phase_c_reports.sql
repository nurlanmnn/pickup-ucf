-- Phase C Task C7: session reports insert and duplicate prevention

DO $$
DECLARE
  v_host_id uuid := gen_random_uuid();
  v_reporter_id uuid := gen_random_uuid();
  v_other_id uuid := gen_random_uuid();
  v_session_id uuid := gen_random_uuid();
  v_starts timestamptz := now() + interval '2 hours';
  v_ends timestamptz := now() + interval '3 hours';
  v_report_id uuid;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name = 'session_reports'
  ) THEN
    RAISE EXCEPTION 'session_reports table not found';
  END IF;

  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at
  ) VALUES
  (
    '00000000-0000-0000-0000-000000000000',
    v_host_id, 'authenticated', 'authenticated',
    'test-reports-host@knights.ucf.edu', '', now(), now(), now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    v_reporter_id, 'authenticated', 'authenticated',
    'test-reports-reporter@knights.ucf.edu', '', now(), now(), now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    v_other_id, 'authenticated', 'authenticated',
    'test-reports-other@knights.ucf.edu', '', now(), now(), now()
  );

  INSERT INTO public.profiles (id, display_name)
  VALUES
    (v_host_id, 'Reports Host'),
    (v_reporter_id, 'Reports Reporter'),
    (v_other_id, 'Reports Other');

  INSERT INTO public.sessions (
    id, host_id, sport, starts_at, ends_at, capacity, skill_level, status
  ) VALUES (
    v_session_id, v_host_id, 'basketball',
    v_starts, v_ends,
    10, 'any', 'open'
  );

  INSERT INTO public.session_participants (session_id, user_id, role, status)
  VALUES (v_session_id, v_host_id, 'host', 'joined');

  PERFORM set_config('request.jwt.claim.sub', v_reporter_id::text, true);

  BEGIN
    INSERT INTO public.session_reports (reporter_id, session_id, reason)
    VALUES (v_reporter_id, v_session_id, 'short');
    RAISE EXCEPTION 'session_reports failed: expected check violation for short reason';
  EXCEPTION
    WHEN check_violation THEN
      NULL;
  END;

  INSERT INTO public.session_reports (reporter_id, session_id, reason)
  VALUES (
    v_reporter_id,
    v_session_id,
    'Host was abusive and made players uncomfortable during the game.'
  )
  RETURNING id INTO v_report_id;

  IF v_report_id IS NULL THEN
    RAISE EXCEPTION 'session_reports failed: insert did not return id';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.session_reports
    WHERE id = v_report_id
      AND reporter_id = v_reporter_id
      AND session_id = v_session_id
  ) THEN
    RAISE EXCEPTION 'session_reports failed: reporter cannot select own report';
  END IF;

  BEGIN
    INSERT INTO public.session_reports (reporter_id, session_id, reason)
    VALUES (
      v_reporter_id,
      v_session_id,
      'Duplicate report attempt for the same session again.'
    );
    RAISE EXCEPTION 'session_reports failed: duplicate insert should be rejected';
  EXCEPTION
    WHEN unique_violation THEN
      NULL;
  END;

  -- RLS isolation: run as authenticated role (service role bypasses RLS)
  SET LOCAL role authenticated;
  PERFORM set_config('request.jwt.claim.sub', v_other_id::text, true);

  IF EXISTS (
    SELECT 1
    FROM public.session_reports
    WHERE id = v_report_id
  ) THEN
    RAISE EXCEPTION 'session_reports failed: other user should not see reporter row';
  END IF;

  RESET role;

  DELETE FROM public.session_reports WHERE session_id = v_session_id;
  DELETE FROM public.session_participants WHERE session_id = v_session_id;
  DELETE FROM public.sessions WHERE id = v_session_id;
  DELETE FROM public.profiles WHERE id IN (v_host_id, v_reporter_id, v_other_id);
  DELETE FROM auth.users WHERE id IN (v_host_id, v_reporter_id, v_other_id);

  PERFORM set_config('request.jwt.claim.sub', '', true);

  RAISE NOTICE 'phase_c_reports: insert and duplicate prevention OK';
END $$;
