-- Phase B Task B1: expand sport_type for UCF RWC intramural sports

ALTER TYPE sport_type ADD VALUE IF NOT EXISTS 'pickleball';
ALTER TYPE sport_type ADD VALUE IF NOT EXISTS 'flag_football';
ALTER TYPE sport_type ADD VALUE IF NOT EXISTS 'spikeball';
ALTER TYPE sport_type ADD VALUE IF NOT EXISTS 'softball';
ALTER TYPE sport_type ADD VALUE IF NOT EXISTS 'floor_hockey';
ALTER TYPE sport_type ADD VALUE IF NOT EXISTS 'dodgeball';
ALTER TYPE sport_type ADD VALUE IF NOT EXISTS 'racquetball';
ALTER TYPE sport_type ADD VALUE IF NOT EXISTS 'badminton';
ALTER TYPE sport_type ADD VALUE IF NOT EXISTS 'cornhole';
