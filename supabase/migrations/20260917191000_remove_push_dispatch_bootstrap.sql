-- The push dispatcher is configured; remove the one-time secret bootstrap RPC.

DROP FUNCTION public.bootstrap_push_dispatch();
