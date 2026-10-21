-- Execute inside BEGIN/ROLLBACK; fixtures and forced-failure triggers never persist.
CREATE FUNCTION public.test_fail_host_insert() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF current_setting('pickup.test_fail_host', true) = 'on' AND NEW.role = 'host' THEN
    RAISE EXCEPTION 'synthetic_host_insert_failure';
  END IF;
  RETURN NEW;
END; $$;
CREATE TRIGGER test_fail_host_insert BEFORE INSERT ON public.session_participants
  FOR EACH ROW EXECUTE FUNCTION public.test_fail_host_insert();

DO $$
DECLARE
  v_host uuid := gen_random_uuid();
  v_other uuid := gen_random_uuid();
  v_request uuid := gen_random_uuid();
  v_failed_request uuid := gen_random_uuid();
  v_id uuid;
  v_replay uuid;
  v_before integer;
  v_payload jsonb := jsonb_build_object('sport','basketball','skill_level','any',
    'starts_at',now()+interval '2 hours','ends_at',now()+interval '3 hours',
    'capacity',10,'custom_location','Synthetic campus court','custom_lat',28.6,'custom_lng',-81.2);
  v_invalid jsonb;
BEGIN
  INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
  VALUES ('00000000-0000-0000-0000-000000000000',v_host,'authenticated','authenticated','atomic-host@ucf.edu','',now(),now(),now()),
         ('00000000-0000-0000-0000-000000000000',v_other,'authenticated','authenticated','atomic-outsider@example.com','',now(),now(),now());
  INSERT INTO public.profiles(id,display_name) VALUES(v_host,'Atomic Host'),(v_other,'Atomic Other');
  IF has_function_privilege('anon','public.create_session(uuid,jsonb)','execute')
     OR has_function_privilege('anon','pickup_private.create_session(uuid,jsonb)','execute')
     OR has_table_privilege('authenticated','pickup_private.session_creation_requests','INSERT') THEN
    RAISE EXCEPTION 'atomic creation privilege failure';
  END IF;
  SET LOCAL role authenticated;
  PERFORM set_config('request.jwt.claim.sub',v_other::text,true);
  BEGIN
    PERFORM public.create_session(v_request,v_payload);
    RAISE EXCEPTION 'non UCF caller accepted';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  PERFORM set_config('request.jwt.claim.sub',v_host::text,true);
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',v_host,'email','atomic-host@ucf.edu')::text,true);
  RESET role;
  UPDATE auth.users SET email_confirmed_at=NULL WHERE id=v_host;
  SET LOCAL role authenticated;
  BEGIN
    PERFORM public.create_session(gen_random_uuid(),v_payload);
    RAISE EXCEPTION 'unconfirmed account accepted';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  RESET role;
  UPDATE auth.users SET email_confirmed_at=now() WHERE id=v_host;
  INSERT INTO public.user_moderation_state(user_id,suspended_until,reason)
    VALUES(v_host,now()+interval '1 hour','Synthetic test');
  SET LOCAL role authenticated;
  BEGIN
    PERFORM public.create_session(gen_random_uuid(),v_payload);
    RAISE EXCEPTION 'suspended account accepted';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'account_suspended' THEN RAISE; END IF;
  END;
  RESET role;
  DELETE FROM public.user_moderation_state WHERE user_id=v_host;
  SET LOCAL role authenticated;
  v_id := public.create_session(v_request,v_payload);
  v_replay := public.create_session(v_request,v_payload);
  IF v_id <> v_replay OR (SELECT player_count FROM public.sessions WHERE id=v_id) <> 1
     OR (SELECT count(*) FROM public.session_participants WHERE session_id=v_id AND user_id=v_host AND role='host' AND status='joined') <> 1 THEN
    RAISE EXCEPTION 'atomic host/count/replay invariant failed';
  END IF;
  BEGIN
    PERFORM public.create_session(v_request,v_payload || '{"capacity":12}'::jsonb);
    RAISE EXCEPTION 'conflicting retry accepted';
  EXCEPTION WHEN SQLSTATE 'PT409' THEN NULL; END;
  UPDATE public.sessions SET notes='Edited after creation' WHERE id=v_id;
  IF public.create_session(v_request,v_payload) <> v_id THEN RAISE EXCEPTION 'edit changed retry identity'; END IF;

  FOREACH v_invalid IN ARRAY ARRAY[
    v_payload || '{"host_id":"00000000-0000-0000-0000-000000000000"}'::jsonb,
    v_payload || '{"capacity":1}'::jsonb,
    v_payload || '{"notes":42}'::jsonb,
    v_payload || '{"custom_location":{"nested":"value"}}'::jsonb, v_payload || '{"capacity":51}'::jsonb,
    v_payload || '{"custom_lat":91}'::jsonb, v_payload - 'custom_lng',
    v_payload || '{"sport":"other"}'::jsonb,
    v_payload || jsonb_build_object('starts_at',now()+interval '8 days','ends_at',now()+interval '8 days 1 hour'),
    v_payload || jsonb_build_object('ends_at',now()+interval '2 hours 14 minutes'),
    v_payload || '{"recurrence_rule":"{\"frequency\":\"weekly\",\"count\":5}"}'::jsonb,
    v_payload || jsonb_build_object('notes',repeat('x',1001))
  ] LOOP
    BEGIN
      PERFORM public.create_session(gen_random_uuid(),v_invalid);
      RAISE EXCEPTION 'invalid input accepted';
    EXCEPTION WHEN OTHERS THEN
      IF SQLERRM = 'invalid input accepted' THEN RAISE; END IF;
    END;
  END LOOP;

  PERFORM public.create_session(gen_random_uuid(),v_payload || '{"capacity":2}'::jsonb);
  PERFORM public.create_session(gen_random_uuid(),v_payload || '{"capacity":50}'::jsonb);
  PERFORM public.create_session(gen_random_uuid(),v_payload || '{"recurrence_rule":"{\"frequency\":\"weekly\",\"count\":2}"}'::jsonb);
  PERFORM public.create_session(gen_random_uuid(),v_payload || '{"sport":"other","custom_sport_name":"Synthetic sport"}'::jsonb);

  SELECT count(*) INTO v_before FROM public.sessions WHERE host_id=v_host;
  PERFORM set_config('pickup.test_fail_host','on',true);
  BEGIN
    PERFORM public.create_session(v_failed_request,v_payload);
    RAISE EXCEPTION 'host failure was not injected';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'synthetic_host_insert_failure' THEN RAISE; END IF;
  END;
  PERFORM set_config('pickup.test_fail_host','off',true);
  IF (SELECT count(*) FROM public.sessions WHERE host_id=v_host) <> v_before THEN
    RAISE EXCEPTION 'partial session survived host failure';
  END IF;
  v_replay := public.create_session(v_failed_request,v_payload);
  IF v_replay IS NULL THEN RAISE EXCEPTION 'rolled-back request could not retry'; END IF;
  RESET role;
  DELETE FROM public.sessions WHERE id=v_id;
  SET LOCAL role authenticated;
  BEGIN
    PERFORM public.create_session(v_request,v_payload);
    RAISE EXCEPTION 'deleted game was recreated';
  EXCEPTION WHEN SQLSTATE 'PT410' THEN NULL; END;
  RESET role;
  RAISE NOTICE 'phase_h_atomic_creation: validation, grants, rollback, replay, and tombstones OK';
END $$;
DROP TRIGGER test_fail_host_insert ON public.session_participants;
DROP FUNCTION public.test_fail_host_insert();
