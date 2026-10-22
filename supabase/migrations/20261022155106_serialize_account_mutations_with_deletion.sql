-- BETA-09/14: keep new memberships and hosted games outside deletion cleanup.
CREATE OR REPLACE FUNCTION public.join_session(p_session_id uuid)
RETURNS participant_status
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_capacity int;
  v_count int;
  v_host_id uuid;
  v_session_status session_status;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  -- Deletion takes this row FOR UPDATE before enumerating any session rows.
  PERFORM 1 FROM auth.users WHERE id=auth.uid() FOR KEY SHARE;
  IF NOT FOUND OR NOT public.is_ucf_email() THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  IF public.is_user_suspended(auth.uid()) THEN RAISE EXCEPTION 'account_suspended'; END IF;

  SELECT capacity, player_count, status, host_id
  INTO v_capacity, v_count, v_session_status, v_host_id
  FROM public.sessions WHERE id = p_session_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'session_not_found'; END IF;
  IF v_session_status NOT IN ('open', 'full') THEN RAISE EXCEPTION 'session_not_joinable'; END IF;
  IF public.users_are_blocked(v_host_id, auth.uid()) THEN RAISE EXCEPTION 'user_blocked'; END IF;

  IF EXISTS (
    SELECT 1 FROM public.session_participants
    WHERE session_id = p_session_id AND user_id = auth.uid() AND status = 'joined'
  ) THEN RETURN 'joined'::public.participant_status; END IF;

  IF v_count < v_capacity THEN
    INSERT INTO public.session_participants (session_id, user_id, role, status)
    VALUES (p_session_id, auth.uid(), 'player', 'joined')
    ON CONFLICT (session_id, user_id) DO UPDATE SET status = 'joined', joined_at = now();
    UPDATE public.sessions
    SET player_count = player_count + 1,
        status = CASE WHEN player_count + 1 >= capacity THEN 'full'::session_status ELSE status END
    WHERE id = p_session_id;
    RETURN 'joined'::public.participant_status;
  END IF;

  INSERT INTO public.session_participants (session_id, user_id, role, status)
  VALUES (p_session_id, auth.uid(), 'player', 'waitlist')
  ON CONFLICT (session_id, user_id) DO UPDATE SET status = 'waitlist', joined_at = now();
  RETURN 'waitlist'::public.participant_status;
END;
$$;


-- Atomic creation shares the same account-before-session lock order.
CREATE OR REPLACE FUNCTION pickup_private.create_session(p_request_id uuid, p_input jsonb)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_host uuid := auth.uid();
  v_receipt pickup_private.session_creation_requests%ROWTYPE;
  v_id uuid;
  v_sport public.sport_type;
  v_skill public.skill_level;
  v_venue uuid;
  v_location text;
  v_lat double precision;
  v_lng double precision;
  v_start timestamptz;
  v_end timestamptz;
  v_capacity integer;
  v_notes text;
  v_custom_sport text;
  v_recurrence text;
  v_rule jsonb;
