-- Prevent postal code lookup from returning arbitrary coordinates for empty/blank inputs
--
-- Without this guard, an empty postal code can lead to a prefix of '' and a query like
--   postal_code LIKE '%'
-- which would return the first row in postal_codes.

CREATE OR REPLACE FUNCTION "public"."find_postal_code_coordinates"(
  "p_postal_code" TEXT,
  "p_country" TEXT
) RETURNS TABLE (
  postal_code TEXT,
  latitude_deg DOUBLE PRECISION,
  longitude_deg DOUBLE PRECISION
)
LANGUAGE "plpgsql"
AS $$
DECLARE
  clean_prefix TEXT;
BEGIN
  -- Guard against NULL/blank inputs: no coordinates should be returned.
  IF p_postal_code IS NULL OR btrim(p_postal_code) = '' THEN
    RETURN;
  END IF;

  IF p_country IS NULL OR btrim(p_country) = '' THEN
    RETURN;
  END IF;

  -- First try exact match
  RETURN QUERY
  SELECT 
    pc.postal_code,
    pc.latitude_deg,
    pc.longitude_deg
  FROM "public"."postal_codes" pc
  WHERE pc.country = p_country
    AND pc.postal_code = p_postal_code
  LIMIT 1;

  -- If no exact match found, try prefix match (for obfuscated codes like "1234?", "12***", "12.")
  IF NOT FOUND THEN
    -- Remove special characters (?, *, ., spaces) and use as prefix
    clean_prefix := regexp_replace(p_postal_code, '[?*. ]', '', 'g');

    -- If the cleaned prefix is empty, do not fall back to a broad match.
    IF clean_prefix IS NULL OR clean_prefix = '' THEN
      RETURN;
    END IF;

    RETURN QUERY
    SELECT 
      pc.postal_code,
      pc.latitude_deg,
      pc.longitude_deg
    FROM "public"."postal_codes" pc
    WHERE pc.country = p_country
      AND pc.postal_code LIKE (clean_prefix || '%')
    ORDER BY pc.postal_code
    LIMIT 1;
  END IF;
END;
$$;

ALTER FUNCTION "public"."find_postal_code_coordinates"("p_postal_code" TEXT, "p_country" TEXT) OWNER TO "postgres";
