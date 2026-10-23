-- Crafted hosts must not bypass creation's numeric/schedule limits via UPDATE.
-- The caller wraps this file in a rollback transaction; all accounts are synthetic.
DO $$
DECLARE
  v_host uuid := gen_random_uuid();
  v_session uuid;
  v_venue uuid := gen_random_uuid();
  v_named_session uuid;
  v_case record;
BEGIN
  INSERT INTO auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
  VALUES('00000000-0000-0000-0000-000000000000',v_host,'authenticated','authenticated',
    v_host::text||'@ucf.edu','',now(),now(),now());
  INSERT INTO public.profiles(id,display_name) VALUES(v_host,'Edit Boundary Host');
  INSERT INTO public.venues(id,name,lat,lng) VALUES(v_venue,'Boundary Venue',28.6,-81.2);
  SET LOCAL role authenticated;
  PERFORM set_config('request.jwt.claim.sub',v_host::text,true);
  PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',v_host,'email',v_host::text||'@ucf.edu')::text,true);
  v_session := public.create_session(gen_random_uuid(),jsonb_build_object(
    'sport','basketball','skill_level','any','starts_at',now()+interval '2 hours',
    'ends_at',now()+interval '3 hours','capacity',2,
    'custom_location','Boundary Court','custom_lat',28.6,'custom_lng',-81.2));

  -- Assignments are fixed test SQL, never external input. Each rejected UPDATE
  -- rolls back inside its exception block before the next independent case.
  FOR v_case IN SELECT * FROM (VALUES
    ('capacity=1','invalid_session_input'),
    ('capacity=51','invalid_session_input'),
    ('capacity=2147483647','invalid_session_input'),
    ('ends_at=starts_at+interval ''14 minutes''','invalid_session_input'),
    ('ends_at=starts_at+interval ''301 minutes''','invalid_session_input'),
    ('starts_at=''infinity''::timestamptz,ends_at=''infinity''::timestamptz','invalid_session_input'),
    ('starts_at=''-infinity''::timestamptz','invalid_session_input'),
    ('starts_at=now()-interval ''2 hours'',ends_at=now()-interval ''1 hour''','schedule_in_past'),
    ('starts_at=now()+interval ''8 days'',ends_at=now()+interval ''8 days 1 hour''','schedule_too_far_ahead'),
    ('custom_lat=91','custom_location_pin_required'),
    ('custom_lat=-91','custom_location_pin_required'),
    ('custom_lng=181','custom_location_pin_required'),
    ('custom_lng=-181','custom_location_pin_required'),
    ('custom_lat=''NaN''::float8','custom_location_pin_required'),
    ('custom_lng=''Infinity''::float8','custom_location_pin_required'),
    ('custom_lat=NULL','custom_location_pin_required'),
    ('custom_lng=NULL','custom_location_pin_required')
  ) AS cases(assignment,expected_error)
  LOOP
    BEGIN
      EXECUTE format('UPDATE public.sessions SET %s WHERE id=$1',v_case.assignment) USING v_session;
      RAISE EXCEPTION 'host patch accepted: %',v_case.assignment;
    EXCEPTION WHEN OTHERS THEN
      IF SQLERRM <> v_case.expected_error THEN RAISE; END IF;
    END;
  END LOOP;

  -- Switching a named venue into custom-location mode also needs a complete pin,
  -- even when neither coordinate value changes (both were previously NULL).
  v_named_session := public.create_session(gen_random_uuid(),jsonb_build_object(
    'sport','basketball','skill_level','any','starts_at',now()+interval '2 hours',
    'ends_at',now()+interval '3 hours','capacity',2,'venue_id',v_venue));
  BEGIN
    UPDATE public.sessions SET venue_id=NULL,custom_location='Boundary Court' WHERE id=v_named_session;
    RAISE EXCEPTION 'host switched to custom location without a pin';
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM <> 'custom_location_pin_required' THEN RAISE; END IF;
  END;
  UPDATE public.sessions SET venue_id=NULL,custom_location='Boundary Court',
    custom_lat=28.6,custom_lng=-81.2 WHERE id=v_named_session;
  -- Build 5 omits optional nulls in patches: a named venue may retain a prior
  -- valid custom pin. Do not reject that existing client representation here.
  UPDATE public.sessions SET venue_id=v_venue WHERE id=v_named_session;

  -- Inclusive limits remain usable; capacity edits preserve the lifecycle guard.
  UPDATE public.sessions SET capacity=50,custom_lat=90,custom_lng=180,
    ends_at=starts_at+interval '15 minutes' WHERE id=v_session;
  UPDATE public.sessions SET capacity=2,custom_lat=-90,custom_lng=-180,
    starts_at=now()+interval '7 days',ends_at=now()+interval '7 days 300 minutes'
    WHERE id=v_session;
  IF NOT EXISTS(SELECT 1 FROM public.sessions WHERE id=v_session AND status='open') THEN
    RAISE EXCEPTION 'valid host edit lost open status';
  END IF;

  -- Do not strand older games: unchanged legacy fields must not prevent a notes
  -- edit or cancellation. Definer-owned maintenance remains outside client checks.
  RESET role;
  UPDATE public.sessions SET capacity=1,custom_lat=100,
    starts_at=now()-interval '2 hours',ends_at=now()-interval '110 minutes'
    WHERE id=v_session;
  SET LOCAL role authenticated;
  UPDATE public.sessions SET notes='Legacy game cancellation check' WHERE id=v_session;
  UPDATE public.sessions SET status='cancelled' WHERE id=v_session;
  RESET role;
  IF NOT EXISTS(SELECT 1 FROM public.sessions WHERE id=v_session AND status='cancelled') THEN
    RAISE EXCEPTION 'legacy cancellation blocked';
  END IF;
  RAISE NOTICE 'phase_o_host_edit_boundaries: crafted edits denied, inclusive limits and legacy cancellation OK';
END $$;
