-- PickUp UCF Supabase Schema

-- 1. Profiles table
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT,
  name TEXT,
  avatar_url TEXT,
  is_verified_ucf BOOLEAN GENERATED ALWAYS AS (email ILIKE '%@ucf.edu') STORED,
  reliability_pct NUMERIC DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 2. Profile Sports table
CREATE TABLE IF NOT EXISTS profile_sports (
  profile_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  sport TEXT,
  skill TEXT CHECK (skill IN ('B', 'I', 'A')),
  PRIMARY KEY (profile_id, sport)
);

-- 3. Sessions table
CREATE TABLE IF NOT EXISTS sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sport TEXT NOT NULL,
  custom_sport TEXT,
  title TEXT,
  notes TEXT,
  starts_at TIMESTAMPTZ NOT NULL,
  ends_at TIMESTAMPTZ NOT NULL,
  lat NUMERIC,
  lng NUMERIC,
  address TEXT,
  saved_venue_key TEXT,
  capacity SMALLINT NOT NULL,
  is_indoor BOOLEAN DEFAULT false,
  skill_target TEXT CHECK (skill_target IN ('Any', 'B', 'I', 'A')) DEFAULT 'Any',
  positions TEXT[],
  equipment_needed BOOLEAN DEFAULT false,
  host_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  is_open BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Session Members table
CREATE TABLE IF NOT EXISTS session_members (
  session_id UUID REFERENCES sessions(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  status TEXT CHECK (status IN ('joined', 'waitlist', 'left')) NOT NULL DEFAULT 'joined',
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (session_id, user_id)
);

-- 5. Messages table
CREATE TABLE IF NOT EXISTS messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID REFERENCES sessions(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  body TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. Attendance table
CREATE TABLE IF NOT EXISTS attendance (
  session_id UUID REFERENCES sessions(id) ON DELETE CASCADE,
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  attended BOOLEAN,
  marked_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (session_id, user_id)
);

-- 7. Saved Sessions table
CREATE TABLE IF NOT EXISTS saved_sessions (
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  session_id UUID REFERENCES sessions(id) ON DELETE CASCADE,
  saved_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (user_id, session_id)
);

-- Enable Row Level Security
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE profile_sports ENABLE ROW LEVEL SECURITY;
ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE session_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE saved_sessions ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Drop existing policies if they exist, then recreate them
DROP POLICY IF EXISTS "Profiles are viewable by everyone" ON profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
DROP POLICY IF EXISTS "Allow automatic profile creation" ON profiles;
DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;

DROP POLICY IF EXISTS "Sessions are viewable by everyone" ON sessions;
DROP POLICY IF EXISTS "Users can create sessions" ON sessions;
DROP POLICY IF EXISTS "Hosts can update own sessions" ON sessions;
DROP POLICY IF EXISTS "Hosts can delete own sessions" ON sessions;

DROP POLICY IF EXISTS "Session members are viewable by everyone" ON session_members;
DROP POLICY IF EXISTS "Users can join sessions" ON session_members;

DROP POLICY IF EXISTS "Messages are viewable by members" ON messages;
DROP POLICY IF EXISTS "Joined members can send messages" ON messages;

DROP POLICY IF EXISTS "Attendance is viewable" ON attendance;
DROP POLICY IF EXISTS "Hosts can mark attendance" ON attendance;

DROP POLICY IF EXISTS "Saved sessions are viewable by owner" ON saved_sessions;
DROP POLICY IF EXISTS "Users can save sessions" ON saved_sessions;
DROP POLICY IF EXISTS "Users can unsave sessions" ON saved_sessions;

-- Profiles: Read all, update own
CREATE POLICY "Profiles are viewable by everyone" ON profiles FOR SELECT USING (true);
CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Allow automatic profile creation" ON profiles FOR INSERT WITH CHECK (true);
CREATE POLICY "Users can insert own profile" ON profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- Sessions: Read all open, hosts can manage
CREATE POLICY "Sessions are viewable by everyone" ON sessions FOR SELECT USING (true);
CREATE POLICY "Users can create sessions" ON sessions FOR INSERT WITH CHECK (auth.uid() = host_id);
CREATE POLICY "Hosts can update own sessions" ON sessions FOR UPDATE USING (auth.uid() = host_id);
CREATE POLICY "Hosts can delete own sessions" ON sessions FOR DELETE USING (auth.uid() = host_id);

-- Session Members: Read all, users can join themselves
CREATE POLICY "Session members are viewable by everyone" ON session_members FOR SELECT USING (true);
CREATE POLICY "Users can join sessions" ON session_members FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Messages: Read if member, write if joined member
CREATE POLICY "Messages are viewable by members" ON messages FOR SELECT 
  USING (EXISTS (SELECT 1 FROM session_members WHERE session_id = messages.session_id AND user_id = auth.uid()));
CREATE POLICY "Joined members can send messages" ON messages FOR INSERT 
  WITH CHECK (auth.uid() = user_id AND 
    EXISTS (SELECT 1 FROM session_members WHERE session_id = messages.session_id AND user_id = auth.uid() AND status = 'joined'));

-- Attendance: Read own or host, write host
CREATE POLICY "Attendance is viewable" ON attendance FOR SELECT USING (true);
CREATE POLICY "Hosts can mark attendance" ON attendance FOR INSERT 
  WITH CHECK (EXISTS (SELECT 1 FROM sessions WHERE id = attendance.session_id AND host_id = auth.uid()));

-- Saved Sessions: User-scoped
CREATE POLICY "Saved sessions are viewable by owner" ON saved_sessions FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can save sessions" ON saved_sessions FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users can unsave sessions" ON saved_sessions FOR DELETE USING (auth.uid() = user_id);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS sessions_starts_at_idx ON sessions(starts_at);
CREATE INDEX IF NOT EXISTS sessions_is_open_idx ON sessions(is_open);
CREATE INDEX IF NOT EXISTS session_members_session_id_idx ON session_members(session_id);
CREATE INDEX IF NOT EXISTS session_members_user_id_idx ON session_members(user_id);
CREATE INDEX IF NOT EXISTS messages_session_id_idx ON messages(session_id);

-- Function to automatically create profile on user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, name)
  VALUES (NEW.id, NEW.email, COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1)))
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to create profile when user signs up
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Function to calculate spots left
CREATE OR REPLACE FUNCTION get_spots_left(p_session_id UUID)
RETURNS INTEGER AS $$
DECLARE
  v_capacity INTEGER;
  v_joined_count INTEGER;
BEGIN
  SELECT capacity INTO v_capacity FROM sessions WHERE id = p_session_id;
  SELECT COUNT(*) INTO v_joined_count 
  FROM session_members 
  WHERE session_id = p_session_id AND status = 'joined';
  RETURN GREATEST(0, v_capacity - v_joined_count);
END;
$$ LANGUAGE plpgsql;

-- Function to automatically add host as a member when session is created
CREATE OR REPLACE FUNCTION public.handle_new_session()
RETURNS TRIGGER AS $$
BEGIN
  -- Add the host as a member so they can chat
  INSERT INTO public.session_members (session_id, user_id, status)
  VALUES (NEW.id, NEW.host_id, 'joined')
  ON CONFLICT (session_id, user_id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to add host as member when session is created
DROP TRIGGER IF EXISTS on_session_created ON sessions;
CREATE TRIGGER on_session_created
  AFTER INSERT ON sessions
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_session();
