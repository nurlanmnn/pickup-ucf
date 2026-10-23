-- A retry while the game is still full must preserve the waiter's queue time.
DO $$
DECLARE
  v_host uuid := gen_random_uuid();
  v_waiter uuid := gen_random_uuid();
  v_player uuid := gen_random_uuid();
  v_session uuid := gen_random_uuid();
  v_first_attempt timestamptz := now()-interval '2 minutes';
BEGIN
  INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
  VALUES('00000000-0000-0000-0000-000000000000',v_host,'authenticated','authenticated',v_host::text||'@ucf.edu','',now(),now(),now()),
    ('00000000-0000-0000-0000-000000000000',v_waiter,'authenticated','authenticated',v_waiter::text||'@ucf.edu','',now(),now(),now()),
    ('00000000-0000-0000-0000-000000000000',v_player,'authenticated','authenticated',v_player::text||'@ucf.edu','',now(),now(),now());
  INSERT INTO public.profiles(id,display_name)
    VALUES(v_host,'Waitlist Host'),(v_waiter,'Waitlist Retry'),(v_player,'Waitlist Player');
  INSERT INTO public.sessions(id,host_id,sport,starts_at,ends_at,capacity,player_count,skill_level,status)
  VALUES(v_session,v_host,'basketball',now()+interval '2 hours',now()+interval '3 hours',2,2,'any','full');
  INSERT INTO public.session_participants(session_id,user_id,role,status)
  VALUES(v_session,v_host,'host','joined'),(v_session,v_player,'player','joined');
  SET LOCAL role authenticated;
  PERFORM set_config('request.jwt.claim.sub',v_waiter::text,true);
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',v_waiter,'email',v_waiter::text||'@ucf.edu')::text,true);
  IF public.join_session(v_session)<>'waitlist' THEN RAISE EXCEPTION 'waitlist setup failed'; END IF;
  RESET role;
  UPDATE public.session_participants SET joined_at=v_first_attempt WHERE session_id=v_session AND user_id=v_waiter;
  SET LOCAL role authenticated;
  PERFORM public.join_session(v_session);
  PERFORM public.join_session(v_session);
  RESET role;
  IF (SELECT joined_at FROM public.session_participants WHERE session_id=v_session AND user_id=v_waiter) IS DISTINCT FROM v_first_attempt THEN
    RAISE EXCEPTION 'join retry changed waitlist priority';
  END IF;
  IF (SELECT count(*) FROM public.session_participants WHERE session_id=v_session AND user_id=v_waiter AND status='waitlist')<>1 THEN
    RAISE EXCEPTION 'join retry duplicated waitlist membership';
  END IF;
  -- Explicit leave followed by a fresh join is a new queue entry.
  SET LOCAL role authenticated;
  PERFORM public.leave_session(v_session);
  PERFORM public.join_session(v_session);
  RESET role;
  IF (SELECT joined_at FROM public.session_participants WHERE session_id=v_session AND user_id=v_waiter)<>now() THEN
    RAISE EXCEPTION 'fresh join did not reset queue time';
  END IF;
  RAISE NOTICE 'phase_p_waitlist_retry: retries retain priority; leave/rejoin creates a new queue entry OK';
END $$;
