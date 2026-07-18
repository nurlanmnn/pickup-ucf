-- Tier 2 Task T2-1: chat message notification trigger

DO $$
DECLARE
  v_host_id uuid := gen_random_uuid();
  v_sender_id uuid := gen_random_uuid();
  v_recipient_id uuid := gen_random_uuid();
  v_session_id uuid := gen_random_uuid();
  v_message_id uuid;
  v_count int;
  v_payload jsonb;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_trigger
    WHERE tgname = 'trg_notify_chat_message'
  ) THEN
    RAISE EXCEPTION 'trg_notify_chat_message not found';
  END IF;

  INSERT INTO auth.users (
    instance_id, id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at
  ) VALUES
  (
    '00000000-0000-0000-0000-000000000000',
    v_host_id, 'authenticated', 'authenticated',
    'test-chat-msg-host@knights.ucf.edu', '', now(), now(), now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    v_sender_id, 'authenticated', 'authenticated',
    'test-chat-msg-sender@knights.ucf.edu', '', now(), now(), now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    v_recipient_id, 'authenticated', 'authenticated',
    'test-chat-msg-recipient@knights.ucf.edu', '', now(), now(), now()
  );

  INSERT INTO public.profiles (id, display_name)
  VALUES
    (v_host_id, 'Chat Msg Host'),
    (v_sender_id, 'Chat Msg Sender'),
    (v_recipient_id, 'Chat Msg Recipient');

  INSERT INTO public.sessions (
    id, host_id, sport, starts_at, ends_at, capacity, skill_level, status
  ) VALUES (
    v_session_id, v_host_id, 'basketball',
    now() + interval '2 hours', now() + interval '3 hours',
    10, 'any', 'open'
  );

  INSERT INTO public.session_participants (session_id, user_id, role, status)
  VALUES
    (v_session_id, v_sender_id, 'player', 'joined'),
    (v_session_id, v_recipient_id, 'player', 'joined');

  SET LOCAL role authenticated;
  PERFORM set_config('request.jwt.claim.sub', v_sender_id::text, true);

  INSERT INTO public.messages (session_id, user_id, body)
  VALUES (v_session_id, v_sender_id, 'Anyone bringing a ball?')
  RETURNING id INTO v_message_id;

  SELECT count(*) INTO v_count
  FROM public.notification_outbox
  WHERE session_id = v_session_id
    AND type = 'chat_message'
    AND user_id = v_recipient_id;

  IF v_count <> 1 THEN
    RAISE EXCEPTION
      'chat_message trigger failed: expected 1 outbox row for recipient, got %',
      v_count;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.notification_outbox
  WHERE session_id = v_session_id
    AND type = 'chat_message'
    AND user_id = v_sender_id;

  IF v_count <> 0 THEN
    RAISE EXCEPTION
      'chat_message trigger failed: expected 0 outbox rows for sender, got %',
      v_count;
  END IF;

  SELECT payload INTO v_payload
  FROM public.notification_outbox
  WHERE session_id = v_session_id
    AND type = 'chat_message'
    AND user_id = v_recipient_id;

  IF v_payload->>'session_id' IS DISTINCT FROM v_session_id::text THEN
    RAISE EXCEPTION
      'chat_message payload failed: expected session_id %, got %',
      v_session_id, v_payload->>'session_id';
  END IF;

  IF v_payload->>'message_id' IS DISTINCT FROM v_message_id::text THEN
    RAISE EXCEPTION
      'chat_message payload failed: expected message_id %, got %',
      v_message_id, v_payload->>'message_id';
  END IF;

  IF COALESCE((v_payload->>'open_chat')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION
      'chat_message payload failed: expected open_chat true, got %',
      v_payload->>'open_chat';
  END IF;

  RESET role;

  DELETE FROM public.notification_outbox WHERE session_id = v_session_id;
  DELETE FROM public.messages WHERE session_id = v_session_id;
  DELETE FROM public.session_participants WHERE session_id = v_session_id;
  DELETE FROM public.sessions WHERE id = v_session_id;
  DELETE FROM public.profiles
  WHERE id IN (v_host_id, v_sender_id, v_recipient_id);
  DELETE FROM auth.users
  WHERE id IN (v_host_id, v_sender_id, v_recipient_id);

  PERFORM set_config('request.jwt.claim.sub', '', true);

  RAISE NOTICE 'phase_d_tier2: chat_message notification OK';
END $$;

-- Tier 2 Task T2-1: chat message notification skipped when pref off

DO $$
DECLARE
  v_host_id uuid := gen_random_uuid();
  v_sender_id uuid := gen_random_uuid();
  v_recipient_id uuid := gen_random_uuid();
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
    'test-chat-pref-off-host@knights.ucf.edu', '', now(), now(), now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    v_sender_id, 'authenticated', 'authenticated',
    'test-chat-pref-off-sender@knights.ucf.edu', '', now(), now(), now()
  ),
  (
    '00000000-0000-0000-0000-000000000000',
    v_recipient_id, 'authenticated', 'authenticated',
    'test-chat-pref-off-recipient@knights.ucf.edu', '', now(), now(), now()
  );

  INSERT INTO public.profiles (id, display_name)
  VALUES
    (v_host_id, 'Chat Pref Off Host'),
    (v_sender_id, 'Chat Pref Off Sender'),
    (v_recipient_id, 'Chat Pref Off Recipient');

  INSERT INTO public.notification_preferences (user_id, chat_messages)
  VALUES (v_recipient_id, false);

  INSERT INTO public.sessions (
    id, host_id, sport, starts_at, ends_at, capacity, skill_level, status
  ) VALUES (
    v_session_id, v_host_id, 'soccer',
    now() + interval '2 hours', now() + interval '3 hours',
    10, 'any', 'open'
  );

  INSERT INTO public.session_participants (session_id, user_id, role, status)
  VALUES
    (v_session_id, v_sender_id, 'player', 'joined'),
    (v_session_id, v_recipient_id, 'player', 'joined');

  SET LOCAL role authenticated;
  PERFORM set_config('request.jwt.claim.sub', v_sender_id::text, true);

  INSERT INTO public.messages (session_id, user_id, body)
  VALUES (v_session_id, v_sender_id, 'Still on for tonight?');

  SELECT count(*) INTO v_count
  FROM public.notification_outbox
  WHERE session_id = v_session_id
    AND type = 'chat_message';

  IF v_count <> 0 THEN
    RAISE EXCEPTION
      'chat_message pref off failed: expected 0 outbox rows, got %',
      v_count;
  END IF;

  RESET role;

  DELETE FROM public.notification_preferences WHERE user_id = v_recipient_id;
  DELETE FROM public.messages WHERE session_id = v_session_id;
  DELETE FROM public.session_participants WHERE session_id = v_session_id;
  DELETE FROM public.sessions WHERE id = v_session_id;
  DELETE FROM public.profiles
  WHERE id IN (v_host_id, v_sender_id, v_recipient_id);
  DELETE FROM auth.users
  WHERE id IN (v_host_id, v_sender_id, v_recipient_id);

  PERFORM set_config('request.jwt.claim.sub', '', true);

  RAISE NOTICE 'phase_d_tier2: chat_message skipped when pref off OK';
END $$;
