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
