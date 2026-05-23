-- PickUp UCF initial schema

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Enums
CREATE TYPE sport_type AS ENUM ('basketball', 'soccer', 'tennis', 'volleyball', 'football', 'other');
CREATE TYPE skill_level AS ENUM ('any', 'beginner', 'intermediate', 'advanced');
CREATE TYPE session_status AS ENUM ('open', 'full', 'cancelled', 'completed');
CREATE TYPE participant_status AS ENUM ('joined', 'waitlist', 'left');
CREATE TYPE participant_role AS ENUM ('host', 'player');

-- Helpers
CREATE OR REPLACE FUNCTION public.is_ucf_email()
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT COALESCE(
    auth.jwt() ->> 'email' LIKE '%@ucf.edu'
    OR auth.jwt() ->> 'email' LIKE '%@knights.ucf.edu',
    false
  );
$$;

CREATE OR REPLACE FUNCTION public.touch_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- Profiles
CREATE TABLE public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
  display_name text NOT NULL,
  username text CHECK (username IS NULL OR username ~ '^[a-z0-9_]{3,20}$'),
  avatar_url text,
  skill_level skill_level,
  preferred_sports sport_type[] DEFAULT '{}',
  games_played int NOT NULL DEFAULT 0 CHECK (games_played >= 0),
  show_up_streak int NOT NULL DEFAULT 0 CHECK (show_up_streak >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX idx_profiles_username_lower ON public.profiles (lower(username))
  WHERE username IS NOT NULL;
CREATE INDEX idx_profiles_display_name ON public.profiles (display_name);

-- Venues
CREATE TABLE public.venues (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  lat double precision NOT NULL,
  lng double precision NOT NULL,
  campus_zone text,
  is_official boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Sessions
CREATE TABLE public.sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  host_id uuid NOT NULL REFERENCES public.profiles (id) ON DELETE RESTRICT,
  sport sport_type NOT NULL,
  venue_id uuid REFERENCES public.venues (id) ON DELETE SET NULL,
  custom_location text,
  starts_at timestamptz NOT NULL,
  ends_at timestamptz NOT NULL,
  capacity int NOT NULL CHECK (capacity > 0),
  player_count int NOT NULL DEFAULT 0 CHECK (player_count >= 0),
  skill_level skill_level NOT NULL,
  notes text,
  status session_status NOT NULL DEFAULT 'open',
  recurrence_rule text,
  weather_snapshot jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (ends_at > starts_at),
  CHECK (player_count <= capacity)
);

CREATE INDEX idx_sessions_upcoming ON public.sessions (starts_at)
  WHERE status IN ('open', 'full');
CREATE INDEX idx_sessions_sport_skill ON public.sessions (sport, skill_level, starts_at);

-- Participants
CREATE TABLE public.session_participants (
  session_id uuid NOT NULL REFERENCES public.sessions (id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  role participant_role NOT NULL DEFAULT 'player',
  status participant_status NOT NULL DEFAULT 'joined',
  checked_in_at timestamptz,
  joined_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (session_id, user_id)
);

CREATE INDEX idx_participants_user ON public.session_participants (user_id, session_id);

CREATE OR REPLACE FUNCTION public.is_session_participant(p_session_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.session_participants sp
    WHERE sp.session_id = p_session_id
      AND sp.user_id = auth.uid()
      AND sp.status IN ('joined', 'waitlist')
  );
$$;

-- Messages
CREATE TABLE public.messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id uuid NOT NULL REFERENCES public.sessions (id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  body text NOT NULL CHECK (length(trim(body)) > 0),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_messages_session_created ON public.messages (session_id, created_at DESC);

-- Device tokens
CREATE TABLE public.device_tokens (
  user_id uuid NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  apns_token text NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, apns_token)
);

-- Attendance
CREATE TABLE public.attendance (
  session_id uuid NOT NULL REFERENCES public.sessions (id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  marked_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (session_id, user_id)
);

-- Triggers
CREATE TRIGGER profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

CREATE TRIGGER sessions_updated_at
  BEFORE UPDATE ON public.sessions
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

-- Username availability
CREATE OR REPLACE FUNCTION public.is_username_available(p_username text)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT NOT EXISTS (
    SELECT 1 FROM public.profiles WHERE lower(username) = lower(p_username)
  );
$$;

GRANT EXECUTE ON FUNCTION public.is_username_available(text) TO authenticated;

-- Join / leave session
CREATE OR REPLACE FUNCTION public.join_session(p_session_id uuid)
RETURNS participant_status
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_capacity int;
  v_count int;
  v_session_status session_status;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  SELECT capacity, player_count, status
  INTO v_capacity, v_count, v_session_status
  FROM public.sessions
  WHERE id = p_session_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'session_not_found';
  END IF;

  IF v_session_status NOT IN ('open', 'full') THEN
    RAISE EXCEPTION 'session_not_joinable';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.session_participants
    WHERE session_id = p_session_id AND user_id = auth.uid() AND status = 'joined'
  ) THEN
    RETURN 'joined';
  END IF;

  IF v_count < v_capacity THEN
    INSERT INTO public.session_participants (session_id, user_id, role, status)
    VALUES (p_session_id, auth.uid(), 'player', 'joined')
    ON CONFLICT (session_id, user_id)
    DO UPDATE SET status = 'joined', joined_at = now();

    UPDATE public.sessions
    SET player_count = player_count + 1,
        status = CASE WHEN player_count + 1 >= capacity THEN 'full'::session_status ELSE status END
    WHERE id = p_session_id;

    RETURN 'joined';
  END IF;

  INSERT INTO public.session_participants (session_id, user_id, role, status)
  VALUES (p_session_id, auth.uid(), 'player', 'waitlist')
  ON CONFLICT (session_id, user_id)
  DO UPDATE SET status = 'waitlist';

  RETURN 'waitlist';
END;
$$;

CREATE OR REPLACE FUNCTION public.leave_session(p_session_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_prev_status participant_status;
BEGIN
  SELECT status INTO v_prev_status
  FROM public.session_participants
  WHERE session_id = p_session_id AND user_id = auth.uid();

  IF NOT FOUND THEN
    RETURN;
  END IF;

  UPDATE public.session_participants
  SET status = 'left'
  WHERE session_id = p_session_id AND user_id = auth.uid();

  IF v_prev_status = 'joined' THEN
    UPDATE public.sessions
    SET player_count = GREATEST(0, player_count - 1),
        status = 'open'
    WHERE id = p_session_id AND status = 'full';

    -- Promote oldest waitlist
    WITH next_wait AS (
      SELECT user_id FROM public.session_participants
      WHERE session_id = p_session_id AND status = 'waitlist'
      ORDER BY joined_at ASC
      LIMIT 1
    )
    UPDATE public.session_participants sp
    SET status = 'joined'
    FROM next_wait nw
    WHERE sp.session_id = p_session_id AND sp.user_id = nw.user_id;

    UPDATE public.sessions
    SET player_count = player_count + 1
    WHERE id = p_session_id
      AND EXISTS (
        SELECT 1 FROM public.session_participants
        WHERE session_id = p_session_id AND status = 'joined'
      );
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.join_session(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.leave_session(uuid) TO authenticated;

-- Delete own account
CREATE OR REPLACE FUNCTION public.delete_own_account()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE uid uuid := auth.uid();
BEGIN
  IF uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  UPDATE public.sessions
  SET status = 'cancelled', updated_at = now()
  WHERE host_id = uid
    AND status IN ('open', 'full')
    AND starts_at > now();

  DELETE FROM auth.users WHERE id = uid;
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_own_account() TO authenticated;

-- RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.venues ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.session_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;

CREATE POLICY profiles_select ON public.profiles
  FOR SELECT TO authenticated
  USING (public.is_ucf_email());

CREATE POLICY profiles_insert ON public.profiles
  FOR INSERT TO authenticated
  WITH CHECK (id = auth.uid() AND public.is_ucf_email());

CREATE POLICY profiles_update ON public.profiles
  FOR UPDATE TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());

CREATE POLICY venues_select ON public.venues
  FOR SELECT TO authenticated
  USING (public.is_ucf_email());

CREATE POLICY sessions_select ON public.sessions
  FOR SELECT TO authenticated
  USING (public.is_ucf_email() AND status IN ('open', 'full') AND starts_at > now() - interval '1 hour');

CREATE POLICY sessions_insert ON public.sessions
  FOR INSERT TO authenticated
  WITH CHECK (host_id = auth.uid() AND public.is_ucf_email());

CREATE POLICY sessions_update ON public.sessions
  FOR UPDATE TO authenticated
  USING (host_id = auth.uid())
  WITH CHECK (host_id = auth.uid());

CREATE POLICY participants_select ON public.session_participants
  FOR SELECT TO authenticated
  USING (public.is_ucf_email());

CREATE POLICY participants_insert ON public.session_participants
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY messages_select ON public.messages
  FOR SELECT TO authenticated
  USING (public.is_session_participant(session_id));

CREATE POLICY messages_insert ON public.messages
  FOR INSERT TO authenticated
  WITH CHECK (
    user_id = auth.uid()
    AND public.is_session_participant(session_id)
  );

CREATE POLICY device_tokens_all ON public.device_tokens
  FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
ALTER PUBLICATION supabase_realtime ADD TABLE public.session_participants;
