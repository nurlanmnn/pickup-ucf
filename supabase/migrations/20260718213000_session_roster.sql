-- Tier 1 Task T1-4: session roster and waitlist position RPC

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
