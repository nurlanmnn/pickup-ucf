DO $$
DECLARE
 v_host uuid:=gen_random_uuid(); v_game uuid:=gen_random_uuid();
 v_id uuid; v_created timestamptz; v_case text;
BEGIN
 INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
 VALUES('00000000-0000-0000-0000-000000000000',v_host,'authenticated','authenticated',v_host::text||'@ucf.edu','',now(),now(),now());
 INSERT INTO public.profiles(id,display_name) VALUES(v_host,'Message Field Test');
 INSERT INTO public.sessions(id,host_id,sport,starts_at,ends_at,capacity,skill_level,status)
 VALUES(v_game,v_host,'basketball',now()+interval '1 hour',now()+interval '2 hours',10,'any','open');
 INSERT INTO public.session_participants(session_id,user_id,role,status) VALUES(v_game,v_host,'host','joined');
 SET LOCAL role authenticated;
 PERFORM set_config('request.jwt.claim.sub',v_host::text,true);
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',v_host,'email',v_host::text||'@ucf.edu')::text,true);
 FOREACH v_case IN ARRAY ARRAY['infinity','-infinity','2099-01-01T00:00:00Z','2000-01-01T00:00:00Z'] LOOP
   BEGIN
     INSERT INTO public.messages(session_id,user_id,body,created_at)
     VALUES(v_game,v_host,'Forged message time',v_case::timestamptz);
     RAISE EXCEPTION 'participant can forge message timestamp';
   EXCEPTION WHEN insufficient_privilege THEN NULL;
   END;
 END LOOP;
 BEGIN
   INSERT INTO public.messages(id,session_id,user_id,body) VALUES(gen_random_uuid(),v_game,v_host,'Forged message identity');
   RAISE EXCEPTION 'participant can set server message identity';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 INSERT INTO public.messages(session_id,user_id,body) VALUES(v_game,v_host,'Valid SDK shaped send')
 RETURNING id,created_at INTO v_id,v_created;
 IF v_id IS NULL OR v_created IS NULL OR NOT isfinite(v_created) OR v_created<>now() THEN
   RAISE EXCEPTION 'server defaults or compatible send failed';
 END IF;
 RESET role;
 IF (SELECT count(*) FROM public.messages WHERE session_id=v_game)<>1 THEN
   RAISE EXCEPTION 'denied forged message persisted';
 END IF;
 RAISE NOTICE 'phase_u_message_fields: forged timestamp/identity denied; compatible server-default send OK';
END; $$;
