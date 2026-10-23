DO $$
DECLARE
 v_host uuid:=gen_random_uuid(); v_viewer uuid:=gen_random_uuid(); v_other uuid:=gen_random_uuid();
 v_game uuid:=gen_random_uuid(); v_history uuid:=gen_random_uuid();
BEGIN
 INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
 SELECT '00000000-0000-0000-0000-000000000000',u,'authenticated','authenticated',u::text||'@ucf.edu','',now(),now(),now()
 FROM unnest(ARRAY[v_host,v_viewer,v_other]) u;
 INSERT INTO public.profiles(id,display_name) SELECT u,'Ledger Access Test' FROM unnest(ARRAY[v_host,v_viewer,v_other]) u;
 INSERT INTO public.sessions(id,host_id,sport,starts_at,ends_at,capacity,skill_level,status)
 VALUES(v_game,v_host,'basketball',now()-interval '2 hours',now()-interval '1 hour',10,'any','completed'),
 (v_history,v_host,'basketball',now()-interval '3 days',now()-interval '2 days',10,'any','completed');
 INSERT INTO public.session_participants(session_id,user_id,role,status)
 VALUES(v_game,v_host,'host','joined'),(v_game,v_viewer,'player','joined'),(v_game,v_other,'player','joined'),(v_history,v_viewer,'player','joined');
 INSERT INTO public.attendance(session_id,user_id) VALUES(v_game,v_other),(v_history,v_viewer);
 INSERT INTO public.user_blocks(blocker_id,blocked_id) VALUES(v_viewer,v_other);
 SET LOCAL role authenticated;
 PERFORM set_config('request.jwt.claim.sub',v_viewer::text,true);
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',v_viewer,'email',v_viewer::text||'@ucf.edu')::text,true);
 BEGIN
   IF EXISTS(SELECT 1 FROM public.attendance WHERE session_id=v_game AND user_id=v_other) THEN
     RAISE EXCEPTION 'attendance ledger reveals blocked participant identity';
   END IF;
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 -- Released profile history reads exactly the caller's own attendance rows.
 IF (SELECT count(*) FROM public.attendance WHERE user_id=v_viewer)<>1
 OR NOT EXISTS(SELECT 1 FROM public.attendance a JOIN public.sessions s ON s.id=a.session_id
               WHERE a.user_id=v_viewer AND s.id=v_history) THEN
   RAISE EXCEPTION 'own profile attendance history unavailable';
 END IF;
 -- Released host form reads participants; RPC still owns writes.
 PERFORM set_config('request.jwt.claim.sub',v_host::text,true);
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',v_host,'email',v_host::text||'@ucf.edu')::text,true);
 IF (SELECT count(*) FROM public.session_participants WHERE session_id=v_game AND status='joined')<>3 THEN
   RAISE EXCEPTION 'host form roster changed';
 END IF;
 PERFORM public.submit_session_attendance(v_game,ARRAY[v_host,v_viewer,v_other]);
 PERFORM public.submit_session_attendance(v_game,ARRAY[v_host,v_viewer,v_other]);
 RESET role;
 IF (SELECT count(*) FROM public.attendance WHERE session_id=v_game)<>3
 OR NOT EXISTS(SELECT 1 FROM public.profiles WHERE id=v_viewer AND games_played=1) THEN
   RAISE EXCEPTION 'attendance RPC, retry or statistics changed';
 END IF;
 RAISE NOTICE 'phase_v_attendance_access: own history preserved, other ledger reads denied; host RPC/retry/statistics OK';
END; $$;
