-- One-time production bootstrap for the push-dispatch scheduler.
-- The helper is removed by the follow-up migration after CRON_SECRET is synced.

CREATE OR REPLACE FUNCTION public.bootstrap_push_dispatch()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_secret text;
  v_secret_id uuid;
  v_existing_job_id bigint;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RAISE EXCEPTION 'service_role required' USING ERRCODE = '42501';
  END IF;

  v_secret := encode(extensions.gen_random_bytes(32), 'hex');

  SELECT id
  INTO v_secret_id
  FROM vault.secrets
  WHERE name = 'pickup_push_cron_secret';

  IF v_secret_id IS NULL THEN
    PERFORM vault.create_secret(
      v_secret,
      'pickup_push_cron_secret',
      'Bearer credential for the PickUp UCF push dispatcher'
    );
  ELSE
    PERFORM vault.update_secret(
      v_secret_id,
      v_secret,
      'pickup_push_cron_secret',
      'Bearer credential for the PickUp UCF push dispatcher'
    );
  END IF;

  SELECT jobid
  INTO v_existing_job_id
  FROM cron.job
  WHERE jobname = 'pickup-dispatch-push';

  IF v_existing_job_id IS NOT NULL THEN
    PERFORM cron.unschedule(v_existing_job_id);
  END IF;

  PERFORM cron.schedule(
    'pickup-dispatch-push',
    '* * * * *',
    $job$
      SELECT net.http_post(
        url := 'https://dkvonsrdxqenozdkufwe.supabase.co/functions/v1/send-push',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || (
            SELECT decrypted_secret
            FROM vault.decrypted_secrets
            WHERE name = 'pickup_push_cron_secret'
          )
        ),
        body := '{}'::jsonb,
        timeout_milliseconds := 10000
      );
    $job$
  );

  RETURN v_secret;
END;
$$;

REVOKE ALL ON FUNCTION public.bootstrap_push_dispatch() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.bootstrap_push_dispatch() TO service_role;
