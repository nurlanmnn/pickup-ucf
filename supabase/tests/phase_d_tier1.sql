-- Tier 1 Task T1-1: notification_preferences table and RLS

DO $$
DECLARE
  v_user_id uuid := gen_random_uuid();
  v_other_id uuid := gen_random_uuid();
  v_session_reminders boolean;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name = 'notification_preferences'
  ) THEN
    RAISE EXCEPTION 'notification_preferences table not found';
  END IF;

  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at
  ) VALUES
  (
    '00000000-0000-0000-0000-000000000000',
    v_user_id, 'authenticated', 'authenticated',
    'test-notif-prefs@knights.ucf.edu', '', now(), now(), now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    v_other_id, 'authenticated', 'authenticated',
    'test-notif-prefs-other@knights.ucf.edu', '', now(), now(), now()
  );

  INSERT INTO public.profiles (id, display_name)
  VALUES
    (v_user_id, 'Notif Prefs User'),
    (v_other_id, 'Notif Prefs Other');

  SET LOCAL role authenticated;
  PERFORM set_config('request.jwt.claim.sub', v_user_id::text, true);

  INSERT INTO public.notification_preferences (user_id, session_reminders)
  VALUES (v_user_id, false);

  SELECT session_reminders INTO v_session_reminders
  FROM public.notification_preferences
  WHERE user_id = v_user_id;

  IF v_session_reminders IS DISTINCT FROM false THEN
    RAISE EXCEPTION
      'notification_preferences failed: expected session_reminders false, got %',
      v_session_reminders;
  END IF;

  PERFORM set_config('request.jwt.claim.sub', v_other_id::text, true);

  IF EXISTS (
    SELECT 1
    FROM public.notification_preferences
    WHERE user_id = v_user_id
  ) THEN
    RAISE EXCEPTION
      'notification_preferences RLS failed: other user should not see row';
  END IF;

  BEGIN
    INSERT INTO public.notification_preferences (user_id)
    VALUES (v_user_id);
    RAISE EXCEPTION
      'notification_preferences RLS failed: other user should not insert for user';
  EXCEPTION
    WHEN insufficient_privilege THEN
      NULL;
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%new row violates row-level security policy%' THEN
        RAISE;
      END IF;
  END;

  RESET role;

  DELETE FROM public.notification_preferences WHERE user_id = v_user_id;
  DELETE FROM public.profiles WHERE id IN (v_user_id, v_other_id);
  DELETE FROM auth.users WHERE id IN (v_user_id, v_other_id);

  PERFORM set_config('request.jwt.claim.sub', '', true);

  RAISE NOTICE 'phase_d_tier1: notification_preferences insert and RLS OK';
END $$;

-- Tier 1 Task T1-2: should_notify gates session reminder enqueue

DO $$
DECLARE
  v_host_id uuid := gen_random_uuid();
  v_player_id uuid := gen_random_uuid();
  v_session_id uuid := gen_random_uuid();
  v_venue_id uuid := gen_random_uuid();
  v_count int;
  v_outbox_count int;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'should_notify'
  ) THEN
    RAISE EXCEPTION 'should_notify function not found';
  END IF;

  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at
  ) VALUES
  (
    '00000000-0000-0000-0000-000000000000',
    v_host_id, 'authenticated', 'authenticated',
    'test-should-notify-host@knights.ucf.edu', '', now(), now(), now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    v_player_id, 'authenticated', 'authenticated',
    'test-should-notify-player@knights.ucf.edu', '', now(), now(), now()
  );

  INSERT INTO public.profiles (id, display_name)
  VALUES
    (v_host_id, 'Should Notify Host'),
    (v_player_id, 'Should Notify Player');

  INSERT INTO public.notification_preferences (user_id, session_reminders)
  VALUES (v_player_id, false);

  INSERT INTO public.notification_preferences (user_id, host_session_reminder)
  VALUES (v_host_id, false);

  INSERT INTO public.venues (id, name, lat, lng)
  VALUES (v_venue_id, 'Student Union', 28.6024, -81.2001);

  INSERT INTO public.sessions (
    id, host_id, sport, venue_id, starts_at, ends_at, capacity, skill_level, status
  ) VALUES (
    v_session_id, v_host_id, 'basketball', v_venue_id,
    now() + interval '1 hour', now() + interval '2 hours',
    10, 'any', 'open'
  );

  INSERT INTO public.session_participants (session_id, user_id, role, status)
  VALUES (v_session_id, v_player_id, 'player', 'joined');

  v_count := public.enqueue_session_reminders('1h');

  IF v_count <> 0 THEN
    RAISE EXCEPTION 'should_notify failed: expected count 0 when session_reminders off, got %', v_count;
  END IF;

  SELECT count(*) INTO v_outbox_count
  FROM public.notification_outbox
  WHERE session_id = v_session_id
    AND type = 'session_reminder_1h'
    AND user_id = v_player_id;

  IF v_outbox_count <> 0 THEN
    RAISE EXCEPTION
      'should_notify failed: expected 0 outbox rows when session_reminders off, got %',
      v_outbox_count;
  END IF;

  DELETE FROM public.notification_outbox WHERE session_id = v_session_id;
  DELETE FROM public.notification_preferences WHERE user_id IN (v_host_id, v_player_id);
  DELETE FROM public.session_participants WHERE session_id = v_session_id;
  DELETE FROM public.sessions WHERE id = v_session_id;
  DELETE FROM public.venues WHERE id = v_venue_id;
  DELETE FROM public.profiles WHERE id IN (v_host_id, v_player_id);
  DELETE FROM auth.users WHERE id IN (v_host_id, v_player_id);

  RAISE NOTICE 'phase_d_tier1: should_notify gates session reminder enqueue OK';
