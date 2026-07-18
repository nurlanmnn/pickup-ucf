-- Phase C Task C4: weather snapshot refresh via pg_net + pg_cron
--
-- Requires pg_net (Database → Extensions). If pg_net is unavailable, weather is
-- still fetched on session create from iOS. Configure before cron refresh works:
--   ALTER DATABASE postgres SET app.settings.supabase_url = 'https://<project>.supabase.co';
--   ALTER DATABASE postgres SET app.settings.service_role_key = '<service_role_key>';

CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

CREATE OR REPLACE FUNCTION public.session_is_outdoor_for_weather(
  p_venue_id uuid,
  p_custom_lat double precision,
  p_custom_lng double precision
)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT
    (p_custom_lat IS NOT NULL AND p_custom_lng IS NOT NULL)
    OR EXISTS (
      SELECT 1
      FROM public.venues v
      WHERE v.id = p_venue_id
        AND v.is_official
        AND v.name NOT ILIKE '%RWC%'
    );
$$;

CREATE OR REPLACE FUNCTION public.refresh_session_weather(p_session_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  v_lat double precision;
  v_lng double precision;
  v_starts_at timestamptz;
  v_outdoor boolean;
  v_url text;
  v_key text;
  v_request_id bigint;
  v_response record;
  v_body jsonb;
  v_snapshot jsonb;
  v_wait int := 0;
BEGIN
  SELECT
    COALESCE(v.lat, s.custom_lat),
    COALESCE(v.lng, s.custom_lng),
    s.starts_at,
    public.session_is_outdoor_for_weather(s.venue_id, s.custom_lat, s.custom_lng)
  INTO v_lat, v_lng, v_starts_at, v_outdoor
  FROM public.sessions s
  LEFT JOIN public.venues v ON v.id = s.venue_id
  WHERE s.id = p_session_id;

  IF NOT FOUND OR NOT v_outdoor OR v_lat IS NULL OR v_lng IS NULL THEN
    RETURN false;
  END IF;

  BEGIN
    v_url := current_setting('app.settings.supabase_url', true);
    v_key := current_setting('app.settings.service_role_key', true);
  EXCEPTION
    WHEN OTHERS THEN
      v_url := NULL;
      v_key := NULL;
  END;

  IF v_url IS NULL OR v_key IS NULL OR v_url = '' OR v_key = '' THEN
    RAISE NOTICE 'refresh_session_weather: set app.settings.supabase_url and service_role_key for pg_net';
    RETURN false;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') THEN
    RAISE NOTICE 'refresh_session_weather: pg_net extension not enabled';
    RETURN false;
  END IF;

  v_body := jsonb_build_object(
    'lat', v_lat,
    'lng', v_lng,
    'starts_at', to_char(v_starts_at AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
  );

  SELECT net.http_post(
    url := rtrim(v_url, '/') || '/functions/v1/fetch-weather',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_key
    ),
    body := v_body
  ) INTO v_request_id;

  LOOP
    SELECT status_code, content::text AS content
    INTO v_response
    FROM net._http_response
    WHERE id = v_request_id;

    EXIT WHEN FOUND;
    v_wait := v_wait + 1;
    IF v_wait > 50 THEN
      RETURN false;
    END IF;
    PERFORM pg_sleep(0.1);
  END LOOP;

  IF v_response.status_code <> 200 THEN
    RETURN false;
  END IF;

  v_snapshot := v_response.content::jsonb;

  UPDATE public.sessions
  SET weather_snapshot = v_snapshot
  WHERE id = p_session_id;

  RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION public.refresh_upcoming_outdoor_weather()
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count int := 0;
  r record;
BEGIN
  FOR r IN
    SELECT s.id
    FROM public.sessions s
    LEFT JOIN public.venues v ON v.id = s.venue_id
    WHERE s.status IN ('open', 'full')
      AND s.starts_at > now()
      AND s.starts_at <= now() + interval '3 hours'
      AND public.session_is_outdoor_for_weather(s.venue_id, s.custom_lat, s.custom_lng)
      AND (
        s.weather_snapshot IS NULL
        OR COALESCE((s.weather_snapshot->>'fetched_at')::timestamptz, '-infinity'::timestamptz)
          < now() - interval '6 hours'
      )
  LOOP
    IF public.refresh_session_weather(r.id) THEN
      v_count := v_count + 1;
    END IF;
  END LOOP;

  RETURN v_count;
END;
$$;

SELECT cron.schedule(
  'pickup-refresh-outdoor-weather',
  '*/15 * * * *',
  $$SELECT public.refresh_upcoming_outdoor_weather();$$
);
