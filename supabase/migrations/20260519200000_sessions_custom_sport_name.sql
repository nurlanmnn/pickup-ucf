-- Optional label when sport enum is `other` (e.g. pickleball, badminton).
ALTER TABLE public.sessions
  ADD COLUMN IF NOT EXISTS custom_sport_name text;

COMMENT ON COLUMN public.sessions.custom_sport_name IS 'User-provided sport name when sport = other.';
