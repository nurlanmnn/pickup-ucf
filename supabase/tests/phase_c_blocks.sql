-- Phase C Task C5: user blocks and join_session rejection

DO $$
DECLARE
  v_host_id uuid := gen_random_uuid();
  v_player_id uuid := gen_random_uuid();
  v_session_id uuid := gen_random_uuid();
  v_starts timestamptz := now() + interval '2 hours';
  v_ends timestamptz := now() + interval '3 hours';
  v_status participant_status;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name = 'user_blocks'
  ) THEN
    RAISE EXCEPTION 'user_blocks table not found';
  END IF;

  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at
  ) VALUES
  (
    '00000000-0000-0000-0000-000000000000',
    v_host_id, 'authenticated', 'authenticated',
    'test-blocks-host@knights.ucf.edu', '', now(), now(), now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    v_player_id, 'authenticated', 'authenticated',
    'test-blocks-player@knights.ucf.edu', '', now(), now(), now()
  );

  INSERT INTO public.profiles (id, display_name)
  VALUES
    (v_host_id, 'Blocks Host'),
    (v_player_id, 'Blocks Player');

  INSERT INTO public.sessions (
    id, host_id, sport, starts_at, ends_at, capacity, skill_level, status
  ) VALUES (
    v_session_id, v_host_id, 'basketball',
    v_starts, v_ends,
    10, 'any', 'open'
  );

  INSERT INTO public.session_participants (session_id, user_id, role, status)
  VALUES (v_session_id, v_host_id, 'host', 'joined');

  PERFORM set_config('request.jwt.claim.sub', v_player_id::text, true);

  BEGIN
    PERFORM public.block_user(NULL);
    RAISE EXCEPTION 'block_user failed: expected invalid_block_target for NULL';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%invalid_block_target%' THEN
        RAISE;
      END IF;
  END;

  BEGIN
    PERFORM public.block_user(v_player_id);
    RAISE EXCEPTION 'block_user failed: expected invalid_block_target for self';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%invalid_block_target%' THEN
        RAISE;
      END IF;
  END;

  PERFORM public.block_user(v_host_id);

  IF NOT EXISTS (
    SELECT 1
    FROM public.user_blocks
    WHERE blocker_id = v_player_id
      AND blocked_id = v_host_id
  ) THEN
    RAISE EXCEPTION 'block_user failed: row not inserted';
  END IF;

  BEGIN
    PERFORM public.join_session(v_session_id);
    RAISE EXCEPTION 'join_session failed: expected user_blocked when player blocked host';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%user_blocked%' THEN
        RAISE;
      END IF;
  END;

  PERFORM public.unblock_user(v_host_id);

  IF EXISTS (
    SELECT 1
    FROM public.user_blocks
    WHERE blocker_id = v_player_id
      AND blocked_id = v_host_id
  ) THEN
    RAISE EXCEPTION 'unblock_user failed: row still present';
  END IF;

  PERFORM set_config('request.jwt.claim.sub', v_host_id::text, true);
  PERFORM public.block_user(v_player_id);
  PERFORM set_config('request.jwt.claim.sub', v_player_id::text, true);

  BEGIN
    PERFORM public.join_session(v_session_id);
    RAISE EXCEPTION 'join_session failed: expected user_blocked when host blocked player';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%user_blocked%' THEN
        RAISE;
      END IF;
  END;

  PERFORM set_config('request.jwt.claim.sub', v_host_id::text, true);
  PERFORM public.unblock_user(v_player_id);
  PERFORM set_config('request.jwt.claim.sub', v_player_id::text, true);

  v_status := public.join_session(v_session_id);

  IF v_status <> 'joined' THEN
    RAISE EXCEPTION 'join_session failed: expected joined after unblock, got %', v_status;
  END IF;

  DELETE FROM public.session_participants WHERE session_id = v_session_id;
  DELETE FROM public.sessions WHERE id = v_session_id;
  DELETE FROM public.user_blocks
  WHERE blocker_id IN (v_host_id, v_player_id)
     OR blocked_id IN (v_host_id, v_player_id);
  DELETE FROM public.profiles WHERE id IN (v_host_id, v_player_id);
  DELETE FROM auth.users WHERE id IN (v_host_id, v_player_id);

  PERFORM set_config('request.jwt.claim.sub', '', true);

  RAISE NOTICE 'phase_c_blocks: block prevents join OK';
END $$;
