-- Migration: Add postal_codes table for geocoding
-- This table stores postal codes with lat/lng
-- Starting with Germany; more countries can be added later

-- Create optimized postal_codes table (no place_name to save storage)
-- Note: For now, "country" is a free-form text value that must match heating_systems.country exactly
-- (e.g. "Deutschland"). We can normalize to ISO country codes later.
CREATE TABLE IF NOT EXISTS "public"."postal_codes" (
    "postal_code" TEXT NOT NULL,
    "country" TEXT NOT NULL,
    "latitude_deg" DOUBLE PRECISION NOT NULL,
    "longitude_deg" DOUBLE PRECISION NOT NULL,
    CONSTRAINT "postal_codes_pkey" PRIMARY KEY ("postal_code", "country"),
    CONSTRAINT "postal_codes_latitude_deg_check" CHECK (("latitude_deg" >= (-90)::double precision) AND ("latitude_deg" <= (90)::double precision)),
    CONSTRAINT "postal_codes_longitude_deg_check" CHECK (("longitude_deg" >= (-180)::double precision) AND ("longitude_deg" <= (180)::double precision))
);

ALTER TABLE "public"."postal_codes" OWNER TO "postgres";

-- Create index for faster lookups on partial postal codes
CREATE INDEX IF NOT EXISTS "postal_codes_partial_lookup_idx" 
ON "public"."postal_codes" 
USING btree ("country", "postal_code" text_pattern_ops);

-- Grant permissions
-- Keep this table read-only for clients; write access is reserved for service_role.
GRANT SELECT ON TABLE "public"."postal_codes" TO "anon";
GRANT SELECT ON TABLE "public"."postal_codes" TO "authenticated";
GRANT ALL ON TABLE "public"."postal_codes" TO "service_role";

-- Enable RLS
ALTER TABLE "public"."postal_codes" ENABLE ROW LEVEL SECURITY;

-- Policy: Public read access (consistent with other "Anyone can view ..." policies)
CREATE POLICY "Anyone can view postal codes"
ON "public"."postal_codes"
FOR SELECT
USING (true);

-- Create a function to find the best matching postal code for obfuscated entries
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

-- Create a view that joins heating_systems with postal_codes
CREATE OR REPLACE VIEW "public"."heating_systems_with_location_view" 
WITH (security_invoker='true') AS
SELECT 
  hs.*,
  pc.latitude_deg,
  pc.longitude_deg
FROM "public"."heating_systems" hs
LEFT JOIN LATERAL (
  SELECT * FROM "public"."find_postal_code_coordinates"(hs.postal_code, hs.country)
) pc ON true;

ALTER VIEW "public"."heating_systems_with_location_view" OWNER TO "postgres";

-- Note: We currently store postal_codes.country as free-form text (e.g. "Deutschland").
-- If you later want normalized ISO country codes, introduce a dedicated country_code column
-- (or a domain) and migrate both heating_systems and postal_codes to use it.
