CREATE FUNCTION public.test_fail_account_delete() RETURNS trigger LANGUAGE plpgsql SET search_path=public AS $$
BEGIN
  IF current_setting('pickup.test_fail_delete',true)='on' THEN RAISE EXCEPTION 'synthetic_delete_failure'; END IF;
  RETURN OLD;
END; $$;
REVOKE ALL ON FUNCTION public.test_fail_account_delete() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER test_fail_account_delete BEFORE DELETE ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.test_fail_account_delete();
-- Synthetic deletion fixtures; suite rollback leaves no account/data changes.
DO $$
DECLARE
  v_deleted uuid := gen_random_uuid();
  v_other uuid := gen_random_uuid();
  v_waiter uuid := gen_random_uuid();
  v_hosted uuid := gen_random_uuid();
  v_other_game uuid := gen_random_uuid();
  v_completed uuid := gen_random_uuid();
  v_other_message uuid := gen_random_uuid();
BEGIN
  INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
  VALUES ('00000000-0000-0000-0000-000000000000',v_deleted,'authenticated','authenticated','delete-owner@ucf.edu','',now(),now(),now()),
    ('00000000-0000-0000-0000-000000000000',v_other,'authenticated','authenticated','delete-other@ucf.edu','',now(),now(),now()),
    ('00000000-0000-0000-0000-000000000000',v_waiter,'authenticated','authenticated','delete-waiter@ucf.edu','',now(),now(),now());
  INSERT INTO public.profiles(id,display_name) VALUES(v_deleted,'Delete Owner'),(v_other,'Delete Other'),(v_waiter,'Delete Waiter');
  INSERT INTO public.sessions(id,host_id,sport,starts_at,ends_at,capacity,player_count,skill_level,status)
  VALUES(v_hosted,v_deleted,'basketball',now()+interval '30 minutes',now()+interval '2 hours',3,2,'any','open'),
    (v_other_game,v_other,'tennis',now()+interval '30 minutes',now()+interval '2 hours',2,2,'any','full'),
    (v_completed,v_deleted,'tennis',now()-interval '2 hours',now()-interval '1 hour',2,1,'any','completed');
  INSERT INTO public.session_participants(session_id,user_id,role,status)
  VALUES(v_hosted,v_deleted,'host','joined'),(v_hosted,v_other,'player','joined'),
    (v_other_game,v_other,'host','joined'),(v_other_game,v_deleted,'player','joined'),
    (v_other_game,v_waiter,'player','waitlist'),(v_completed,v_deleted,'host','joined');
  INSERT INTO public.messages(session_id,user_id,body) VALUES(v_hosted,v_deleted,'Owner chat');
  INSERT INTO public.messages(id,session_id,user_id,body) VALUES(v_other_message,v_hosted,v_other,'Other chat retained');
  INSERT INTO public.device_tokens(user_id,apns_token) VALUES(v_deleted,repeat('ae',32));
  INSERT INTO public.live_activity_tokens(user_id,session_id,apns_token,starts_at,ends_at,needs_update)
  VALUES(v_deleted,v_hosted,repeat('af',32),now(),now()+interval '2 hours',false),
    (v_other,v_hosted,repeat('be',32),now(),now()+interval '2 hours',false);
  IF NOT EXISTS(SELECT 1 FROM public.notification_outbox WHERE user_id=v_other AND payload->>'actor_user_id'=v_deleted::text) THEN
    RAISE EXCEPTION 'missing authored-preview fixture';
  END IF;
  UPDATE public.sessions SET recurrence_rule='{"frequency":"weekly","count":4}' WHERE id=v_completed;
  SET LOCAL role authenticated;
  PERFORM set_config('request.jwt.claim.sub',v_deleted::text,true);
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',v_deleted,'email','delete-owner@ucf.edu')::text,true);
  PERFORM set_config('pickup.test_fail_delete','on',true);
  BEGIN
    PERFORM public.delete_own_account();
    RAISE EXCEPTION 'forced deletion failure did not fire';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'synthetic_delete_failure' THEN RAISE; END IF;
  END;
  PERFORM set_config('pickup.test_fail_delete','off',true);
  RESET role;
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE id=v_deleted)
     OR NOT EXISTS(SELECT 1 FROM public.sessions WHERE id=v_hosted AND host_id=v_deleted AND status='open' AND player_count=2)
     OR NOT EXISTS(SELECT 1 FROM public.session_participants WHERE session_id=v_other_game AND user_id=v_waiter AND status='waitlist')
     OR NOT EXISTS(SELECT 1 FROM public.notification_outbox WHERE user_id=v_other AND payload->>'actor_user_id'=v_deleted::text) THEN
    RAISE EXCEPTION 'partial deletion failure did not roll back';
  END IF;
  SET LOCAL role authenticated;
  PERFORM public.delete_own_account();
  PERFORM public.delete_own_account(); -- Safe retry even with an unexpired deleted-account JWT.
  IF public.is_ucf_email() THEN RAISE EXCEPTION 'deleted JWT still authorized'; END IF;
  RESET role;
  IF EXISTS(SELECT 1 FROM auth.users WHERE id=v_deleted)
     OR EXISTS(SELECT 1 FROM public.profiles WHERE id=v_deleted)
     OR EXISTS(SELECT 1 FROM public.messages WHERE user_id=v_deleted)
     OR EXISTS(SELECT 1 FROM public.session_participants WHERE user_id=v_deleted)
     OR EXISTS(SELECT 1 FROM public.device_tokens WHERE user_id=v_deleted)
     OR EXISTS(SELECT 1 FROM public.live_activity_tokens WHERE user_id=v_deleted)
     OR EXISTS(SELECT 1 FROM public.notification_outbox WHERE user_id=v_deleted OR payload->>'actor_user_id'=v_deleted::text) THEN
    RAISE EXCEPTION 'deleted account data survived';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM public.sessions WHERE id=v_hosted AND host_id IS NULL AND status='cancelled' AND player_count=1)
     OR NOT EXISTS(SELECT 1 FROM public.sessions WHERE id=v_completed AND host_id IS NULL AND status='completed' AND player_count=0)
     OR NOT EXISTS(SELECT 1 FROM public.messages WHERE id=v_other_message)
     OR NOT EXISTS(SELECT 1 FROM auth.users WHERE id=v_other) THEN
    RAISE EXCEPTION 'anonymized games/other-user content not preserved';
  END IF;
  IF (SELECT player_count FROM public.sessions WHERE id=v_other_game) <> 2
     OR NOT EXISTS(SELECT 1 FROM public.session_participants WHERE session_id=v_other_game AND user_id=v_waiter AND status='joined') THEN
    RAISE EXCEPTION 'participant deletion did not reconcile/promote';
  END IF;
  IF NOT EXISTS(SELECT 1 FROM public.notification_outbox WHERE user_id=v_other AND session_id=v_hosted AND type='session_cancelled')
     OR NOT EXISTS(SELECT 1 FROM public.live_activity_tokens WHERE user_id=v_other AND session_id=v_hosted AND needs_update AND ends_at<=now()) THEN
    RAISE EXCEPTION 'other-device cancellation cleanup missing';
  END IF;
  SET LOCAL role authenticated;
  PERFORM set_config('request.jwt.claim.sub',v_other::text,true);
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',v_other,'email','delete-other@ucf.edu')::text,true);
  BEGIN
    PERFORM public.submit_session_attendance(v_completed,ARRAY[v_other]);
    RAISE EXCEPTION 'other user controlled anonymized-host attendance';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'not_host' THEN RAISE; END IF;
  END;
  IF NOT EXISTS(SELECT 1 FROM public.sessions WHERE id=v_hosted AND host_id IS NULL) THEN
    RAISE EXCEPTION 'participant cannot read retained history';
  END IF;
  RESET role;
  IF public.spawn_next_recurring_session(v_completed) IS NOT NULL THEN
    RAISE EXCEPTION 'deleted host spawned another game';
  END IF;
  -- Scheduled cleanup must tolerate null-host games and still reach surviving players.
  PERFORM public.enqueue_finished_session_cleanup();
  PERFORM public.enqueue_finished_session_cleanup();
  IF NOT EXISTS(SELECT 1 FROM public.notification_outbox WHERE user_id=v_other
      AND session_id=v_hosted AND type='session_finished') THEN
    RAISE EXCEPTION 'anonymized-game cleanup missed surviving player';
  END IF;
  RAISE NOTICE 'phase_l_account_deletion: anonymized history, counts, tokens, previews and retry OK';
END; $$;

DROP TRIGGER test_fail_account_delete ON auth.users;
DROP FUNCTION public.test_fail_account_delete();
