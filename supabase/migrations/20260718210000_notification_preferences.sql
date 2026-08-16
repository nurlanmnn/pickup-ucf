-- Tier 1 Task T1-1: notification preferences table

CREATE TABLE public.notification_preferences (
  user_id uuid PRIMARY KEY REFERENCES public.profiles (id) ON DELETE CASCADE,
  session_reminders boolean NOT NULL DEFAULT true,
  waitlist_promoted boolean NOT NULL DEFAULT true,
  session_cancelled boolean NOT NULL DEFAULT true,
  host_player_joined boolean NOT NULL DEFAULT true,
  host_session_reminder boolean NOT NULL DEFAULT true,
  chat_messages boolean NOT NULL DEFAULT true,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;

CREATE POLICY notification_preferences_own ON public.notification_preferences
  FOR ALL TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE TRIGGER notification_preferences_updated_at
  BEFORE UPDATE ON public.notification_preferences
  FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();
