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
