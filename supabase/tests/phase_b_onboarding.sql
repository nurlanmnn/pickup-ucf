-- Phase B Task B3: complete_onboarding RPC
DO $$
DECLARE
  v_user_id uuid := gen_random_uuid();
  v_completed_at timestamptz;
  v_sports sport_type[];
  v_skill skill_level;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'complete_onboarding'
  ) THEN
    RAISE EXCEPTION 'complete_onboarding function not found';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'profiles'
      AND column_name = 'onboarding_completed_at'
  ) THEN
    RAISE EXCEPTION 'onboarding_completed_at column not found';
  END IF;

  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at
  ) VALUES (
    '00000000-0000-0000-0000-000000000000',
    v_user_id, 'authenticated', 'authenticated',
    'test-onboarding@knights.ucf.edu', '', now(), now(), now()
  );

  INSERT INTO public.profiles (id, display_name)
  VALUES (v_user_id, 'Onboarding Test User');

  PERFORM set_config('request.jwt.claim.sub', '', true);

  BEGIN
    PERFORM public.complete_onboarding(
      ARRAY['basketball']::sport_type[],
      'beginner'::skill_level
    );
    RAISE EXCEPTION 'complete_onboarding failed: expected not_authenticated';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%not_authenticated%' THEN
        RAISE;
      END IF;
  END;

  PERFORM set_config('request.jwt.claim.sub', v_user_id::text, true);

  BEGIN
    PERFORM public.complete_onboarding(NULL, 'beginner'::skill_level);
    RAISE EXCEPTION 'complete_onboarding failed: expected preferred_sports_required for NULL';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%preferred_sports_required%' THEN
        RAISE;
      END IF;
  END;

  BEGIN
    PERFORM public.complete_onboarding(
      ARRAY[]::sport_type[],
      'beginner'::skill_level
    );
    RAISE EXCEPTION 'complete_onboarding failed: expected preferred_sports_required for empty array';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%preferred_sports_required%' THEN
        RAISE;
      END IF;
  END;

  PERFORM public.complete_onboarding(
    ARRAY['basketball', 'pickleball']::sport_type[],
    'intermediate'::skill_level
  );

  SELECT onboarding_completed_at, preferred_sports, skill_level
  INTO v_completed_at, v_sports, v_skill
  FROM public.profiles
  WHERE id = v_user_id;

  IF v_completed_at IS NULL THEN
    RAISE EXCEPTION 'complete_onboarding failed: onboarding_completed_at not set';
  END IF;

  IF array_length(v_sports, 1) <> 2 THEN
    RAISE EXCEPTION 'complete_onboarding failed: preferred_sports not updated';
  END IF;

  IF v_skill <> 'intermediate' THEN
    RAISE EXCEPTION 'complete_onboarding failed: skill_level not updated to intermediate';
  END IF;

  DELETE FROM public.profiles WHERE id = v_user_id;
  DELETE FROM auth.users WHERE id = v_user_id;

  PERFORM set_config('request.jwt.claim.sub', '', true);

  RAISE NOTICE 'phase_b_onboarding: complete_onboarding OK';
END $$;
