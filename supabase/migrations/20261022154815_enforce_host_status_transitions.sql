-- BETA-13: direct host edits cannot reopen moderation removals or forge lifecycle state.
CREATE FUNCTION public.guard_client_session_status()
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
  IF NEW.status <> 'cancelled' THEN
    NEW.status := CASE WHEN NEW.player_count >= NEW.capacity THEN 'full'::public.session_status
                      ELSE 'open'::public.session_status END;
  END IF;
  RETURN NEW;
END; $$;
REVOKE ALL ON FUNCTION public.guard_client_session_status() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER sessions_guard_client_status BEFORE UPDATE ON public.sessions
  FOR EACH ROW EXECUTE FUNCTION public.guard_client_session_status();
