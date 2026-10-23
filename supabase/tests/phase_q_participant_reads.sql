-- Direct table reads must not bypass roster/session visibility.
DO $$
DECLARE
 v_host uuid:=gen_random_uuid(); v_viewer uuid:=gen_random_uuid();
 v_joined uuid:=gen_random_uuid(); v_waiter uuid:=gen_random_uuid();
 v_open uuid:=gen_random_uuid(); v_past uuid:=gen_random_uuid();
 v_roster jsonb;
BEGIN
 INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
 SELECT '00000000-0000-0000-0000-000000000000',u,'authenticated','authenticated',u::text||'@ucf.edu','',now(),now(),now()
 FROM unnest(ARRAY[v_host,v_viewer,v_joined,v_waiter]) u;
 INSERT INTO public.profiles(id,display_name)
 SELECT u,'Participant Read Test' FROM unnest(ARRAY[v_host,v_viewer,v_joined,v_waiter]) u;
 INSERT INTO public.sessions(id,host_id,sport,starts_at,ends_at,capacity,skill_level,status)
 VALUES(v_open,v_host,'basketball',now()+interval '1 hour',now()+interval '2 hours',10,'any','open'),
       (v_past,v_host,'basketball',now()-interval '2 days',now()-interval '1 day',10,'any','completed');
 INSERT INTO public.session_participants(session_id,user_id,role,status)
 VALUES(v_open,v_host,'host','joined'),(v_open,v_joined,'player','joined'),
       (v_open,v_waiter,'player','waitlist'),(v_past,v_joined,'player','joined');
 UPDATE public.session_participants SET joined_at=now()-interval '1 hour'
 WHERE session_id=v_open AND user_id=v_waiter;
 SET LOCAL role authenticated;
 PERFORM set_config('request.jwt.claim.sub',v_viewer::text,true);
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',v_viewer,'email',v_viewer::text||'@ucf.edu')::text,true);
 IF EXISTS(SELECT 1 FROM public.session_participants WHERE session_id=v_past) THEN
   RAISE EXCEPTION 'direct participant read exposes inaccessible historical game';
 END IF;
 IF EXISTS(SELECT 1 FROM public.session_participants WHERE session_id=v_open AND user_id=v_waiter) THEN
   RAISE EXCEPTION 'direct participant read exposes another waitlist identity';
 END IF;
 IF (SELECT count(*) FROM public.session_participants WHERE session_id=v_open) <> 2 THEN
   RAISE EXCEPTION 'visible joined roster unavailable';
 END IF;
 v_roster:=public.get_session_roster(v_open);
 IF (v_roster->>'waitlist_count')::int <> 1 THEN RAISE EXCEPTION 'waitlist count changed'; END IF;
 RESET role;
 INSERT INTO public.session_participants(session_id,user_id,role,status)
 VALUES(v_open,v_viewer,'player','waitlist'),(v_past,v_viewer,'player','joined');
 SET LOCAL role authenticated;
 IF (SELECT count(*) FROM public.session_participants WHERE user_id=v_viewer) <> 2 THEN
   RAISE EXCEPTION 'own membership lookup lost historical/waitlist rows';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.session_participants WHERE session_id=v_past AND user_id=v_joined) THEN
   RAISE EXCEPTION 'participant cannot read retained joined roster';
 END IF;
 v_roster:=public.get_session_roster(v_open);
 IF (v_roster->>'waitlist_count')::int <> 2 OR (v_roster->>'viewer_waitlist_position')::int <> 2 THEN
   RAISE EXCEPTION 'waitlist aggregates/position changed';
 END IF;
 RESET role;
 INSERT INTO public.user_blocks(blocker_id,blocked_id) VALUES(v_joined,v_viewer);
 SET LOCAL role authenticated;
 IF EXISTS(SELECT 1 FROM public.session_participants WHERE user_id=v_joined) THEN
   RAISE EXCEPTION 'reverse-blocked participant identity exposed';
 END IF;
 RESET role;
 INSERT INTO public.user_blocks(blocker_id,blocked_id) VALUES(v_viewer,v_host);
 SET LOCAL role authenticated;
 IF EXISTS(SELECT 1 FROM public.session_participants WHERE user_id<>v_viewer AND session_id=v_open) THEN
   RAISE EXCEPTION 'blocked host game exposes other participants';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM public.session_participants WHERE user_id=v_viewer AND session_id=v_open) THEN
   RAISE EXCEPTION 'blocked host removed own membership lookup';
 END IF;
 -- Host attendance uses joined rows from completed games.
 PERFORM set_config('request.jwt.claim.sub',v_host::text,true);
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',v_host,'email',v_host::text||'@ucf.edu')::text,true);
 IF NOT EXISTS(SELECT 1 FROM public.session_participants WHERE session_id=v_past AND user_id=v_joined AND status='joined') THEN
   RAISE EXCEPTION 'host attendance roster unavailable';
 END IF;
 RESET role;
 -- Stale school-email claims cannot authorize rows after authoritative email changes.
 UPDATE auth.users SET email=v_host::text||'@example.com' WHERE id=v_host;
 SET LOCAL role authenticated;
 IF EXISTS(SELECT 1 FROM public.session_participants WHERE session_id IN (v_open,v_past)) THEN
   RAISE EXCEPTION 'non-school account can read participant rows';
 END IF;
 RESET role;
 SET LOCAL role anon;
 BEGIN
   IF EXISTS(SELECT 1 FROM public.session_participants WHERE session_id IN (v_open,v_past)) THEN
     RAISE EXCEPTION 'anonymous caller can read participant rows';
   END IF;
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 RESET role;
 RAISE NOTICE 'phase_q_participant_reads: direct reads, membership, blocking, attendance and waitlist aggregates OK';
END; $$;
