-- BETA-13: clients cannot forge message time/identity and poison chat ordering.
-- Current source and TestFlight build 5 send exactly these three fields.
REVOKE INSERT ON public.messages FROM PUBLIC,anon,authenticated;
REVOKE INSERT (id,session_id,user_id,body,created_at) ON public.messages FROM PUBLIC,anon,authenticated;
GRANT INSERT (session_id,user_id,body) ON public.messages TO authenticated;
