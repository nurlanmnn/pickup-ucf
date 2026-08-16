-- Remove global profile skill level; skill is per-session only.

DROP FUNCTION IF EXISTS public.complete_onboarding(sport_type[], skill_level);

CREATE OR REPLACE FUNCTION public.complete_onboarding(p_preferred_sports sport_type[])
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  IF p_preferred_sports IS NULL OR array_length(p_preferred_sports, 1) IS NULL THEN
    RAISE EXCEPTION 'preferred_sports_required';
  END IF;

  UPDATE public.profiles
  SET
    preferred_sports = p_preferred_sports,
    onboarding_completed_at = now(),
    updated_at = now()
  WHERE id = auth.uid();
END;
$$;

GRANT EXECUTE ON FUNCTION public.complete_onboarding(sport_type[]) TO authenticated;

ALTER TABLE public.profiles
  DROP COLUMN IF EXISTS skill_level;
