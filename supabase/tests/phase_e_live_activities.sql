-- Live Activity tokens are registered only for the signed-in session host or player.
DO $$
DECLARE
  v_host_id uuid := gen_random_uuid();
  v_player_id uuid := gen_random_uuid();
  v_outsider_id uuid := gen_random_uuid();
  v_session_id uuid := gen_random_uuid();
  v_starts_at timestamptz := now() + interval '1 hour';
  v_ends_at timestamptz := now() + interval '2 hours';
  v_rescheduled_end timestamptz := now() + interval '3 hours';
  v_player_token text := repeat('ab', 32);
  v_host_token text := repeat('cd', 32);
  v_count int;
  v_saved_start timestamptz;
  v_saved_end timestamptz;
BEGIN
  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at
  ) VALUES
  (
    '00000000-0000-0000-0000-000000000000',
    v_host_id, 'authenticated', 'authenticated',
    'test-live-host@knights.ucf.edu', '', now(), now(), now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    v_player_id, 'authenticated', 'authenticated',
    'test-live-player@knights.ucf.edu', '', now(), now(), now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    v_outsider_id, 'authenticated', 'authenticated',
    'test-live-outsider@knights.ucf.edu', '', now(), now(), now()
  );

  INSERT INTO public.profiles (id, display_name)
  VALUES
    (v_host_id, 'Live Host'),
    (v_player_id, 'Live Player'),
    (v_outsider_id, 'Live Outsider');

  INSERT INTO public.sessions (
    id, host_id, sport, starts_at, ends_at, capacity, skill_level, status
  ) VALUES (
    v_session_id, v_host_id, 'basketball', v_starts_at, v_ends_at,
    10, 'any', 'open'
  );

  INSERT INTO public.session_participants (session_id, user_id, role, status)
  VALUES (v_session_id, v_player_id, 'player', 'joined');

  SET LOCAL role authenticated;
  PERFORM set_config('request.jwt.claim.sub', v_outsider_id::text, true);

  BEGIN
    PERFORM public.register_live_activity_token(v_session_id, repeat('ef', 32));
    RAISE EXCEPTION 'register_live_activity_token allowed a non-participant';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%live_activity_session_not_available%' THEN
        RAISE;
      END IF;
  END;

  PERFORM set_config('request.jwt.claim.sub', v_player_id::text, true);
  PERFORM public.register_live_activity_token(v_session_id, upper(v_player_token));

  PERFORM set_config('request.jwt.claim.sub', v_host_id::text, true);
  PERFORM public.register_live_activity_token(v_session_id, v_host_token);

  RESET role;

  SELECT count(*) INTO v_count
  FROM public.live_activity_tokens
  WHERE session_id = v_session_id;

  IF v_count <> 2 THEN
    RAISE EXCEPTION 'expected host and player tokens, got %', v_count;
  END IF;

  SELECT starts_at, ends_at
  INTO v_saved_start, v_saved_end
  FROM public.live_activity_tokens
  WHERE user_id = v_player_id
    AND session_id = v_session_id
    AND apns_token = v_player_token;

  IF v_saved_start IS DISTINCT FROM v_starts_at
     OR v_saved_end IS DISTINCT FROM v_ends_at THEN
    RAISE EXCEPTION 'registration did not use canonical session timestamps';
  END IF;

  UPDATE public.sessions
  SET ends_at = v_rescheduled_end
  WHERE id = v_session_id;

  SELECT ends_at INTO v_saved_end
  FROM public.live_activity_tokens
  WHERE user_id = v_player_id
    AND session_id = v_session_id;

  IF v_saved_end IS DISTINCT FROM v_rescheduled_end THEN
    RAISE EXCEPTION 'session schedule update did not sync Live Activity end';
  END IF;

  -- Moving outside the final-hour window must end the current activity.
  UPDATE public.sessions SET starts_at = now() + interval '19 hours',
    ends_at = now() + interval '20 hours' WHERE id = v_session_id;
  IF EXISTS (SELECT 1 FROM public.live_activity_tokens
    WHERE session_id = v_session_id AND ends_at > now()) THEN
    RAISE EXCEPTION 'reschedule outside final hour did not end activities';
  END IF;
  SET LOCAL role authenticated;
  PERFORM set_config('request.jwt.claim.sub', v_player_id::text, true);
  BEGIN
    PERFORM public.register_live_activity_token(v_session_id, repeat('34', 32));
    RAISE EXCEPTION 'allowed activity registration 19 hours early';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%live_activity_session_not_available%' THEN RAISE; END IF;
  END;
  RESET role;
  UPDATE public.sessions SET starts_at = v_starts_at, ends_at = v_rescheduled_end
  WHERE id = v_session_id;

  SET LOCAL role authenticated;
  PERFORM set_config('request.jwt.claim.sub', v_player_id::text, true);
  PERFORM public.register_live_activity_token(v_session_id, v_player_token);
  RESET role;
  IF EXISTS (SELECT 1 FROM public.live_activity_tokens
    WHERE session_id = v_session_id AND ends_at > now()) THEN
    RAISE EXCEPTION 'schedule edit or registration revived an activity already due to end';
  END IF;

  -- A second device must not overwrite the first device's end-push token.
  SET LOCAL role authenticated;
  PERFORM set_config('request.jwt.claim.sub', v_player_id::text, true);
  PERFORM public.register_live_activity_token(v_session_id, repeat('12', 32));
  RESET role;
  SELECT count(*) INTO v_count FROM public.live_activity_tokens
  WHERE session_id = v_session_id AND user_id = v_player_id;
  IF v_count <> 2 THEN RAISE EXCEPTION 'second device overwrote first activity'; END IF;

  PERFORM public.enqueue_notification(v_player_id, v_session_id, 'session_reminder_1h',
    'Game soon', 'Reminder', 'lifecycle-pending:' || v_session_id);
  IF NOT EXISTS (SELECT 1 FROM public.notification_outbox WHERE session_id = v_session_id
    AND payload ? 'session_ends_at' AND payload ? 'session_starts_at') THEN
    RAISE EXCEPTION 'notification payload is missing canonical timestamps';
  END IF;

  -- Leaving on another device makes every player activity immediately due to end.
  UPDATE public.session_participants SET status = 'left'
  WHERE session_id = v_session_id AND user_id = v_player_id;
  IF EXISTS (SELECT 1 FROM public.live_activity_tokens
    WHERE session_id = v_session_id AND user_id = v_player_id AND ends_at > now()) THEN
    RAISE EXCEPTION 'departed player activities were not ended';
  END IF;

  IF EXISTS (SELECT 1 FROM public.notification_outbox WHERE session_id = v_session_id
    AND user_id = v_player_id AND type = 'session_reminder_1h' AND sent_at IS NULL) THEN
    RAISE EXCEPTION 'leaving did not remove an unsent reminder';
  END IF;

  SET LOCAL role authenticated;
  PERFORM set_config('request.jwt.claim.sub', v_player_id::text, true);
  BEGIN
    PERFORM public.register_live_activity_token(v_session_id, repeat('56', 32));
    RAISE EXCEPTION 'allowed departed player activity registration';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM NOT LIKE '%live_activity_session_not_available%' THEN RAISE; END IF;
  END;
  RESET role;

  UPDATE public.sessions SET status = 'completed' WHERE id = v_session_id;
  IF EXISTS (SELECT 1 FROM public.live_activity_tokens
    WHERE session_id = v_session_id AND ends_at > now()) THEN
    RAISE EXCEPTION 'completed session activities were not ended';
  END IF;
  PERFORM public.enqueue_finished_session_cleanup();
  PERFORM public.enqueue_finished_session_cleanup();
  SELECT count(*) INTO v_count FROM public.notification_outbox
  WHERE session_id = v_session_id AND type = 'session_finished';
  IF v_count <> 2 THEN RAISE EXCEPTION 'cleanup must be deduplicated per player/host'; END IF;

  DELETE FROM public.sessions WHERE id = v_session_id;
  DELETE FROM public.profiles
  WHERE id IN (v_host_id, v_player_id, v_outsider_id);
  DELETE FROM auth.users
  WHERE id IN (v_host_id, v_player_id, v_outsider_id);

  PERFORM set_config('request.jwt.claim.sub', '', true);

  RAISE NOTICE 'phase_e_live_activities: registration and schedule sync OK';
END $$;
