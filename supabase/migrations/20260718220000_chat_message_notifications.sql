-- Tier 2 Task T2-1: chat message push notifications

DROP FUNCTION IF EXISTS public.enqueue_notification(uuid, uuid, text, text, text, text);

CREATE OR REPLACE FUNCTION public.enqueue_notification(
  p_user_id uuid,
  p_session_id uuid,
  p_type text,
  p_title text,
  p_body text,
  p_dedupe_key text,
  p_payload_extras jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.notification_outbox (
    user_id, session_id, type, title, body, payload, dedupe_key
  )
  VALUES (
    p_user_id,
    p_session_id,
    p_type,
    p_title,
    p_body,
    jsonb_build_object('session_id', p_session_id) || p_payload_extras,
    p_dedupe_key
  )
  ON CONFLICT (dedupe_key) DO NOTHING;
END;
$$;

REVOKE ALL ON FUNCTION public.enqueue_notification(uuid, uuid, text, text, text, text, jsonb) FROM PUBLIC;

CREATE OR REPLACE FUNCTION public.notify_chat_message()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  r record;
  v_sender_name text;
  v_sport text;
BEGIN
  SELECT display_name INTO v_sender_name FROM public.profiles WHERE id = NEW.user_id;
  SELECT sport::text INTO v_sport FROM public.sessions WHERE id = NEW.session_id;

  FOR r IN
    SELECT sp.user_id
    FROM public.session_participants sp
    WHERE sp.session_id = NEW.session_id
      AND sp.status IN ('joined', 'waitlist')
      AND sp.user_id <> NEW.user_id
  LOOP
    IF public.should_notify(r.user_id, 'chat_message') THEN
      PERFORM public.enqueue_notification(
        r.user_id,
        NEW.session_id,
        'chat_message',
        format('New message · %s', COALESCE(v_sport, 'Session')),
        format('%s: %s', COALESCE(v_sender_name, 'Someone'), left(NEW.body, 80)),
        format('chat_message:%s:%s', NEW.session_id, NEW.id),
        jsonb_build_object('message_id', NEW.id, 'open_chat', true)
      );
    END IF;
  END LOOP;

  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_notify_chat_message
  AFTER INSERT ON public.messages
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_chat_message();
