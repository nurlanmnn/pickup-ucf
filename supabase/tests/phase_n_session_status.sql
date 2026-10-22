DO $$
DECLARE v_host uuid:=gen_random_uuid(); v_session uuid;
BEGIN
 INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
 VALUES('00000000-0000-0000-0000-000000000000',v_host,'authenticated','authenticated','status-host@ucf.edu','',now(),now(),now());
 INSERT INTO public.profiles(id,display_name) VALUES(v_host,'Status Host');
 SET LOCAL role authenticated;
 PERFORM set_config('request.jwt.claim.sub',v_host::text,true);
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',v_host,'email','status-host@ucf.edu')::text,true);
 v_session:=public.create_session(gen_random_uuid(),jsonb_build_object('sport','basketball','skill_level','any',
   'starts_at',now()+interval '2 hours','ends_at',now()+interval '3 hours','capacity',2,
   'custom_location','Court','custom_lat',28.6,'custom_lng',-81.2));
 BEGIN
   UPDATE public.sessions SET status='completed' WHERE id=v_session;
   RAISE EXCEPTION 'client completed a game outside attendance RPC';
 EXCEPTION WHEN OTHERS THEN
   IF SQLERRM <> 'invalid_session_status_transition' THEN RAISE; END IF;
 END;
 UPDATE public.sessions SET status='cancelled' WHERE id=v_session;
 UPDATE public.sessions SET status='cancelled' WHERE id=v_session;
 BEGIN
   UPDATE public.sessions SET status='open' WHERE id=v_session;
   RAISE EXCEPTION 'client reopened cancelled game';
 EXCEPTION WHEN OTHERS THEN
   IF SQLERRM <> 'session_not_editable' THEN RAISE; END IF;
 END;
 BEGIN
   UPDATE public.sessions SET notes='Changed after cancellation' WHERE id=v_session;
   RAISE EXCEPTION 'client edited closed content';
 EXCEPTION WHEN OTHERS THEN
   IF SQLERRM <> 'session_not_editable' THEN RAISE; END IF;
 END;
 RESET role;
 UPDATE public.sessions SET status='full',player_count=2 WHERE id=v_session;
 SET LOCAL role authenticated;
 UPDATE public.sessions SET capacity=4 WHERE id=v_session;
 IF (SELECT status FROM public.sessions WHERE id=v_session) <> 'open' THEN
   RAISE EXCEPTION 'capacity edit left incorrect full status';
 END IF;
 RESET role;
 RAISE NOTICE 'phase_n_session_status: client transitions and capacity status OK';
END; $$;
