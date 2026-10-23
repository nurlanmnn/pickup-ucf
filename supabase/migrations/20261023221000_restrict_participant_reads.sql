-- BETA-13: direct reads must not bypass the roster RPC's privacy boundary.
-- Preserve self membership/status reads, including historical/blocked-host games.
-- Other identities require a joined row in a visible game and no mutual block.
DROP POLICY participants_select ON public.session_participants;
CREATE POLICY participants_select ON public.session_participants
FOR SELECT TO authenticated
USING (
  public.is_ucf_email()
  AND (
    user_id = auth.uid()
    OR (
      status = 'joined'
      AND NOT public.users_are_blocked(auth.uid(), user_id)
      AND pickup_private.can_view_session(session_id)
    )
  )
);