END $$;

-- Tier 1 Task T1-3: host notified when player joins

DO $$
DECLARE
  v_host_id uuid := gen_random_uuid();
  v_player_id uuid := gen_random_uuid();
  v_session_id uuid := gen_random_uuid();
  v_count int;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_trigger
    WHERE tgname = 'trg_notify_host_player_joined'
  ) THEN
    RAISE EXCEPTION 'trg_notify_host_player_joined not found';
  END IF;

  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at
  ) VALUES
  (
    '00000000-0000-0000-0000-000000000000',
    v_host_id, 'authenticated', 'authenticated',
    'test-host-notify-host@knights.ucf.edu', '', now(), now(), now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    v_player_id, 'authenticated', 'authenticated',
    'test-host-notify-player@knights.ucf.edu', '', now(), now(), now()
  );

  INSERT INTO public.profiles (id, display_name)
  VALUES
    (v_host_id, 'Host Notify Host'),
    (v_player_id, 'Host Notify Player');

  INSERT INTO public.sessions (
    id, host_id, sport, starts_at, ends_at, capacity, skill_level, status
  ) VALUES (
    v_session_id, v_host_id, 'soccer',
    now() + interval '2 hours', now() + interval '3 hours',
    10, 'any', 'open'
  );

  INSERT INTO public.session_participants (session_id, user_id, role, status)
  VALUES (v_session_id, v_host_id, 'host', 'joined');

  INSERT INTO public.session_participants (session_id, user_id, role, status)
  VALUES (v_session_id, v_player_id, 'player', 'joined');

  SELECT count(*) INTO v_count
  FROM public.notification_outbox
  WHERE session_id = v_session_id
    AND type = 'host_player_joined'
    AND user_id = v_host_id;

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'host_player_joined failed: expected 1 outbox row for host, got %',
      v_count;
  END IF;

  DELETE FROM public.notification_outbox WHERE session_id = v_session_id;
  DELETE FROM public.session_participants WHERE session_id = v_session_id;
  DELETE FROM public.sessions WHERE id = v_session_id;
  DELETE FROM public.profiles WHERE id IN (v_host_id, v_player_id);
  DELETE FROM auth.users WHERE id IN (v_host_id, v_player_id);

  RAISE NOTICE 'phase_d_tier1: host_player_joined notification OK';
END $$;

-- Tier 1 Task T1-3: host join notification skipped when pref off

DO $$
DECLARE
  v_host_id uuid := gen_random_uuid();
  v_player_id uuid := gen_random_uuid();
  v_session_id uuid := gen_random_uuid();
  v_count int;
BEGIN
  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at
  ) VALUES
  (
    '00000000-0000-0000-0000-000000000000',
    v_host_id, 'authenticated', 'authenticated',
    'test-host-pref-off-host@knights.ucf.edu', '', now(), now(), now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    v_player_id, 'authenticated', 'authenticated',
    'test-host-pref-off-player@knights.ucf.edu', '', now(), now(), now()
  );

  INSERT INTO public.profiles (id, display_name)
  VALUES
    (v_host_id, 'Host Pref Off Host'),
    (v_player_id, 'Host Pref Off Player');

  INSERT INTO public.notification_preferences (user_id, host_player_joined)
  VALUES (v_host_id, false);

  INSERT INTO public.sessions (
    id, host_id, sport, starts_at, ends_at, capacity, skill_level, status
  ) VALUES (
    v_session_id, v_host_id, 'tennis',
    now() + interval '2 hours', now() + interval '3 hours',
    4, 'beginner', 'open'
  );

  INSERT INTO public.session_participants (session_id, user_id, role, status)
  VALUES (v_session_id, v_host_id, 'host', 'joined');

  INSERT INTO public.session_participants (session_id, user_id, role, status)
  VALUES (v_session_id, v_player_id, 'player', 'joined');

  SELECT count(*) INTO v_count
  FROM public.notification_outbox
  WHERE session_id = v_session_id
    AND type = 'host_player_joined'
    AND user_id = v_host_id;

  IF v_count <> 0 THEN
    RAISE EXCEPTION
      'host_player_joined pref off failed: expected 0 outbox rows, got %',
      v_count;
  END IF;

  DELETE FROM public.notification_preferences WHERE user_id = v_host_id;
  DELETE FROM public.session_participants WHERE session_id = v_session_id;
  DELETE FROM public.sessions WHERE id = v_session_id;
  DELETE FROM public.profiles WHERE id IN (v_host_id, v_player_id);
  DELETE FROM auth.users WHERE id IN (v_host_id, v_player_id);

  RAISE NOTICE 'phase_d_tier1: host_player_joined skipped when pref off OK';
