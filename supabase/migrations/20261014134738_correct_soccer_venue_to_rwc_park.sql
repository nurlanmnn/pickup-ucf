-- UCF's official RWC Park directions pin:
-- https://www.ucf.edu/location/rwc-park/
-- Address: 12669 Scholarship Dr, Orlando, FL 32816 (UCF IMLeagues facility).
-- Update in place so existing sessions retain their venue_id.
UPDATE public.venues
SET name = 'RWC Park',
    lat = 28.592627488099,
    lng = -81.200138801506
WHERE name = 'Soccer Practice Fields'
  AND is_official = true;
