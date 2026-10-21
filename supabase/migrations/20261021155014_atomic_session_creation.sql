-- BETA-02: session, joined host, and retry receipt commit or roll back together.
CREATE SCHEMA IF NOT EXISTS pickup_private;
REVOKE ALL ON SCHEMA pickup_private FROM PUBLIC, anon;
GRANT USAGE ON SCHEMA pickup_private TO authenticated;

CREATE TABLE pickup_private.session_creation_requests (
  host_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  request_id uuid NOT NULL,
  session_id uuid REFERENCES public.sessions(id) ON DELETE SET NULL,
  payload_hash bytea NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (host_id, request_id)
);
ALTER TABLE pickup_private.session_creation_requests ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON pickup_private.session_creation_requests FROM PUBLIC, anon, authenticated;

CREATE FUNCTION pickup_private.create_session(p_request_id uuid, p_input jsonb)
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

CREATE FUNCTION public.create_session(p_request_id uuid, p_input jsonb)
RETURNS uuid
LANGUAGE sql
SECURITY INVOKER
SET search_path = ''
AS $$ SELECT pickup_private.create_session(p_request_id, p_input); $$;
REVOKE ALL ON FUNCTION public.create_session(uuid, jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.create_session(uuid, jsonb) TO authenticated;
COMMENT ON FUNCTION public.create_session(uuid, jsonb) IS
  'Creates a session and its joined host atomically. Reuse a request UUID only for retries of the same form.';
