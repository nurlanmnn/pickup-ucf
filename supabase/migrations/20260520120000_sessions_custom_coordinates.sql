-- Pin custom (non-venue) session locations on the map
ALTER TABLE public.sessions
  ADD COLUMN IF NOT EXISTS custom_lat double precision,
  ADD COLUMN IF NOT EXISTS custom_lng double precision;

COMMENT ON COLUMN public.sessions.custom_lat IS 'Latitude when venue_id is null';
COMMENT ON COLUMN public.sessions.custom_lng IS 'Longitude when venue_id is null';
