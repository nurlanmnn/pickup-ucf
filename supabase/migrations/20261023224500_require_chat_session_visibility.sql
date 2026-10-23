-- BETA-13: a negative subquery cannot detect blocked games hidden by session RLS.
-- Require the positive shared gate so all chat respects authoritative school
-- identity and host blocking, while retaining member-only historical chat.
DROP POLICY messages_select ON public.messages;
CREATE POLICY messages_select ON public.messages FOR SELECT TO authenticated
USING (
  pickup_private.can_view_session(session_id)
  AND public.is_session_participant(session_id)
  AND NOT public.users_are_blocked(auth.uid(),user_id)
);
DROP POLICY messages_insert ON public.messages;
CREATE POLICY messages_insert ON public.messages FOR INSERT TO authenticated
WITH CHECK (
  user_id=auth.uid()
  AND pickup_private.can_view_session(session_id)
  AND public.is_session_participant(session_id)
  AND NOT public.is_user_suspended(auth.uid())
);
