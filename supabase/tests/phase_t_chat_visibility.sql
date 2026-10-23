DO $$
DECLARE
 v_host uuid:=gen_random_uuid(); v_viewer uuid:=gen_random_uuid(); v_other uuid:=gen_random_uuid();
 v_outsider uuid:=gen_random_uuid(); v_game uuid:=gen_random_uuid(); v_past uuid:=gen_random_uuid();
 v_count int; v_actor uuid;
BEGIN
 INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
 SELECT '00000000-0000-0000-0000-000000000000',u,'authenticated','authenticated',u::text||'@ucf.edu','',now(),now(),now()
 FROM unnest(ARRAY[v_host,v_viewer,v_other,v_outsider]) u;
 INSERT INTO public.profiles(id,display_name)
 SELECT u,'Chat Visibility Test' FROM unnest(ARRAY[v_host,v_viewer,v_other,v_outsider]) u;
 INSERT INTO public.sessions(id,host_id,sport,starts_at,ends_at,capacity,skill_level,status)
 VALUES(v_game,v_host,'basketball',now()+interval '1 hour',now()+interval '2 hours',10,'any','open'),
 (v_past,NULL,'basketball',now()-interval '2 days',now()-interval '1 day',10,'any','cancelled');
 INSERT INTO public.session_participants(session_id,user_id,role,status)
 VALUES(v_game,v_host,'host','joined'),(v_game,v_viewer,'player','joined'),
 (v_game,v_other,'player','joined'),(v_past,v_viewer,'player','joined');
 INSERT INTO public.messages(session_id,user_id,body)
 VALUES(v_game,v_host,'Host message'),(v_game,v_other,'Other player message'),(v_past,v_other,'Retained message');
 SET LOCAL role authenticated;
 PERFORM set_config('request.jwt.claim.sub',v_viewer::text,true);
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',v_viewer,'email',v_viewer::text||'@ucf.edu')::text,true);
 IF (SELECT count(*) FROM public.messages WHERE session_id=v_game) <> 2 THEN
   RAISE EXCEPTION 'visible chat read changed';
 END IF;
 INSERT INTO public.messages(session_id,user_id,body) VALUES(v_game,v_viewer,'Visible player send');
 IF NOT EXISTS(SELECT 1 FROM public.messages WHERE session_id=v_past) THEN
   RAISE EXCEPTION 'retained null-host chat unavailable';
 END IF;
 RESET role;
 -- Each direction must hide the game and all messages, not just the host author.
 FOREACH v_actor IN ARRAY ARRAY[v_viewer,v_host] LOOP
   INSERT INTO public.user_blocks(blocker_id,blocked_id)
   VALUES(v_actor,CASE WHEN v_actor=v_viewer THEN v_host ELSE v_viewer END);
   SET LOCAL role authenticated;
   IF EXISTS(SELECT 1 FROM public.sessions WHERE id=v_game) THEN RAISE EXCEPTION 'blocked host game visible'; END IF;
   IF EXISTS(SELECT 1 FROM public.messages WHERE session_id=v_game) THEN
     RAISE EXCEPTION 'blocked host game still exposes chat messages';
   END IF;
   BEGIN
     INSERT INTO public.messages(session_id,user_id,body) VALUES(v_game,v_viewer,'Denied hidden game send');
     RAISE EXCEPTION 'blocked host game still accepts chat sends';
   EXCEPTION WHEN insufficient_privilege THEN NULL;
   END;
   RESET role;
   DELETE FROM public.user_blocks WHERE blocker_id=v_actor;
 END LOOP;
 INSERT INTO public.user_blocks(blocker_id,blocked_id) VALUES(v_viewer,v_other);
 UPDATE public.session_participants SET status='waitlist' WHERE session_id=v_game AND user_id=v_viewer;
 SET LOCAL role authenticated;
 IF EXISTS(SELECT 1 FROM public.messages WHERE session_id=v_game AND user_id=v_other)
 OR NOT EXISTS(SELECT 1 FROM public.messages WHERE session_id=v_game AND user_id=v_host) THEN
   RAISE EXCEPTION 'blocked author filter or waitlist read changed';
 END IF;
 INSERT INTO public.messages(session_id,user_id,body) VALUES(v_game,v_viewer,'Waitlisted player send');
 RESET role;
 UPDATE auth.users SET email_confirmed_at=NULL WHERE id=v_viewer;
 SET LOCAL role authenticated;
 IF EXISTS(SELECT 1 FROM public.messages WHERE session_id IN(v_game,v_past)) THEN
   RAISE EXCEPTION 'unconfirmed existing member can read chat';
 END IF;
 BEGIN
   INSERT INTO public.messages(session_id,user_id,body) VALUES(v_game,v_viewer,'Denied unconfirmed send');
   RAISE EXCEPTION 'unconfirmed existing member can send chat';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 PERFORM set_config('request.jwt.claim.sub',v_outsider::text,true);
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',v_outsider,'email',v_outsider::text||'@ucf.edu')::text,true);
 IF EXISTS(SELECT 1 FROM public.messages WHERE session_id=v_game) THEN RAISE EXCEPTION 'outsider reads chat'; END IF;
 BEGIN
   INSERT INTO public.messages(session_id,user_id,body) VALUES(v_game,v_outsider,'Denied outsider send');
   RAISE EXCEPTION 'outsider sends chat';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 RESET role;
 RAISE NOTICE 'phase_t_chat_visibility: host blocking, account confirmation, membership and retained chat OK';
END; $$;
