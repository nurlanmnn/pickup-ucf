-- Standard APNs tokens must have exactly one current owner.
DO $$
DECLARE
  v_user_a uuid := gen_random_uuid();
  v_user_b uuid := gen_random_uuid();
  v_token text := repeat('ab', 32);
  v_count int;
  v_owner uuid;
  v_direct_write_succeeded boolean := false;
  v_duplicate_write_succeeded boolean := false;
BEGIN
  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at
  ) VALUES
  (
    '00000000-0000-0000-0000-000000000000',
    v_user_a, 'authenticated', 'authenticated',
    'test-device-a@knights.ucf.edu', '', now(), now(), now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    v_user_b, 'authenticated', 'authenticated',
    'test-device-b@knights.ucf.edu', '', now(), now(), now()
  );

  INSERT INTO public.profiles (id, display_name)
  VALUES (v_user_a, 'Device User A'), (v_user_b, 'Device User B');

  IF has_function_privilege('anon', 'public.register_device_token(text)', 'EXECUTE')
     OR has_function_privilege('anon', 'public.unregister_device_token(text)', 'EXECUTE') THEN
    RAISE EXCEPTION 'anonymous role can execute a device-token RPC';
  END IF;

  IF NOT has_function_privilege(
    'authenticated', 'public.register_device_token(text)', 'EXECUTE'
  ) OR NOT has_function_privilege(
    'authenticated', 'public.unregister_device_token(text)', 'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'authenticated role cannot execute device-token RPCs';
  END IF;

  IF has_table_privilege('authenticated', 'public.device_tokens', 'INSERT')
     OR has_table_privilege('authenticated', 'public.device_tokens', 'UPDATE')
     OR has_table_privilege('authenticated', 'public.device_tokens', 'DELETE') THEN
    RAISE EXCEPTION 'authenticated role can mutate device_tokens directly';
  END IF;

  IF NOT has_table_privilege('service_role', 'public.device_tokens', 'SELECT')
     OR NOT has_table_privilege('service_role', 'public.device_tokens', 'DELETE')
     OR has_table_privilege('service_role', 'public.device_tokens', 'INSERT')
     OR has_table_privilege('service_role', 'public.device_tokens', 'UPDATE') THEN
    RAISE EXCEPTION 'service role device-token grants are not least privilege';
  END IF;

  SET LOCAL role authenticated;
  PERFORM set_config('request.jwt.claim.sub', v_user_a::text, true);
  PERFORM public.register_device_token(upper(v_token));
  PERFORM public.register_device_token(v_token);

  RESET role;
  SELECT count(*) INTO v_count
  FROM public.device_tokens
  WHERE apns_token = v_token;

  SELECT user_id INTO v_owner
  FROM public.device_tokens
  WHERE apns_token = v_token;

  IF v_count <> 1 OR v_owner <> v_user_a THEN
    RAISE EXCEPTION 'idempotent registration did not leave one user-A row';
  END IF;

  SET LOCAL role authenticated;
  PERFORM set_config('request.jwt.claim.sub', v_user_b::text, true);
  PERFORM public.register_device_token(v_token);

  RESET role;
  SELECT count(*) INTO v_count
  FROM public.device_tokens
  WHERE apns_token = v_token;

  SELECT user_id INTO v_owner
  FROM public.device_tokens
  WHERE apns_token = v_token;

  IF v_count <> 1 OR v_owner <> v_user_b THEN
    RAISE EXCEPTION 'registration did not atomically transfer ownership to user B';
  END IF;

  BEGIN
    INSERT INTO public.device_tokens (user_id, apns_token)
    VALUES (v_user_a, v_token);
    v_duplicate_write_succeeded := true;
  EXCEPTION WHEN unique_violation THEN
    NULL;
  END;

  IF v_duplicate_write_succeeded THEN
    RAISE EXCEPTION 'database constraint allowed duplicate token ownership';
  END IF;

  -- A delayed user-A cleanup must not delete B's transferred row.
  SET LOCAL role authenticated;
  PERFORM set_config('request.jwt.claim.sub', v_user_a::text, true);
  PERFORM public.unregister_device_token(v_token);

  RESET role;
  SELECT count(*) INTO v_count
  FROM public.device_tokens
  WHERE apns_token = v_token;

  SELECT user_id INTO v_owner
  FROM public.device_tokens
  WHERE apns_token = v_token;

  IF v_count <> 1 OR v_owner <> v_user_b THEN
    RAISE EXCEPTION 'delayed user-A cleanup removed user-B ownership';
  END IF;

  -- Authenticated clients must not bypass the owner RPC contract.
  SET LOCAL role authenticated;
  PERFORM set_config('request.jwt.claim.sub', v_user_a::text, true);
  BEGIN
    INSERT INTO public.device_tokens (user_id, apns_token)
    VALUES (v_user_a, repeat('cd', 32));
    v_direct_write_succeeded := true;
  EXCEPTION WHEN insufficient_privilege THEN
    NULL;
  END;

  IF v_direct_write_succeeded THEN
    RAISE EXCEPTION 'authenticated direct device-token insert succeeded';
  END IF;

  -- Invalid tokens are rejected without persisting their value.
  BEGIN
    PERFORM public.register_device_token('not-a-token');
    RAISE EXCEPTION 'invalid token registration succeeded';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%invalid_device_token%' THEN
      RAISE;
    END IF;
  END;

  PERFORM set_config('request.jwt.claim.sub', v_user_b::text, true);
  PERFORM public.unregister_device_token(v_token);

  RESET role;
  SELECT count(*) INTO v_count
  FROM public.device_tokens
  WHERE apns_token = v_token;

  IF v_count <> 0 THEN
    RAISE EXCEPTION 'current owner could not unregister token';
  END IF;

  DELETE FROM public.profiles WHERE id IN (v_user_a, v_user_b);
  DELETE FROM auth.users WHERE id IN (v_user_a, v_user_b);
  PERFORM set_config('request.jwt.claim.sub', '', true);

  RAISE NOTICE 'phase_f_device_token_ownership: ownership lifecycle OK';
END $$;
