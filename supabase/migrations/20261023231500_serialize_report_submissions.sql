-- BETA-13: serialize count-and-insert per reporter, including the first report.
-- Lock the existing account, never retained audit rows or the target account.
CREATE OR REPLACE FUNCTION public.submit_moderation_report(
  p_target_type public.report_target_type,
  p_target_id uuid,
  p_category public.report_category,
  p_context text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_report_id uuid;
  v_context text;
  v_subject_user_id uuid;
  v_snapshot jsonb;
  v_hour_count int;
  v_day_count int;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  -- Same account-before-session order as deletion; KEY SHARE joins remain compatible.
  PERFORM 1 FROM auth.users WHERE id = auth.uid() FOR NO KEY UPDATE;
  IF NOT FOUND OR NOT public.is_ucf_email() THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;
  IF public.is_user_suspended(auth.uid()) THEN RAISE EXCEPTION 'account_suspended'; END IF;
  IF p_target_id IS NULL THEN RAISE EXCEPTION 'invalid_report_target'; END IF;

  v_context := public.assert_user_content(p_context, 'report_context');
  IF v_context IS NOT NULL AND length(v_context) < 10 THEN RAISE EXCEPTION 'report_context_too_short'; END IF;

  -- Each count must see commits made while waiting for the account lock.
  -- PostgREST defaults to READ COMMITTED. Transaction-wide snapshots cannot
  -- safely use this protocol; fail closed if a SQL caller changes isolation.
  IF current_setting('transaction_isolation') NOT IN ('read committed', 'read uncommitted') THEN
    RAISE EXCEPTION USING ERRCODE = '40001',
      MESSAGE = 'report_requires_read_committed';
  END IF;

  SELECT count(*) FILTER (WHERE created_at > now() - interval '1 hour'),
         count(*) FILTER (WHERE created_at > now() - interval '1 day')
  INTO v_hour_count, v_day_count
  FROM public.moderation_reports WHERE reporter_id = auth.uid();
  IF v_hour_count >= 5 OR v_day_count >= 20 THEN RAISE EXCEPTION 'report_rate_limited'; END IF;

  IF p_target_type = 'session' THEN
    SELECT host_id,
           jsonb_build_object('sport', sport::text, 'notes', left(COALESCE(notes, ''), 500), 'status', status::text)
    INTO v_subject_user_id, v_snapshot FROM public.sessions WHERE id = p_target_id;
  ELSIF p_target_type = 'message' THEN
    SELECT user_id,
           jsonb_build_object('session_id', session_id, 'body', left(body, 500), 'created_at', created_at)
    INTO v_subject_user_id, v_snapshot FROM public.messages WHERE id = p_target_id;
  ELSE
    SELECT id, jsonb_build_object('display_name', display_name, 'username', username)
    INTO v_subject_user_id, v_snapshot FROM public.profiles WHERE id = p_target_id;
  END IF;

  IF v_subject_user_id IS NULL THEN RAISE EXCEPTION 'report_target_not_found'; END IF;
  IF v_subject_user_id = auth.uid() THEN RAISE EXCEPTION 'invalid_report_target'; END IF;

  INSERT INTO public.moderation_reports (
    reporter_id, target_type, target_session_id, target_message_id, target_user_id,
    subject_user_id, category, context, target_snapshot
  ) VALUES (
    auth.uid(), p_target_type,
    CASE WHEN p_target_type = 'session' THEN p_target_id END,
    CASE WHEN p_target_type = 'message' THEN p_target_id END,
    CASE WHEN p_target_type = 'user' THEN p_target_id END,
    v_subject_user_id, p_category, v_context, v_snapshot
  ) RETURNING id INTO v_report_id;

  RETURN v_report_id;
EXCEPTION
  WHEN unique_violation THEN RAISE EXCEPTION 'report_already_submitted';
END;
$$;
