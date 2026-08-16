-- Phase C Task C7: session reports table and RLS

CREATE TABLE public.session_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reporter_id uuid NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  session_id uuid NOT NULL REFERENCES public.sessions (id) ON DELETE CASCADE,
  reason text NOT NULL CHECK (length(trim(reason)) BETWEEN 10 AND 500),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (reporter_id, session_id)
);

ALTER TABLE public.session_reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY session_reports_insert ON public.session_reports
  FOR INSERT TO authenticated
  WITH CHECK (reporter_id = auth.uid());

CREATE POLICY session_reports_select ON public.session_reports
  FOR SELECT TO authenticated
  USING (reporter_id = auth.uid());
