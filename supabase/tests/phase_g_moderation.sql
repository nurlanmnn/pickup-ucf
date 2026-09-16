-- EXT-01: UGC policy, typed reports, rate limits, blocking, and moderator access.

DO $$
DECLARE
  v_host_id uuid := gen_random_uuid();
  v_reporter_id uuid := gen_random_uuid();
  v_other_id uuid := gen_random_uuid();
  v_moderator_id uuid := gen_random_uuid();
  v_session_id uuid := gen_random_uuid();
  v_message_id uuid := gen_random_uuid();
  v_report_id uuid;
  v_warning_report_id uuid;
  v_notice_id uuid;
  v_count int;
BEGIN
  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at
  ) VALUES
    ('00000000-0000-0000-0000-000000000000', v_host_id, 'authenticated', 'authenticated', 'ext01-host@knights.ucf.edu', '', now(), now(), now()),
    ('00000000-0000-0000-0000-000000000000', v_reporter_id, 'authenticated', 'authenticated', 'ext01-reporter@knights.ucf.edu', '', now(), now(), now()),
    ('00000000-0000-0000-0000-000000000000', v_other_id, 'authenticated', 'authenticated', 'ext01-other@knights.ucf.edu', '', now(), now(), now()),
    ('00000000-0000-0000-0000-000000000000', v_moderator_id, 'authenticated', 'authenticated', 'ext01-moderator@knights.ucf.edu', '', now(), now(), now());

  INSERT INTO public.profiles (id, display_name)
  VALUES
    (v_host_id, 'EXT Host'),
    (v_reporter_id, 'EXT Reporter'),
    (v_other_id, 'EXT Other'),
    (v_moderator_id, 'EXT Moderator');

  INSERT INTO public.sessions (
    id, host_id, sport, starts_at, ends_at, capacity, player_count, skill_level, status
  ) VALUES (
    v_session_id, v_host_id, 'basketball', now() + interval '2 hours',
    now() + interval '3 hours', 8, 2, 'any', 'open'
  );

  INSERT INTO public.session_participants (session_id, user_id, role, status)
  VALUES
    (v_session_id, v_host_id, 'host', 'joined'),
    (v_session_id, v_reporter_id, 'player', 'joined');

  INSERT INTO public.messages (id, session_id, user_id, body)
  VALUES (v_message_id, v_session_id, v_host_id, 'Meet by the north court.');

  SET LOCAL role authenticated;
  PERFORM set_config('request.jwt.claim.sub', v_reporter_id::text, true);

  BEGIN
    INSERT INTO public.messages (session_id, user_id, body)
    VALUES (v_session_id, v_reporter_id, 'I will k1ll you');
    RAISE EXCEPTION 'moderation failed: abusive message was accepted';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%user_content_rejected%' THEN RAISE; END IF;
  END;

  v_report_id := public.submit_moderation_report(
    'message', v_message_id, 'harassment', 'Repeated insults after the game.'
  );

  BEGIN
    PERFORM public.submit_moderation_report('user', v_reporter_id, 'other', NULL);
    RAISE EXCEPTION 'moderation failed: self-target false report was accepted';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%invalid_report_target%' THEN RAISE; END IF;
  END;

  BEGIN
    PERFORM public.submit_moderation_report('message', v_message_id, 'spam', NULL);
    RAISE EXCEPTION 'moderation failed: duplicate report was accepted';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%report_already_submitted%' THEN RAISE; END IF;
  END;

  v_warning_report_id := public.submit_moderation_report('session', v_session_id, 'unsafe_behavior', NULL);
  PERFORM public.submit_moderation_report('user', v_host_id, 'impersonation', NULL);
  PERFORM public.submit_moderation_report('user', v_other_id, 'other', NULL);
  PERFORM public.submit_moderation_report('user', v_moderator_id, 'other', NULL);

  BEGIN
    PERFORM public.submit_moderation_report('user', v_reporter_id, 'other', NULL);
    RAISE EXCEPTION 'moderation failed: sixth report bypassed the hourly limit';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%report_rate_limited%' THEN RAISE; END IF;
  END;

  BEGIN
    PERFORM 1 FROM public.moderation_reports LIMIT 1;
    RAISE EXCEPTION 'moderation failed: authenticated client read private report table';
  EXCEPTION
    WHEN insufficient_privilege THEN NULL;
  END;

  BEGIN
    PERFORM * FROM public.list_moderation_reports(20);
    RAISE EXCEPTION 'moderation failed: non-moderator listed reports';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%moderator_required%' THEN RAISE; END IF;
  END;

  PERFORM public.block_user(v_host_id);
  IF EXISTS (SELECT 1 FROM public.messages WHERE id = v_message_id) THEN
    RAISE EXCEPTION 'moderation failed: blocked author message remained visible';
  END IF;
  IF EXISTS (SELECT 1 FROM public.sessions WHERE id = v_session_id) THEN
    RAISE EXCEPTION 'moderation failed: blocked host session remained visible';
  END IF;

  PERFORM public.enqueue_notification(
    v_reporter_id, v_session_id, 'chat_message', 'New message', 'Hidden body',
    'ext01-blocked-notification', jsonb_build_object('actor_user_id', v_host_id)
  );
  RESET role;

  IF EXISTS (SELECT 1 FROM public.notification_outbox WHERE dedupe_key = 'ext01-blocked-notification') THEN
    RAISE EXCEPTION 'moderation failed: blocked actor notification was queued';
  END IF;

  INSERT INTO public.moderator_accounts (user_id, created_by)
  VALUES (v_moderator_id, v_moderator_id);

  SET LOCAL role authenticated;
  PERFORM set_config('request.jwt.claim.sub', v_moderator_id::text, true);
  SELECT count(*) INTO v_count FROM public.list_moderation_reports(20);
  IF v_count <> 5 THEN
    RAISE EXCEPTION 'moderation failed: moderator expected 5 reports, got %', v_count;
  END IF;

  PERFORM public.moderate_report(v_report_id, 'suspend_user', 'Credible repeated harassment.', 24);
  PERFORM public.moderate_report(v_warning_report_id, 'warn_user', 'Unsafe meetup instructions.', NULL);
  RESET role;

  IF NOT EXISTS (
    SELECT 1 FROM public.user_moderation_state
    WHERE user_id = v_host_id AND suspended_until > now()
  ) THEN
    RAISE EXCEPTION 'moderation failed: suspension was not recorded';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.moderation_actions
    WHERE report_id = v_report_id AND moderator_id = v_moderator_id
  ) THEN
    RAISE EXCEPTION 'moderation failed: action audit was not recorded';
  END IF;

  SET LOCAL role authenticated;
  PERFORM set_config('request.jwt.claim.sub', v_host_id::text, true);
  SELECT count(*) INTO v_count FROM public.list_my_moderation_notices();
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'moderation failed: expected warning and suspension notices, got %', v_count;
  END IF;
  SELECT id INTO v_notice_id FROM public.list_my_moderation_notices() ORDER BY created_at, id LIMIT 1;
  PERFORM public.acknowledge_moderation_notice(v_notice_id);
  SELECT count(*) INTO v_count FROM public.list_my_moderation_notices();
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'moderation failed: notice acknowledgement was not scoped correctly';
  END IF;
  BEGIN
    PERFORM public.submit_moderation_report('user', v_other_id, 'other', NULL);
    RAISE EXCEPTION 'moderation failed: suspended user submitted a report';
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLERRM NOT LIKE '%account_suspended%' THEN RAISE; END IF;
  END;
  RESET role;

  DELETE FROM auth.users WHERE id = v_other_id;
  IF NOT EXISTS (SELECT 1 FROM public.moderation_reports WHERE target_user_id = v_other_id) THEN
    RAISE EXCEPTION 'moderation failed: report retention changed after account deletion';
  END IF;

  DELETE FROM public.moderation_actions WHERE report_id IN (SELECT id FROM public.moderation_reports WHERE reporter_id = v_reporter_id);
  DELETE FROM public.user_moderation_notices WHERE user_id IN (v_host_id, v_reporter_id, v_other_id, v_moderator_id);
  DELETE FROM public.moderation_reports WHERE reporter_id = v_reporter_id;
  DELETE FROM public.user_moderation_state WHERE user_id IN (v_host_id, v_reporter_id, v_other_id, v_moderator_id);
  DELETE FROM public.moderator_accounts WHERE user_id = v_moderator_id;
  DELETE FROM public.notification_outbox WHERE session_id = v_session_id;
  DELETE FROM public.messages WHERE session_id = v_session_id;
  DELETE FROM public.session_participants WHERE session_id = v_session_id;
  DELETE FROM public.sessions WHERE id = v_session_id;
  DELETE FROM public.user_blocks WHERE blocker_id = v_reporter_id OR blocked_id = v_reporter_id;
  DELETE FROM auth.users WHERE id IN (v_host_id, v_reporter_id, v_moderator_id);

  PERFORM set_config('request.jwt.claim.sub', '', true);
  RAISE NOTICE 'phase_g_moderation: policy, reports, blocking, and moderator controls OK';
END $$;
