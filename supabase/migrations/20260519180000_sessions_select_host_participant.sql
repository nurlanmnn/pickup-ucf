-- Allow hosts and participants to read their sessions after start time;
-- keep public Discover to upcoming open/full games only (starts_at > now()).

DROP POLICY IF EXISTS sessions_select ON public.sessions;

CREATE POLICY sessions_select ON public.sessions
  FOR SELECT TO authenticated
  USING (
    public.is_ucf_email()
    AND (
      (status IN ('open', 'full') AND starts_at > now())
      OR host_id = auth.uid()
      OR public.is_session_participant(id)
    )
  );
