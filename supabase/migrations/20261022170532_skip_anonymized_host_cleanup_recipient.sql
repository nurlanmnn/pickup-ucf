-- Retained games have null hosts. Skip that recipient while notifying surviving players.
CREATE OR REPLACE FUNCTION public.enqueue_finished_session_cleanup()
RETURNS int LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_count int;
BEGIN
  INSERT INTO public.notification_outbox (user_id, session_id, type, title, body, payload, dedupe_key)
  SELECT recipients.user_id, s.id, 'session_finished', '', '',
    jsonb_build_object('session_id', s.id, 'session_ends_at', s.ends_at),
    format('session_finished:%s:%s', s.id, recipients.user_id)
  FROM public.sessions s
  CROSS JOIN LATERAL (
    SELECT s.host_id AS user_id
    UNION SELECT user_id FROM public.session_participants WHERE session_id = s.id
    UNION SELECT user_id FROM public.notification_outbox WHERE session_id = s.id AND type <> 'session_finished'
  ) recipients
  WHERE recipients.user_id IS NOT NULL
    AND (s.ends_at <= now() OR s.status IN ('completed', 'cancelled'))
    AND s.ends_at > now() - interval '1 day'
  ON CONFLICT (dedupe_key) DO NOTHING;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;
REVOKE ALL ON FUNCTION public.enqueue_finished_session_cleanup() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.enqueue_finished_session_cleanup() TO service_role;
