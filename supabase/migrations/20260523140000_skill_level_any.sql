-- Open sessions to all skill levels
ALTER TYPE public.skill_level ADD VALUE IF NOT EXISTS 'any' BEFORE 'beginner';
