-- One-time recovery helper for synchronizing the Vault-backed cron credential
-- with the send-push Edge Function secret. Removed by the follow-up migration.

CREATE OR REPLACE FUNCTION public.rotate_push_dispatch_secret()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_secret text;
  v_secret_id uuid;
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

  RETURN v_secret;
END;
$$;

REVOKE ALL ON FUNCTION public.rotate_push_dispatch_secret() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rotate_push_dispatch_secret() TO service_role;
