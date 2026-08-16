-- Phase B Task B3: onboarding completion column and RPC

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS onboarding_completed_at timestamptz;

CREATE OR REPLACE FUNCTION public.complete_onboarding(
  p_preferred_sports sport_type[],
  p_skill_level skill_level
)
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
    skill_level = p_skill_level,
    onboarding_completed_at = now(),
    updated_at = now()
  WHERE id = auth.uid();
END;
$$;

GRANT EXECUTE ON FUNCTION public.complete_onboarding(sport_type[], skill_level) TO authenticated;
