-- BETA-13: public policy helpers must not disclose unrelated users' private state.
-- pickup_private is intentionally not a Data API exposed schema. Preserve the raw
-- functions/OIDs/ACLs for policies and trusted definer-owned internal operations.
ALTER FUNCTION public.users_are_blocked(uuid,uuid) SET SCHEMA pickup_private;
ALTER FUNCTION public.is_user_suspended(uuid) SET SCHEMA pickup_private;

-- Invoker wrappers distinguish an untrusted API/RLS call from a trusted nested
-- SECURITY DEFINER operation without trusting JWT metadata or a caller flag.
CREATE FUNCTION public.users_are_blocked(p_first uuid,p_second uuid)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path='' AS $$
BEGIN
  IF current_user='authenticated' AND (
    auth.uid() IS NULL OR
    (auth.uid() IS DISTINCT FROM p_first AND auth.uid() IS DISTINCT FROM p_second)
  ) THEN
    RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='helper_scope_denied';
  END IF;
  RETURN pickup_private.users_are_blocked(p_first,p_second);
END; $$;
CREATE FUNCTION public.is_user_suspended(p_user_id uuid)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path='' AS $$
BEGIN
  IF current_user='authenticated' AND (
    auth.uid() IS NULL OR auth.uid() IS DISTINCT FROM p_user_id
  ) THEN
    RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='helper_scope_denied';
  END IF;
  RETURN pickup_private.is_user_suspended(p_user_id);
END; $$;
REVOKE ALL ON FUNCTION public.users_are_blocked(uuid,uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.is_user_suspended(uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.users_are_blocked(uuid,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_user_suspended(uuid) TO authenticated;
