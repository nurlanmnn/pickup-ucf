-- BETA-03: align client/server Unicode normalization and required text limits.
-- Existing triggers and RPCs remain authoritative; no historical rows rewritten.
CREATE OR REPLACE FUNCTION public.assert_user_content(p_value text, p_field text)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public
AS $$
DECLARE
  v_value text;
  v_folded text;
  v_max int;
BEGIN
  -- Reject raw C0/C1 controls before whitespace normalization; retain emoji ZWJ.
  IF EXISTS (SELECT 1 FROM unnest(string_to_array(COALESCE(p_value, ''), NULL)) AS c
    WHERE (ascii(c) < 32 OR ascii(c) BETWEEN 127 AND 159) AND ascii(c) NOT IN (9,10,13)) THEN
    RAISE EXCEPTION 'user_content_rejected';
  END IF;
  v_value := NULLIF(btrim(regexp_replace(normalize(p_value, NFC),
    U&'[\0009\000A\000D\0020\00A0\1680\2000-\200A\2028\2029\202F\205F\3000]+', ' ', 'g')), '');
  IF v_value IS NULL THEN
    IF p_field IN ('display_name', 'chat_message') THEN
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'user_content_required';
    END IF;
    RETURN NULL;
  END IF;
  v_max := CASE p_field
    WHEN 'display_name' THEN 80
    WHEN 'session_notes' THEN 1000
    WHEN 'custom_sport' THEN 40
    WHEN 'custom_location' THEN 120
    WHEN 'chat_message' THEN 500
    WHEN 'report_context' THEN 500
    ELSE 500
  END;
  IF char_length(v_value) > v_max THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'user_content_too_long';
  END IF;

  v_folded := lower(translate(v_value, '013', 'oie'));
  IF v_folded ~ '(i|we) (will|am going to|are going to|gonna) (kill|hurt|shoot|stab) (you|u|him|her|them)'
     OR v_folded ~ '(send|show) (me )?(nude|nudes|explicit photos)'
     OR v_folded ~ '(n[i1]gg+[e3]r|f[a@]gg+[o0]t|k[i1]k[e3])'
     OR lower(v_value) ~ 'https?://|www\.'
     OR lower(v_value) ~ '(text|call) me (at )?[+]?[0-9][0-9 ().-]{8,}[0-9]' THEN
    RAISE EXCEPTION 'user_content_rejected';
  END IF;
  RETURN v_value;
END;
$$;

REVOKE ALL ON FUNCTION public.assert_user_content(text, text) FROM PUBLIC, anon, authenticated;
