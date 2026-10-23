-- BETA-13: raw attendance reads must not bypass blocked roster identities.
-- Profile history needs only the caller's own ledger rows; host attendance uses
-- the existing participant roster and definer RPC. Preserve data/service access.
REVOKE ALL ON public.attendance FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.attendance TO authenticated;
DROP POLICY attendance_select ON public.attendance;
CREATE POLICY attendance_select ON public.attendance FOR SELECT TO authenticated
USING (public.is_ucf_email() AND user_id=auth.uid());
