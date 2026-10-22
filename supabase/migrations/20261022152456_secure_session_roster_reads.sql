-- BETA-13: share one visibility gate between session RLS and the roster RPC.
-- Keep exact waitlist counts/position while withholding blocked profile identities.
CREATE FUNCTION pickup_private.can_view_session(p_session_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path='' AS $$
 SELECT public.is_ucf_email() AND EXISTS (
   SELECT 1 FROM public.sessions s WHERE s.id=p_session_id
     AND NOT public.users_are_blocked(auth.uid(),s.host_id)
     AND ((s.status IN ('open','full') AND s.starts_at>now())
       OR s.host_id=auth.uid() OR public.is_session_participant(s.id))
 );
$$;
REVOKE ALL ON FUNCTION pickup_private.can_view_session(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION pickup_private.can_view_session(uuid) TO authenticated;
DROP POLICY sessions_select ON public.sessions;
CREATE POLICY sessions_select ON public.sessions FOR SELECT TO authenticated
 USING (pickup_private.can_view_session(id));

CREATE OR REPLACE FUNCTION public.get_session_roster(p_session_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result jsonb;
  v_viewer_waitlist int;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  IF NOT pickup_private.can_view_session(p_session_id) THEN RAISE EXCEPTION 'session_not_found'; END IF;

  SELECT row_number INTO v_viewer_waitlist
  FROM (
    SELECT user_id, row_number() OVER (ORDER BY joined_at) AS row_number
    FROM public.session_participants
    WHERE session_id = p_session_id AND status = 'waitlist'
  ) w
  WHERE user_id = auth.uid();

  SELECT jsonb_build_object(
    'joined', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'user_id', sp.user_id,
        'display_name', p.display_name,
        'username', p.username,
        'role', sp.role
      ) ORDER BY sp.joined_at)
      FROM public.session_participants sp
      JOIN public.profiles p ON p.id = sp.user_id
      WHERE sp.session_id = p_session_id AND sp.status = 'joined'
        AND NOT public.users_are_blocked(auth.uid(),sp.user_id)
    ), '[]'::jsonb),
    'waitlist_count', (
      SELECT count(*)::int FROM public.session_participants
      WHERE session_id = p_session_id AND status = 'waitlist'
    ),
    'viewer_waitlist_position', v_viewer_waitlist
  ) INTO v_result;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_session_roster(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.get_session_roster(uuid) FROM PUBLIC,anon;
