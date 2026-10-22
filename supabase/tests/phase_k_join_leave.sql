DO $$
DECLARE
  v_host uuid := gen_random_uuid();
  v_player uuid := gen_random_uuid();
  v_session uuid;
BEGIN
  INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
  VALUES ('00000000-0000-0000-0000-000000000000',v_host,'authenticated','authenticated','leave-host@ucf.edu','',now(),now(),now()),
    ('00000000-0000-0000-0000-000000000000',v_player,'authenticated','authenticated','leave-player@ucf.edu','',now(),now(),now());
  INSERT INTO public.profiles(id,display_name) VALUES(v_host,'Leave Host'),(v_player,'Leave Player');
  SET LOCAL role authenticated;
  PERFORM set_config('request.jwt.claim.sub',v_host::text,true);
  v_session := public.create_session(gen_random_uuid(),jsonb_build_object('sport','basketball','skill_level','any',
    'starts_at',now()+interval '2 hours','ends_at',now()+interval '3 hours','capacity',2,
    'custom_location','Court','custom_lat',28.6,'custom_lng',-81.2));
  BEGIN
    PERFORM public.leave_session(v_session);
    RAISE EXCEPTION 'host was allowed to leave';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'host_cannot_leave' THEN RAISE; END IF;
  END;
  PERFORM set_config('request.jwt.claim.sub',v_player::text,true);
  PERFORM public.join_session(v_session);
  PERFORM public.leave_session(v_session);
  PERFORM public.leave_session(v_session);
  RESET role;
  IF (SELECT player_count FROM public.sessions WHERE id=v_session) <> 1
    OR (SELECT count(*) FROM public.session_participants WHERE session_id=v_session AND status='joined') <> 1 THEN
    RAISE EXCEPTION 'repeated leave count mismatch';
  END IF;
  RAISE NOTICE 'phase_k_join_leave: host and retry invariants OK';
END; $$;
