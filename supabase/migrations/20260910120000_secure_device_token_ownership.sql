-- A physical APNs token may belong to only one current account.
-- Normalize legacy rows first, discard values APNs cannot use, and retain the
-- most recently updated owner when historical duplicates exist.
DELETE FROM public.device_tokens
WHERE length(lower(btrim(apns_token))) < 32
   OR length(lower(btrim(apns_token))) > 512
   OR length(lower(btrim(apns_token))) % 2 <> 0
   OR lower(btrim(apns_token)) !~ '^[0-9a-f]+$';

WITH ranked_tokens AS (
  SELECT
    ctid,
    row_number() OVER (
      PARTITION BY lower(btrim(apns_token))
      ORDER BY updated_at DESC, user_id DESC
    ) AS ownership_rank
  FROM public.device_tokens
)
DELETE FROM public.device_tokens AS device_token
USING ranked_tokens
WHERE device_token.ctid = ranked_tokens.ctid
  AND ranked_tokens.ownership_rank > 1;

UPDATE public.device_tokens
SET apns_token = lower(btrim(apns_token));

ALTER TABLE public.device_tokens
  DROP CONSTRAINT device_tokens_pkey;

ALTER TABLE public.device_tokens
  ADD CONSTRAINT device_tokens_pkey PRIMARY KEY (apns_token);

CREATE INDEX idx_device_tokens_user_id
  ON public.device_tokens (user_id);

DROP POLICY IF EXISTS device_tokens_all ON public.device_tokens;
REVOKE ALL ON TABLE public.device_tokens FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT, DELETE ON TABLE public.device_tokens TO service_role;

CREATE OR REPLACE FUNCTION public.register_device_token(p_apns_token text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_token text := lower(btrim(p_apns_token));
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  IF v_token IS NULL
     OR length(v_token) < 32
     OR length(v_token) > 512
     OR length(v_token) % 2 <> 0
     OR v_token !~ '^[0-9a-f]+$' THEN
    RAISE EXCEPTION 'invalid_device_token';
  END IF;

  INSERT INTO public.device_tokens (user_id, apns_token, updated_at)
  VALUES (v_user_id, v_token, now())
  ON CONFLICT (apns_token) DO UPDATE
  SET user_id = EXCLUDED.user_id,
      updated_at = now();
END;
$$;

REVOKE ALL ON FUNCTION public.register_device_token(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.register_device_token(text) TO authenticated;

CREATE OR REPLACE FUNCTION public.unregister_device_token(p_apns_token text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_token text := lower(btrim(p_apns_token));
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  IF v_token IS NULL
     OR length(v_token) < 32
     OR length(v_token) > 512
     OR length(v_token) % 2 <> 0
     OR v_token !~ '^[0-9a-f]+$' THEN
    RAISE EXCEPTION 'invalid_device_token';
  END IF;

  DELETE FROM public.device_tokens
  WHERE apns_token = v_token
    AND user_id = v_user_id;
END;
$$;

REVOKE ALL ON FUNCTION public.unregister_device_token(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.unregister_device_token(text) TO authenticated;