BEGIN
  PERFORM 1 FROM auth.users WHERE id=v_host FOR KEY SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='creation_forbidden'; END IF;
  -- Authoritative account data, never editable user metadata or caller-supplied host IDs.
  IF v_host IS NULL OR NOT EXISTS (
    SELECT 1 FROM auth.users u JOIN public.profiles p ON p.id = u.id
    WHERE u.id = v_host AND u.email_confirmed_at IS NOT NULL
      AND lower(u.email) ~ '@(knights\.)?ucf\.edu$'
  ) THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'creation_forbidden';
  END IF;
  IF public.is_user_suspended(v_host) THEN RAISE EXCEPTION 'account_suspended'; END IF;
  IF p_request_id IS NULL OR p_input IS NULL OR jsonb_typeof(p_input) <> 'object' THEN
    RAISE EXCEPTION USING ERRCODE = 'PT400', MESSAGE = 'invalid_session_input';
  END IF;
  IF octet_length(p_input::text) > 8192
     OR p_input - ARRAY['sport','custom_sport_name','venue_id','custom_location','custom_lat','custom_lng',
                       'starts_at','ends_at','capacity','skill_level','notes','recurrence_rule'] <> '{}'::jsonb
     OR EXISTS (
       SELECT 1 FROM jsonb_each(p_input) e
       WHERE e.key IN ('sport','custom_sport_name','venue_id','custom_location','starts_at','ends_at','skill_level','notes','recurrence_rule')
         AND jsonb_typeof(e.value) NOT IN ('string','null')
     ) THEN
    RAISE EXCEPTION USING ERRCODE = 'PT400', MESSAGE = 'invalid_session_input';
  END IF;

  -- Serialize identical requests, including two requests racing before either commits.
  PERFORM pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(v_host::text || p_request_id::text, 0));
  SELECT * INTO v_receipt FROM pickup_private.session_creation_requests
    WHERE host_id = v_host AND request_id = p_request_id;
  IF FOUND THEN
    IF v_receipt.payload_hash IS DISTINCT FROM pg_catalog.sha256(pg_catalog.convert_to(p_input::text, 'UTF8')) THEN
      RAISE EXCEPTION USING ERRCODE = 'PT409', MESSAGE = 'creation_request_conflict';
    END IF;
    IF v_receipt.session_id IS NULL THEN
      RAISE EXCEPTION USING ERRCODE = 'PT410', MESSAGE = 'creation_no_longer_available';
    END IF;
    RETURN v_receipt.session_id;
  END IF;

  BEGIN
    v_sport := (p_input->>'sport')::public.sport_type;
    v_skill := (p_input->>'skill_level')::public.skill_level;
    v_venue := (p_input->>'venue_id')::uuid;
    v_start := (p_input->>'starts_at')::timestamptz;
    v_end := (p_input->>'ends_at')::timestamptz;
    v_capacity := (p_input->>'capacity')::integer;
    v_lat := (p_input->>'custom_lat')::double precision;
    v_lng := (p_input->>'custom_lng')::double precision;
    v_recurrence := p_input->>'recurrence_rule';
    IF v_recurrence IS NOT NULL THEN v_rule := v_recurrence::jsonb; END IF;
  EXCEPTION WHEN invalid_text_representation OR invalid_datetime_format OR datetime_field_overflow OR numeric_value_out_of_range THEN
    RAISE EXCEPTION USING ERRCODE = 'PT400', MESSAGE = 'invalid_session_input';
  END;

  IF v_sport IS NULL OR v_skill IS NULL OR v_start IS NULL OR v_end IS NULL OR v_capacity IS NULL
     OR NOT isfinite(v_start) OR NOT isfinite(v_end)
     OR v_capacity NOT BETWEEN 2 AND 50 OR jsonb_typeof(p_input->'capacity') <> 'number'
     OR v_end - v_start NOT BETWEEN interval '15 minutes' AND interval '300 minutes' THEN
    RAISE EXCEPTION USING ERRCODE = 'PT400', MESSAGE = 'invalid_session_input';
  END IF;
  IF v_start <= now() THEN RAISE EXCEPTION 'schedule_in_past'; END IF;
  IF v_start > now() + interval '7 days' THEN RAISE EXCEPTION 'schedule_too_far_ahead'; END IF;

  v_notes := nullif(public.assert_user_content(p_input->>'notes', 'session_notes'), '');
  v_location := nullif(public.assert_user_content(p_input->>'custom_location', 'custom_location'), '');
  v_custom_sport := nullif(public.assert_user_content(p_input->>'custom_sport_name', 'custom_sport'), '');
  IF v_sport = 'other' AND v_custom_sport IS NULL THEN RAISE EXCEPTION 'custom_sport_required'; END IF;
  IF v_sport <> 'other' AND v_custom_sport IS NOT NULL THEN
    RAISE EXCEPTION USING ERRCODE = 'PT400', MESSAGE = 'invalid_session_input';
  END IF;
  IF (v_venue IS NULL) = (v_location IS NULL) THEN RAISE EXCEPTION 'location_required'; END IF;
  IF v_venue IS NOT NULL THEN
    IF v_lat IS NOT NULL OR v_lng IS NOT NULL OR NOT EXISTS (SELECT 1 FROM public.venues WHERE id = v_venue) THEN
      RAISE EXCEPTION 'invalid_session_location';
    END IF;
  ELSIF v_lat IS NULL OR v_lng IS NULL OR v_lat NOT BETWEEN -90 AND 90 OR v_lng NOT BETWEEN -180 AND 180
        OR jsonb_typeof(p_input->'custom_lat') <> 'number' OR jsonb_typeof(p_input->'custom_lng') <> 'number' THEN
    RAISE EXCEPTION 'custom_location_pin_required';
  END IF;
  IF v_recurrence IS NOT NULL AND (
    jsonb_typeof(v_rule) <> 'object' OR v_rule->>'frequency' IS DISTINCT FROM 'weekly'
    OR v_rule->>'count' NOT IN ('2','3','4') OR NOT (v_rule ? 'count')
    OR jsonb_typeof(v_rule->'count') <> 'number'
    OR v_rule - ARRAY['frequency','count'] <> '{}'::jsonb
  ) THEN
    RAISE EXCEPTION USING ERRCODE = 'PT400', MESSAGE = 'invalid_session_input';
  END IF;

  INSERT INTO public.sessions(host_id, sport, custom_sport_name, venue_id, custom_location,
    custom_lat, custom_lng, starts_at, ends_at, capacity, player_count, skill_level, notes, recurrence_rule, status)
  VALUES (v_host, v_sport, v_custom_sport, v_venue, v_location, v_lat, v_lng,
    v_start, v_end, v_capacity, 1, v_skill, v_notes, v_recurrence, 'open')
  RETURNING id INTO v_id;
  INSERT INTO public.session_participants(session_id, user_id, role, status)
    VALUES (v_id, v_host, 'host', 'joined');
  INSERT INTO pickup_private.session_creation_requests(host_id, request_id, session_id, payload_hash)
    VALUES (v_host, p_request_id, v_id, pg_catalog.sha256(pg_catalog.convert_to(p_input::text, 'UTF8')));
  RETURN v_id;
END;
$$;
REVOKE ALL ON FUNCTION pickup_private.create_session(uuid, jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION pickup_private.create_session(uuid, jsonb) TO authenticated;
