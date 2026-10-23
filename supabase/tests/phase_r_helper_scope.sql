-- Public RLS helpers must not become unrelated-user privacy oracles.
DO $$
DECLARE
 v_viewer uuid:=gen_random_uuid(); v_first uuid:=gen_random_uuid(); v_second uuid:=gen_random_uuid();
BEGIN
 INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
 SELECT '00000000-0000-0000-0000-000000000000',u,'authenticated','authenticated',u::text||'@ucf.edu','',now(),now(),now()
 FROM unnest(ARRAY[v_viewer,v_first,v_second]) u;
 INSERT INTO public.profiles(id,display_name)
 SELECT u,'Helper Scope Test' FROM unnest(ARRAY[v_viewer,v_first,v_second]) u;
 INSERT INTO public.user_blocks(blocker_id,blocked_id) VALUES(v_first,v_second),(v_viewer,v_first);
 INSERT INTO public.user_moderation_state(user_id,suspended_until,reason)
 VALUES(v_first,now()+interval '1 day','Synthetic suspension reason');
 SET LOCAL role authenticated;
 PERFORM set_config('request.jwt.claim.sub',v_viewer::text,true);
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',v_viewer,'email',v_viewer::text||'@ucf.edu')::text,true);
 BEGIN
   PERFORM public.users_are_blocked(v_first,v_second);
   RAISE EXCEPTION 'public helper reveals unrelated block relationship';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 BEGIN
   PERFORM public.is_user_suspended(v_first);
   RAISE EXCEPTION 'public helper reveals another users suspension';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 -- Negative and NULL guesses must fail identically, not reveal existence.
 BEGIN
   PERFORM public.users_are_blocked(v_first,gen_random_uuid());
   RAISE EXCEPTION 'public helper allows unrelated negative block guess';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 BEGIN
   PERFORM public.is_user_suspended(NULL);
   RAISE EXCEPTION 'public helper allows unrelated null suspension guess';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;
 IF NOT public.users_are_blocked(v_viewer,v_first) OR NOT public.users_are_blocked(v_first,v_viewer) THEN
   RAISE EXCEPTION 'caller block checks changed';
 END IF;
 IF public.is_user_suspended(v_viewer) THEN RAISE EXCEPTION 'caller suspension changed'; END IF;
 -- Standard profile RLS still hides the callers blocked target.
 IF EXISTS(SELECT 1 FROM public.profiles WHERE id=v_first) THEN RAISE EXCEPTION 'profile block policy changed'; END IF;
 RESET role;
 -- Privileged internal operations must retain arbitrary actor checks.
 IF NOT public.users_are_blocked(v_first,v_second) OR NOT public.is_user_suspended(v_first) THEN
   RAISE EXCEPTION 'trusted helper checks lost arbitrary actors';
 END IF;
 -- A SECURITY DEFINER caller must keep trusted scope even under an authenticated request.
 CREATE FUNCTION pickup_private.test_trusted_scope(p_first uuid,p_second uuid) RETURNS boolean
 LANGUAGE sql SECURITY DEFINER SET search_path='' AS $body$
   SELECT public.users_are_blocked(p_first,p_second) AND public.is_user_suspended(p_first);
 $body$;
 REVOKE ALL ON FUNCTION pickup_private.test_trusted_scope(uuid,uuid) FROM PUBLIC,anon;
 GRANT EXECUTE ON FUNCTION pickup_private.test_trusted_scope(uuid,uuid) TO authenticated;
 SET LOCAL role authenticated;
 IF NOT pickup_private.test_trusted_scope(v_first,v_second) THEN RAISE EXCEPTION 'nested definer helper scope changed'; END IF;
 RESET role;
 DROP FUNCTION pickup_private.test_trusted_scope(uuid,uuid);
 RAISE NOTICE 'phase_r_helper_scope: unrelated RPC denial, own RLS and trusted definer checks OK';
END; $$;
