-- Session reminder enqueue + pg_cron schedules

CREATE OR REPLACE FUNCTION public.enqueue_session_reminders(p_window text)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count int := 0;
  r record;
  v_type text;
  v_title text;
  v_body text;
  v_interval interval;
BEGIN
  IF p_window = '1h' THEN
    v_type := 'session_reminder_1h';
    v_title := 'Game in 1 hour';
    v_interval := interval '1 hour';
  ELSIF p_window = '15m' THEN
    v_type := 'session_reminder_15m';
    v_title := 'Game in 15 minutes';
    v_interval := interval '15 minutes';
  ELSE
    RAISE EXCEPTION 'invalid_window';
  END IF;

  FOR r IN
    SELECT s.id AS session_id, sp.user_id, s.sport::text AS sport,
           COALESCE(v.name, s.custom_location, 'campus') AS location
    FROM public.sessions s
    JOIN public.session_participants sp ON sp.session_id = s.id
    LEFT JOIN public.venues v ON v.id = s.venue_id
    WHERE s.status IN ('open', 'full')
      AND sp.status IN ('joined', 'waitlist')
      AND s.starts_at > now()
      AND s.starts_at <= now() + v_interval + interval '5 minutes'
      AND s.starts_at > now() + v_interval - interval '5 minutes'
  LOOP
    v_body := format('%s at %s starts soon.', r.sport, r.location);
    PERFORM public.enqueue_notification(
      r.user_id,
      r.session_id,
      v_type,
      v_title,
      v_body,
      format('%s:%s:%s', v_type, r.session_id, r.user_id)
    );
    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;

-- pg_cron jobs (requires extension enabled on hosted Supabase: Database → Extensions → pg_cron)
SELECT cron.schedule(
  'pickup-complete-expired-sessions',
  '*/15 * * * *',
  $$SELECT public.complete_expired_sessions();$$
);

SELECT cron.schedule(
  'pickup-reminder-1h',
  '*/5 * * * *',
  $$SELECT public.enqueue_session_reminders('1h');$$
);

SELECT cron.schedule(
  'pickup-reminder-15m',
  '*/5 * * * *',
  $$SELECT public.enqueue_session_reminders('15m');$$
);
