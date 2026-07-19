-- Tier 1 Task T1-3: host join and host session reminder notifications

CREATE OR REPLACE FUNCTION public.notify_host_player_joined()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_host_id uuid;
  v_joiner_name text;
  v_sport text;
BEGIN
  IF NEW.status <> 'joined' OR NEW.role = 'host' THEN
    RETURN NEW;
  END IF;

  SELECT s.host_id, s.sport::text INTO v_host_id, v_sport
  FROM public.sessions s WHERE s.id = NEW.session_id;

  IF v_host_id IS NULL OR v_host_id = NEW.user_id THEN
    RETURN NEW;
  END IF;

  SELECT display_name INTO v_joiner_name FROM public.profiles WHERE id = NEW.user_id;

  IF public.should_notify(v_host_id, 'host_player_joined') THEN
    PERFORM public.enqueue_notification(
      v_host_id,
      NEW.session_id,
      'host_player_joined',
      'Player joined',
      format('%s joined your %s game.', COALESCE(v_joiner_name, 'Someone'), v_sport),
      format('host_player_joined:%s:%s:%s', NEW.session_id, NEW.user_id, NEW.joined_at)
    );
  END IF;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_notify_host_player_joined
  AFTER INSERT OR UPDATE OF status ON public.session_participants
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_host_player_joined();

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
        AND s.starts_at <= now() + v_interval + interval '5 minutes'
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
