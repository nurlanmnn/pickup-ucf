DO $$
DECLARE v_host uuid:=gen_random_uuid(); v_viewer uuid:=gen_random_uuid(); v_hidden uuid:=gen_random_uuid();
  v_session uuid:=gen_random_uuid(); v_private uuid:=gen_random_uuid(); v_roster jsonb;
BEGIN
 INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
 VALUES('00000000-0000-0000-0000-000000000000',v_host,'authenticated','authenticated','roster-host@ucf.edu','',now(),now(),now()),
 ('00000000-0000-0000-0000-000000000000',v_viewer,'authenticated','authenticated','roster-viewer@ucf.edu','',now(),now(),now()),
 ('00000000-0000-0000-0000-000000000000',v_hidden,'authenticated','authenticated','roster-hidden@ucf.edu','',now(),now(),now());
 INSERT INTO public.profiles(id,display_name) VALUES(v_host,'Roster Host'),(v_viewer,'Roster Viewer'),(v_hidden,'Roster Hidden');
 INSERT INTO public.sessions(id,host_id,sport,starts_at,ends_at,capacity,skill_level,status)
 VALUES(v_session,v_host,'basketball',now()+interval '1 hour',now()+interval '2 hours',4,'any','open'),
 (v_private,v_host,'basketball',now()-interval '2 days',now()-interval '1 day',4,'any','completed');
 INSERT INTO public.session_participants(session_id,user_id,role,status)
 VALUES(v_session,v_host,'host','joined'),(v_session,v_hidden,'player','joined'),(v_private,v_hidden,'player','joined');
 INSERT INTO public.user_blocks(blocker_id,blocked_id) VALUES(v_viewer,v_hidden);
 SET LOCAL role authenticated;
 PERFORM set_config('request.jwt.claim.sub',v_viewer::text,true);
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',v_viewer,'email','roster-viewer@ucf.edu')::text,true);
 v_roster := public.get_session_roster(v_session);
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(v_roster->'joined') row WHERE row->>'user_id'=v_hidden::text) THEN
   RAISE EXCEPTION 'roster exposes blocked identity';
 END IF;
 BEGIN
   PERFORM public.get_session_roster(v_private);
   RAISE EXCEPTION 'roster exposes inaccessible historical game';
 EXCEPTION WHEN OTHERS THEN
   IF SQLERRM <> 'session_not_found' THEN RAISE; END IF;
 END;
 RESET role;
 UPDATE public.session_participants SET status='waitlist',joined_at=now()-interval '1 hour'
   WHERE session_id=v_session AND user_id=v_hidden;
 INSERT INTO public.session_participants(session_id,user_id,role,status) VALUES(v_session,v_viewer,'player','waitlist');
 SET LOCAL role authenticated;
 v_roster := public.get_session_roster(v_session);
 IF (v_roster->>'waitlist_count')::int <> 2 OR (v_roster->>'viewer_waitlist_position')::int <> 2 THEN
   RAISE EXCEPTION 'blocked identity filtering changed true waitlist position';
 END IF;
 RESET role;
 RAISE NOTICE 'phase_m_roster_access: visibility and blocked identities OK';
END; $$;
