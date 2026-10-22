-- Run inside the suite's rollback transaction. Synthetic content only.
DO $$
DECLARE
  v_field text;
  v_max int;
  v_text text;
BEGIN
  FOREACH v_field IN ARRAY ARRAY['display_name','session_notes','custom_sport','custom_location','chat_message','report_context'] LOOP
    v_max := CASE v_field WHEN 'display_name' THEN 80 WHEN 'session_notes' THEN 1000
      WHEN 'custom_sport' THEN 40 WHEN 'custom_location' THEN 120 ELSE 500 END;
    IF public.assert_user_content(repeat(U&'e\0301',v_max),v_field) <> repeat('é',v_max) THEN
      RAISE EXCEPTION 'NFC exact boundary failed: %',v_field;
    END IF;
    IF public.assert_user_content('🏀',v_field) <> '🏀' THEN RAISE EXCEPTION 'minimum failed'; END IF;
    FOREACH v_text IN ARRAY ARRAY[repeat('🏀',v_max+1),repeat('👩‍👩‍👧‍👦',v_max/7+1)] LOOP
      BEGIN
        PERFORM public.assert_user_content(v_text,v_field);
        RAISE EXCEPTION 'over limit accepted: %',v_field;
      EXCEPTION WHEN SQLSTATE '22023' THEN
        IF SQLERRM <> 'user_content_too_long' THEN RAISE; END IF;
      END;
    END LOOP;
    FOREACH v_text IN ARRAY ARRAY[E'hello\vworld',chr(133),E'hello\f'] LOOP
      BEGIN
        PERFORM public.assert_user_content(v_text,v_field);
        RAISE EXCEPTION 'control accepted: %',v_field;
      EXCEPTION WHEN OTHERS THEN
        IF SQLERRM <> 'user_content_rejected' THEN RAISE; END IF;
      END;
    END LOOP;
  END LOOP;
  IF public.assert_user_content(U&'\00A0Cafe\0301\2007\000Ateam\3000','display_name') <> 'Café team'
     OR public.assert_user_content('👩‍👩‍👧‍👦','chat_message') <> '👩‍👩‍👧‍👦' THEN
    RAISE EXCEPTION 'Unicode normalization failed';
  END IF;
  FOREACH v_field IN ARRAY ARRAY['display_name','chat_message'] LOOP
    FOREACH v_text IN ARRAY ARRAY[NULL,E' \n\t',U&'\00A0\3000'] LOOP
      BEGIN
        PERFORM public.assert_user_content(v_text,v_field);
        RAISE EXCEPTION 'required blank accepted';
      EXCEPTION WHEN SQLSTATE '22023' THEN
        IF SQLERRM <> 'user_content_required' THEN RAISE; END IF;
      END;
    END LOOP;
  END LOOP;
  IF public.assert_user_content(E' \n\t','session_notes') IS NOT NULL THEN
    RAISE EXCEPTION 'optional blank not null';
  END IF;
END; $$;

DO $$
DECLARE
  v_user uuid := gen_random_uuid();
  v_session uuid;
  v_body text;
BEGIN
  INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
  VALUES ('00000000-0000-0000-0000-000000000000',v_user,'authenticated','authenticated','boundaries@ucf.edu','',now(),now(),now());
  INSERT INTO public.profiles(id,display_name) VALUES(v_user,'Boundaries Host');
  IF has_function_privilege('anon','public.assert_user_content(text,text)','EXECUTE') THEN
    RAISE EXCEPTION 'content helper exposed to anonymous clients';
  END IF;
  SET LOCAL role authenticated;
  PERFORM set_config('request.jwt.claim.sub',v_user::text,true);
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',v_user,'email','boundaries@ucf.edu')::text,true);
  v_session := public.create_session(gen_random_uuid(),jsonb_build_object('sport','basketball','skill_level','any',
    'starts_at',now()+interval '2 hours','ends_at',now()+interval '3 hours','capacity',10,
    'custom_location','Court','custom_lat',28.6,'custom_lng',-81.2,'notes',repeat('🏀',1000)));
  -- Crafted clients do not pass through iOS validators.
  FOREACH v_body IN ARRAY ARRAY[repeat('🏀',501),E' \n\t',E'hello\vworld'] LOOP
    BEGIN
      INSERT INTO public.messages(session_id,user_id,body) VALUES(v_session,v_user,v_body);
      RAISE EXCEPTION 'crafted chat accepted';
    EXCEPTION WHEN OTHERS THEN
      IF SQLERRM NOT IN ('user_content_too_long','user_content_required','user_content_rejected') THEN RAISE; END IF;
    END;
  END LOOP;
  INSERT INTO public.messages(session_id,user_id,body) VALUES(v_session,v_user,U&'Cafe\0301\000Ateam');
  IF NOT EXISTS(SELECT 1 FROM public.messages WHERE session_id=v_session AND body='Café team' AND char_length(body)=9) THEN
    RAISE EXCEPTION 'stored chat normalization failed';
  END IF;
  BEGIN
    UPDATE public.profiles SET display_name=U&'\00A0\3000' WHERE id=v_user;
    RAISE EXCEPTION 'crafted profile blank accepted';
  EXCEPTION WHEN SQLSTATE '22023' THEN
    IF SQLERRM <> 'user_content_required' THEN RAISE; END IF;
  END;
  BEGIN
    UPDATE public.sessions SET notes=repeat('🏀',1001) WHERE id=v_session;
    RAISE EXCEPTION 'crafted session notes accepted';
  EXCEPTION WHEN SQLSTATE '22023' THEN
    IF SQLERRM <> 'user_content_too_long' THEN RAISE; END IF;
  END;
  RESET role;
  RAISE NOTICE 'phase_i_input_boundaries: normalized limits and crafted writes OK';
END; $$;
