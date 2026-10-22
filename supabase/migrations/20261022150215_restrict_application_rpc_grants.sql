-- BETA-13: explicit role grants for application functions. Supabase default
-- privileges can grant anon/authenticated directly; revoking PUBLIC alone is insufficient.
-- Internal helpers remain callable by their SECURITY DEFINER owners. Cron runs as
-- postgres; the service role retains its existing execute grants.
REVOKE ALL ON FUNCTION public.acknowledge_moderation_notice(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.assert_user_content(text,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.block_user(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.complete_expired_sessions() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.complete_onboarding(sport_type[]) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.delete_own_account() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.end_departed_player_activities() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.enforce_user_content() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.enqueue_finished_session_cleanup() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.enqueue_notification(uuid,uuid,text,text,text,text,jsonb) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.enqueue_session_reminders(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.get_session_roster(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.guard_blocked_notification() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.is_current_user_moderator() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.is_session_participant(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.is_ucf_email() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.is_user_suspended(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.is_username_available(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.join_session(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.leave_session(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.list_blocked_users() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.list_moderation_reports(integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.list_my_moderation_notices() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.list_my_moderation_reports() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.moderate_report(uuid,moderation_action_type,text,integer) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.notify_chat_message() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.notify_host_player_joined() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.notify_session_cancelled() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.refresh_session_weather(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.refresh_upcoming_outdoor_weather() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.register_device_token(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.register_live_activity_token(uuid,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.session_is_outdoor_for_weather(uuid,double precision,double precision) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.should_notify(uuid,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.spawn_next_recurring_session(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.submit_moderation_report(report_target_type,uuid,report_category,text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.submit_session_attendance(uuid,uuid[]) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.sync_live_activity_session_schedule() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.touch_updated_at() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.unblock_user(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.unregister_device_token(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.users_are_blocked(uuid,uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.create_session(uuid,jsonb) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.acknowledge_moderation_notice(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.block_user(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.complete_onboarding(sport_type[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_own_account() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_session_roster(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_current_user_moderator() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_session_participant(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_ucf_email() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_user_suspended(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_username_available(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.join_session(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.leave_session(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_blocked_users() TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_moderation_reports(integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_my_moderation_notices() TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_my_moderation_reports() TO authenticated;
GRANT EXECUTE ON FUNCTION public.moderate_report(uuid,moderation_action_type,text,integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.register_device_token(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.register_live_activity_token(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_moderation_report(report_target_type,uuid,report_category,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_session_attendance(uuid,uuid[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.unblock_user(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.unregister_device_token(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.users_are_blocked(uuid,uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_session(uuid,jsonb) TO authenticated;

-- Advisor findings: invoker/trigger helpers also use a fixed path.
ALTER FUNCTION public.touch_updated_at() SET search_path = public;
ALTER FUNCTION public.is_ucf_email() SET search_path = public;
ALTER FUNCTION public.session_is_outdoor_for_weather(uuid,double precision,double precision) SET search_path = public;

-- All membership/count changes go through transactional owner functions. Preserve
-- host edit/cancel and profile-upsert fields used by the released client.
REVOKE INSERT, UPDATE, DELETE ON public.session_participants FROM PUBLIC, anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.sessions FROM PUBLIC, anon, authenticated;
GRANT UPDATE (sport, custom_sport_name, venue_id, custom_location, custom_lat, custom_lng,
  starts_at, ends_at, capacity, skill_level, notes, status) ON public.sessions TO authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.profiles FROM PUBLIC, anon, authenticated;
GRANT INSERT (id, display_name, username, avatar_url, preferred_sports) ON public.profiles TO authenticated;
-- id is needed by PostgREST's profile upsert conflict update, still owner-scoped by RLS.
GRANT UPDATE (id, display_name, username, avatar_url, preferred_sports) ON public.profiles TO authenticated;

-- Deleted accounts can retain an unexpired JWT. Authorization must check the
-- current confirmed account, not only a stale email claim. This returns one bit
-- for the caller; it never exposes auth records or editable metadata.
CREATE OR REPLACE FUNCTION public.is_ucf_email()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (
    SELECT 1 FROM auth.users u WHERE u.id = auth.uid()
      AND u.email_confirmed_at IS NOT NULL
      AND lower(u.email) ~ '@(knights\.)?ucf\.edu$'
  );
$$;
REVOKE ALL ON FUNCTION public.is_ucf_email() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_ucf_email() TO authenticated;