END $$;

-- Tier 1 Task T1-4: get_session_roster joined list and waitlist position

DO $$
DECLARE
  v_host_id uuid := gen_random_uuid();
  v_joined_1 uuid := gen_random_uuid();
  v_wait_1 uuid := gen_random_uuid();
  v_wait_2 uuid := gen_random_uuid();
  v_session_id uuid := gen_random_uuid();
  v_roster jsonb;
  v_joined_count int;
  v_waitlist_count int;
  v_position int;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'get_session_roster'
  ) THEN
    RAISE EXCEPTION 'get_session_roster function not found';
  END IF;

  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at
  ) VALUES
  (
    '00000000-0000-0000-0000-000000000000',
    v_host_id, 'authenticated', 'authenticated',
    'test-roster-host@knights.ucf.edu', '', now(), now(), now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    v_joined_1, 'authenticated', 'authenticated',
    'test-roster-joined1@knights.ucf.edu', '', now(), now(), now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    v_wait_1, 'authenticated', 'authenticated',
    'test-roster-wait1@knights.ucf.edu', '', now(), now(), now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    v_wait_2, 'authenticated', 'authenticated',
    'test-roster-wait2@knights.ucf.edu', '', now(), now(), now()
  );

  INSERT INTO public.profiles (id, display_name, username)
  VALUES
    (v_host_id, 'Roster Host', 'rosterhost'),
    (v_joined_1, 'Roster Joined One', 'joinedone'),
    (v_wait_1, 'Roster Wait One', 'waitone'),
    (v_wait_2, 'Roster Wait Two', 'waittwo');

  INSERT INTO public.sessions (
    id, host_id, sport, starts_at, ends_at, capacity, skill_level, status, player_count
  ) VALUES (
    v_session_id, v_host_id, 'basketball',
    now() + interval '2 hours', now() + interval '3 hours',
    2, 'any', 'full', 2
  );

  INSERT INTO public.session_participants (session_id, user_id, role, status, joined_at)
  VALUES
    (v_session_id, v_host_id, 'host', 'joined', now() - interval '4 hours'),
    (v_session_id, v_joined_1, 'player', 'joined', now() - interval '3 hours'),
    (v_session_id, v_wait_1, 'player', 'waitlist', now() - interval '1 hour'),
    (v_session_id, v_wait_2, 'player', 'waitlist', now() - interval '30 minutes');

  PERFORM set_config('request.jwt.claim.sub', v_wait_1::text, true);

  v_roster := public.get_session_roster(v_session_id);

  v_joined_count := jsonb_array_length(v_roster->'joined');
  v_waitlist_count := (v_roster->>'waitlist_count')::int;
  v_position := (v_roster->>'viewer_waitlist_position')::int;

  IF v_joined_count <> 2 THEN
    RAISE EXCEPTION
      'get_session_roster failed: expected 2 joined players, got %',
      v_joined_count;
  END IF;

  IF v_waitlist_count <> 2 THEN
    RAISE EXCEPTION
      'get_session_roster failed: expected waitlist_count 2, got %',
      v_waitlist_count;
  END IF;

  IF v_position <> 1 THEN
    RAISE EXCEPTION
      'get_session_roster failed: expected viewer_waitlist_position 1, got %',
      v_position;
  END IF;

  DELETE FROM public.notification_outbox WHERE session_id = v_session_id;
  DELETE FROM public.session_participants WHERE session_id = v_session_id;
  DELETE FROM public.sessions WHERE id = v_session_id;
  DELETE FROM public.profiles
  WHERE id IN (v_host_id, v_joined_1, v_wait_1, v_wait_2);
  DELETE FROM auth.users
  WHERE id IN (v_host_id, v_joined_1, v_wait_1, v_wait_2);

  PERFORM set_config('request.jwt.claim.sub', '', true);

  RAISE NOTICE 'phase_d_tier1: get_session_roster OK';
END $$;
