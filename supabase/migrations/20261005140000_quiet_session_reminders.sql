-- One reminder in the final hour, only for confirmed players and hosts.
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
    -- Keep older callers safe while removing the second reminder.
    RETURN 0;
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
      AND sp.status = 'joined'
      AND sp.user_id <> s.host_id
      AND s.starts_at > now()
      AND s.starts_at <= now() + v_interval
      AND s.starts_at > now() + v_interval - interval '5 minutes'
  LOOP
    IF public.should_notify(r.user_id, v_type) THEN
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
    END IF;
  END LOOP;

  IF p_window = '1h' THEN
    FOR r IN
      SELECT s.id AS session_id, s.host_id AS user_id, s.sport::text AS sport,
             COALESCE(v.name, s.custom_location, 'campus') AS location
      FROM public.sessions s
      LEFT JOIN public.venues v ON v.id = s.venue_id
      WHERE s.status IN ('open', 'full')
        AND s.starts_at > now()
        AND s.starts_at <= now() + v_interval
        AND s.starts_at > now() + v_interval - interval '5 minutes'
    LOOP
      IF public.should_notify(r.user_id, 'host_session_reminder_1h') THEN
        v_body := format('Your %s game at %s starts in 1 hour.', r.sport, r.location);
        PERFORM public.enqueue_notification(
          r.user_id,
          r.session_id,
          'host_session_reminder_1h',
          'Your game in 1 hour',
          v_body,
          format('host_session_reminder_1h:%s', r.session_id)
        );
        v_count := v_count + 1;
      END IF;
    END LOOP;
  END IF;

  RETURN v_count;
END;
$$;

-- Disable the existing recurring 15-minute reminder job if installed.
DO $$
DECLARE
  v_job_id bigint;
BEGIN
  FOR v_job_id IN SELECT jobid FROM cron.job WHERE jobname = 'pickup-reminder-15m'
  LOOP
    PERFORM cron.unschedule(v_job_id);
  END LOOP;
END;
$$;

-- Queued reminders from the previous policy should not be dispatched later.
DELETE FROM public.notification_outbox
WHERE type = 'session_reminder_15m' AND sent_at IS NULL;
