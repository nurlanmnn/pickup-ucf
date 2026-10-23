-- BETA-13: enforce creation's numeric limits on direct authenticated host edits.
-- Check changed fields only so legacy games can still be cancelled or annotated.
CREATE OR REPLACE FUNCTION public.guard_client_session_status()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path=public AS $$
BEGIN
  -- Internal RPCs, cron and moderator actions run as their definer owner.
  IF current_user <> 'authenticated' THEN RETURN NEW; END IF;
  IF OLD.status NOT IN ('open','full') THEN
    IF (to_jsonb(NEW)-'updated_at') IS DISTINCT FROM (to_jsonb(OLD)-'updated_at') THEN
      RAISE EXCEPTION 'session_not_editable';
    END IF;
    RETURN NEW;
  END IF;
  IF NEW.status IS DISTINCT FROM OLD.status AND NEW.status <> 'cancelled' THEN
    RAISE EXCEPTION 'invalid_session_status_transition';
  END IF;

  IF NEW.capacity IS DISTINCT FROM OLD.capacity
     AND (NEW.capacity IS NULL OR NEW.capacity NOT BETWEEN 2 AND 50) THEN
    RAISE EXCEPTION USING ERRCODE='PT400', MESSAGE='invalid_session_input';
  END IF;
  IF NEW.starts_at IS DISTINCT FROM OLD.starts_at OR NEW.ends_at IS DISTINCT FROM OLD.ends_at THEN
    IF NEW.starts_at IS NULL OR NEW.ends_at IS NULL
       OR NOT isfinite(NEW.starts_at) OR NOT isfinite(NEW.ends_at) THEN
      RAISE EXCEPTION USING ERRCODE='PT400', MESSAGE='invalid_session_input';
    END IF;
    IF NEW.ends_at - NEW.starts_at NOT BETWEEN interval '15 minutes' AND interval '300 minutes' THEN
      RAISE EXCEPTION USING ERRCODE='PT400', MESSAGE='invalid_session_input';
    END IF;
    IF NEW.starts_at <= now() THEN RAISE EXCEPTION 'schedule_in_past'; END IF;
    IF NEW.starts_at > now()+interval '7 days' THEN RAISE EXCEPTION 'schedule_too_far_ahead'; END IF;
  END IF;
  IF NEW.venue_id IS DISTINCT FROM OLD.venue_id OR NEW.custom_location IS DISTINCT FROM OLD.custom_location
     OR NEW.custom_lat IS DISTINCT FROM OLD.custom_lat OR NEW.custom_lng IS DISTINCT FROM OLD.custom_lng THEN
    IF (NEW.custom_lat IS NOT NULL AND NEW.custom_lat NOT BETWEEN -90 AND 90)
       OR (NEW.custom_lng IS NOT NULL AND NEW.custom_lng NOT BETWEEN -180 AND 180)
       OR (NEW.venue_id IS NULL AND (NEW.custom_lat IS NULL OR NEW.custom_lng IS NULL)) THEN
      RAISE EXCEPTION 'custom_location_pin_required';
    END IF;
  END IF;

  IF NEW.status <> 'cancelled' THEN
    NEW.status := CASE WHEN NEW.player_count >= NEW.capacity THEN 'full'::public.session_status
                      ELSE 'open'::public.session_status END;
  END IF;
  RETURN NEW;
END; $$;
REVOKE ALL ON FUNCTION public.guard_client_session_status() FROM PUBLIC,anon,authenticated;
