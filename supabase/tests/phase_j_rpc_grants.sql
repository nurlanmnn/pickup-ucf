DO $$
BEGIN
  IF has_function_privilege('anon','public.enqueue_notification(uuid,uuid,text,text,text,text,jsonb)','EXECUTE')
     OR has_function_privilege('authenticated','public.enqueue_notification(uuid,uuid,text,text,text,text,jsonb)','EXECUTE')
     OR has_function_privilege('anon','public.join_session(uuid)','EXECUTE')
     OR has_function_privilege('authenticated','public.spawn_next_recurring_session(uuid)','EXECUTE') THEN
    RAISE EXCEPTION 'internal notification/lifecycle RPC or authenticated mutation exposed';
  END IF;
  IF NOT has_function_privilege('authenticated','public.join_session(uuid)','EXECUTE')
     OR NOT has_function_privilege('service_role','public.enqueue_session_reminders(text)','EXECUTE') THEN
    RAISE EXCEPTION 'required RPC grant missing';
  END IF;
END; $$;
SET LOCAL role anon;
DO $$ BEGIN
  BEGIN
    PERFORM public.enqueue_notification(gen_random_uuid(),NULL,'chat_message','Synthetic','Synthetic',gen_random_uuid()::text);
    RAISE EXCEPTION 'anonymous enqueue callable';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END; $$;
RESET role;
SET LOCAL role authenticated;
DO $$ BEGIN
  BEGIN
    PERFORM public.complete_expired_sessions();
    RAISE EXCEPTION 'ordinary user can invoke global maintenance';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
END; $$;
RESET role;
DO $$ BEGIN
  IF has_table_privilege('authenticated','public.sessions','INSERT')
     OR has_table_privilege('authenticated','public.session_participants','INSERT')
     OR has_column_privilege('authenticated','public.sessions','player_count','UPDATE')
     OR has_column_privilege('authenticated','public.profiles','games_played','UPDATE') THEN
    RAISE EXCEPTION 'server-owned membership/count/statistics remain client writable';
  END IF;
END; $$;
DO $$
DECLARE v_user uuid := gen_random_uuid();
BEGIN
  INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
  VALUES ('00000000-0000-0000-0000-000000000000',v_user,'authenticated','authenticated','grants@ucf.edu','',now(),now(),now());
  SET LOCAL role authenticated;
  PERFORM set_config('request.jwt.claim.sub',v_user::text,true);
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',v_user,'email','grants@ucf.edu')::text,true);
  INSERT INTO public.profiles(id,display_name) VALUES(v_user,'Grant Test')
    ON CONFLICT(id) DO UPDATE SET id=EXCLUDED.id,display_name=EXCLUDED.display_name;
  UPDATE public.profiles SET preferred_sports=ARRAY['basketball'::public.sport_type] WHERE id=v_user;
  BEGIN
    UPDATE public.profiles SET games_played=999 WHERE id=v_user;
    RAISE EXCEPTION 'crafted statistics update allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  BEGIN
    INSERT INTO public.session_participants(session_id,user_id,role,status)
      VALUES(gen_random_uuid(),v_user,'host','joined');
    RAISE EXCEPTION 'crafted host membership allowed';
  EXCEPTION WHEN insufficient_privilege THEN NULL; END;
  RESET role;
END; $$;
-- An otherwise valid, unexpired JWT may survive auth-user deletion. School
-- membership must use current server account data, not the old email claim.
SET LOCAL role authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000009999',true);
SELECT set_config('request.jwt.claims','{"sub":"00000000-0000-0000-0000-000000009999","email":"deleted@ucf.edu"}',true);
DO $$ BEGIN
  IF public.is_ucf_email() OR EXISTS(SELECT 1 FROM public.venues) THEN
    RAISE EXCEPTION 'deleted account email claim still authorizes school data';
  END IF;
END; $$;
RESET role;
DO $$ BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public' AND NOT EXISTS (
      SELECT 1 FROM pg_depend d WHERE d.classid='pg_proc'::regclass AND d.objid=p.oid AND d.deptype='e'
    ) AND (has_function_privilege('anon',p.oid,'EXECUTE') OR NOT EXISTS (
      SELECT 1 FROM unnest(p.proconfig) AS setting WHERE setting LIKE 'search_path=%'
    ))
  ) THEN RAISE EXCEPTION 'application function has anonymous execution or mutable search path'; END IF;
END; $$;
