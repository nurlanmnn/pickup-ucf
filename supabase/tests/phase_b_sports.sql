-- Phase B Task B1: sport_type enum expansion
DO $$
BEGIN
  PERFORM 'pickleball'::sport_type;
  PERFORM 'flag_football'::sport_type;
  PERFORM 'cornhole'::sport_type;
  RAISE NOTICE 'phase_b_sports: enum values OK';
END $$;
