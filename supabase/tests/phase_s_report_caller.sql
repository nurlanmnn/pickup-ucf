-- Retained moderation records must not let a deleted-account JWT create new UGC.
DO $$
DECLARE
 v_active uuid:=gen_random_uuid(); v_deleted uuid:=gen_random_uuid();
 v_unconfirmed uuid:=gen_random_uuid(); v_external uuid:=gen_random_uuid();
 v_target uuid:=gen_random_uuid(); v_actor uuid; v_report uuid;
BEGIN
 INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
 SELECT '00000000-0000-0000-0000-000000000000',u,'authenticated','authenticated',u::text||'@ucf.edu','',now(),now(),now()
 FROM unnest(ARRAY[v_active,v_deleted,v_unconfirmed,v_external,v_target]) u;
 INSERT INTO public.profiles(id,display_name)
 SELECT u,'Report Caller Test' FROM unnest(ARRAY[v_active,v_deleted,v_unconfirmed,v_external,v_target]) u;
 UPDATE auth.users SET email_confirmed_at=NULL WHERE id=v_unconfirmed;
 UPDATE auth.users SET email=v_external::text||'@example.com' WHERE id=v_external;
 DELETE FROM auth.users WHERE id=v_deleted;
 SET LOCAL role authenticated;
 FOREACH v_actor IN ARRAY ARRAY[v_deleted,v_unconfirmed,v_external] LOOP
   PERFORM set_config('request.jwt.claim.sub',v_actor::text,true);
   -- Claim still says confirmed school identity; authoritative account must win.
   PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',v_actor,'email',v_actor::text||'@ucf.edu','email_verified',true)::text,true);
   BEGIN
     PERFORM public.submit_moderation_report('user',v_target,'other','Synthetic report context');
     RAISE EXCEPTION 'invalid current account submitted moderation report';
   EXCEPTION WHEN OTHERS THEN
     IF SQLERRM <> 'not_authenticated' THEN RAISE; END IF;
   END;
 END LOOP;
 PERFORM set_config('request.jwt.claim.sub','',true);
 PERFORM set_config('request.jwt.claims','{}',true);
 BEGIN
   PERFORM public.submit_moderation_report('user',v_target,'other','Synthetic report context');
   RAISE EXCEPTION 'missing principal submitted moderation report';
 EXCEPTION WHEN OTHERS THEN
   IF SQLERRM <> 'not_authenticated' THEN RAISE; END IF;
 END;
 PERFORM set_config('request.jwt.claim.sub',v_active::text,true);
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',v_active,'email',v_active::text||'@ucf.edu')::text,true);
 v_report:=public.submit_moderation_report('user',v_target,'other','Synthetic report context');
 RESET role;
 IF NOT EXISTS(SELECT 1 FROM public.moderation_reports WHERE id=v_report AND reporter_id=v_active)
 OR EXISTS(SELECT 1 FROM public.moderation_reports WHERE reporter_id IN (v_deleted,v_unconfirmed,v_external)) THEN
   RAISE EXCEPTION 'report authorization changed valid caller or persisted denied content';
 END IF;
 RAISE NOTICE 'phase_s_report_caller: deleted JWT, school confirmation and valid report authorization OK';
END; $$;
