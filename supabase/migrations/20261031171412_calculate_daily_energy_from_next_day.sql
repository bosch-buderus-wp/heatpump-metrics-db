-- Preserve both public view contracts, including their different temperature handling.
-- Completed days use the first reading on that day and the first reading on the
-- immediately following calendar day. A missing next day produces NULL energy;
-- the current day remains a partial value when at least two readings exist.
-- Dates retain the session-time-zone semantics of the previous views. Irregular
-- upload times can make the measured interval different from a calendar day.
-- Negative differences remain visible, as in the previous calculation.
-- The two view definitions stay independent to preserve their permission paths.

CREATE OR REPLACE VIEW public.daily_values WITH (security_invoker = true) AS
WITH daily_aggregates AS (
  SELECT
    DATE(m.created_at) as date,
    m.heating_id,
    m.user_id,

    -- Keep one first and last counter reading per calendar day.
    (ARRAY_AGG(m.thermal_energy_kwh ORDER BY m.created_at ASC, m.id ASC))[1] as first_thermal_energy_kwh,
    (ARRAY_AGG(m.thermal_energy_kwh ORDER BY m.created_at DESC, m.id DESC))[1] as last_thermal_energy_kwh,

    (ARRAY_AGG(m.electrical_energy_kwh ORDER BY m.created_at ASC, m.id ASC))[1] as first_electrical_energy_kwh,
    (ARRAY_AGG(m.electrical_energy_kwh ORDER BY m.created_at DESC, m.id DESC))[1] as last_electrical_energy_kwh,

    (ARRAY_AGG(m.thermal_energy_heating_kwh ORDER BY m.created_at ASC, m.id ASC))[1] as first_thermal_energy_heating_kwh,
    (ARRAY_AGG(m.thermal_energy_heating_kwh ORDER BY m.created_at DESC, m.id DESC))[1] as last_thermal_energy_heating_kwh,

    (ARRAY_AGG(m.electrical_energy_heating_kwh ORDER BY m.created_at ASC, m.id ASC))[1] as first_electrical_energy_heating_kwh,
    (ARRAY_AGG(m.electrical_energy_heating_kwh ORDER BY m.created_at DESC, m.id DESC))[1] as last_electrical_energy_heating_kwh,

    -- Average temperatures
    AVG(m.outdoor_temperature_c) as outdoor_temperature_c,
    AVG(m.flow_temperature_c) as flow_temperature_c,

    -- Two readings are needed for a partial current-day value.
    COUNT(*) as measurement_count

  FROM public.measurements m
  GROUP BY DATE(m.created_at), m.heating_id, m.user_id
), daily_intervals AS (
  SELECT da.*, LEAD(da.date) OVER w AS next_date,
    LEAD(da.first_thermal_energy_kwh) OVER w AS next_thermal_energy_kwh,
    LEAD(da.first_electrical_energy_kwh) OVER w AS next_electrical_energy_kwh,
    LEAD(da.first_thermal_energy_heating_kwh) OVER w AS next_thermal_energy_heating_kwh,
    LEAD(da.first_electrical_energy_heating_kwh) OVER w AS next_electrical_energy_heating_kwh
  FROM daily_aggregates da
  WINDOW w AS (PARTITION BY da.heating_id, da.user_id ORDER BY da.date)
)
SELECT
  da.date,
  da.heating_id,
  da.user_id,
  hs.name,
  hs.heating_type,
  hs.model_idu,
  hs.model_odu,
  hs.country,
  hs.postal_code,
  hs.heating_load_kw,
  hs.heated_area_m2,
  hs.building_construction_year,
  hs.design_outdoor_temp_c,
  hs.building_energy_standard,
  hs.building_type,
  hs.used_for_heating,
  hs.used_for_dhw,
  hs.used_for_cooling,
  hs.sw_idu,
  hs.sw_odu,
  hs.thermometer_offset_k,
  calc.thermal_energy_kwh,
  calc.electrical_energy_kwh,
  calc.thermal_energy_heating_kwh,
  calc.electrical_energy_heating_kwh,

  da.outdoor_temperature_c,

  da.flow_temperature_c,

  -- Computed COP values
  CASE
    WHEN calc.electrical_energy_kwh > 0 AND calc.thermal_energy_kwh IS NOT NULL
    THEN calc.thermal_energy_kwh / calc.electrical_energy_kwh
    ELSE NULL
  END as az,

  CASE
    WHEN calc.electrical_energy_heating_kwh > 0 AND calc.thermal_energy_heating_kwh IS NOT NULL
    THEN calc.thermal_energy_heating_kwh / calc.electrical_energy_heating_kwh
    ELSE NULL
  END as az_heating,
  hs.model_family_id

FROM daily_intervals da
LEFT JOIN LATERAL (
  SELECT
    (CASE
      WHEN da.date = CURRENT_DATE THEN
        CASE WHEN da.measurement_count >= 2 THEN da.last_thermal_energy_kwh END
      WHEN da.next_date = da.date + 1 THEN da.next_thermal_energy_kwh
    END - da.first_thermal_energy_kwh) AS thermal_energy_kwh,
    (CASE
      WHEN da.date = CURRENT_DATE THEN
        CASE WHEN da.measurement_count >= 2 THEN da.last_electrical_energy_kwh END
      WHEN da.next_date = da.date + 1 THEN da.next_electrical_energy_kwh
    END - da.first_electrical_energy_kwh) AS electrical_energy_kwh,
    (CASE
      WHEN da.date = CURRENT_DATE THEN
        CASE WHEN da.measurement_count >= 2 THEN da.last_thermal_energy_heating_kwh END
      WHEN da.next_date = da.date + 1 THEN da.next_thermal_energy_heating_kwh
    END - da.first_thermal_energy_heating_kwh) AS thermal_energy_heating_kwh,
    (CASE
      WHEN da.date = CURRENT_DATE THEN
        CASE WHEN da.measurement_count >= 2 THEN da.last_electrical_energy_heating_kwh END
      WHEN da.next_date = da.date + 1 THEN da.next_electrical_energy_heating_kwh
    END - da.first_electrical_energy_heating_kwh) AS electrical_energy_heating_kwh
) calc ON true
LEFT JOIN public.heating_systems hs ON da.heating_id = hs.heating_id
ORDER BY da.date DESC, hs.name;



CREATE OR REPLACE VIEW public.daily_values_view WITH (security_invoker = true) AS
WITH daily_aggregates AS (
  SELECT
    DATE(m.created_at) as date,
    m.heating_id,
    m.user_id,

    -- Keep one first and last counter reading per calendar day.
    (ARRAY_AGG(m.thermal_energy_kwh ORDER BY m.created_at ASC, m.id ASC))[1] as first_thermal_energy_kwh,
    (ARRAY_AGG(m.thermal_energy_kwh ORDER BY m.created_at DESC, m.id DESC))[1] as last_thermal_energy_kwh,

    (ARRAY_AGG(m.electrical_energy_kwh ORDER BY m.created_at ASC, m.id ASC))[1] as first_electrical_energy_kwh,
    (ARRAY_AGG(m.electrical_energy_kwh ORDER BY m.created_at DESC, m.id DESC))[1] as last_electrical_energy_kwh,

    (ARRAY_AGG(m.thermal_energy_heating_kwh ORDER BY m.created_at ASC, m.id ASC))[1] as first_thermal_energy_heating_kwh,
    (ARRAY_AGG(m.thermal_energy_heating_kwh ORDER BY m.created_at DESC, m.id DESC))[1] as last_thermal_energy_heating_kwh,

    (ARRAY_AGG(m.electrical_energy_heating_kwh ORDER BY m.created_at ASC, m.id ASC))[1] as first_electrical_energy_heating_kwh,
    (ARRAY_AGG(m.electrical_energy_heating_kwh ORDER BY m.created_at DESC, m.id DESC))[1] as last_electrical_energy_heating_kwh,

    -- Average temperatures
    AVG(m.outdoor_temperature_c) as outdoor_temperature_c,
    AVG(m.flow_temperature_c) as flow_temperature_c,

    -- Two readings are needed for a partial current-day value.
    COUNT(*) as measurement_count

  FROM public.measurements m
  GROUP BY DATE(m.created_at), m.heating_id, m.user_id
), daily_intervals AS (
  SELECT da.*, LEAD(da.date) OVER w AS next_date,
    LEAD(da.first_thermal_energy_kwh) OVER w AS next_thermal_energy_kwh,
    LEAD(da.first_electrical_energy_kwh) OVER w AS next_electrical_energy_kwh,
    LEAD(da.first_thermal_energy_heating_kwh) OVER w AS next_thermal_energy_heating_kwh,
    LEAD(da.first_electrical_energy_heating_kwh) OVER w AS next_electrical_energy_heating_kwh
  FROM daily_aggregates da
  WINDOW w AS (PARTITION BY da.heating_id, da.user_id ORDER BY da.date)
)
SELECT
  da.date,
  da.heating_id,
  da.user_id,
  hs.name,
  hs.heating_type,
  hs.model_idu,
  hs.model_odu,
  hs.country,
  hs.postal_code,
  hs.heating_load_kw,
  hs.heated_area_m2,
  hs.building_construction_year,
  hs.design_outdoor_temp_c,
  hs.building_energy_standard,
  hs.building_type,
  hs.used_for_heating,
  hs.used_for_dhw,
  hs.used_for_cooling,
  hs.sw_idu,
  hs.sw_odu,
  hs.thermometer_offset_k,
  calc.thermal_energy_kwh,
  calc.electrical_energy_kwh,
  calc.thermal_energy_heating_kwh,
  calc.electrical_energy_heating_kwh,

  -- Apply thermometer offset to outdoor temperature
  CASE
    WHEN hs.thermometer_offset_k IS NOT NULL AND da.outdoor_temperature_c IS NOT NULL
    THEN da.outdoor_temperature_c - hs.thermometer_offset_k
    ELSE da.outdoor_temperature_c
  END as outdoor_temperature_c,

  da.flow_temperature_c,

  -- Computed COP values
  CASE
    WHEN calc.electrical_energy_kwh > 0 AND calc.thermal_energy_kwh IS NOT NULL
    THEN calc.thermal_energy_kwh / calc.electrical_energy_kwh
    ELSE NULL
  END as az,

  CASE
    WHEN calc.electrical_energy_heating_kwh > 0 AND calc.thermal_energy_heating_kwh IS NOT NULL
    THEN calc.thermal_energy_heating_kwh / calc.electrical_energy_heating_kwh
    ELSE NULL
  END as az_heating,
  hs.model_family_id

FROM daily_intervals da
LEFT JOIN LATERAL (
  SELECT
    (CASE
      WHEN da.date = CURRENT_DATE THEN
        CASE WHEN da.measurement_count >= 2 THEN da.last_thermal_energy_kwh END
      WHEN da.next_date = da.date + 1 THEN da.next_thermal_energy_kwh
    END - da.first_thermal_energy_kwh) AS thermal_energy_kwh,
    (CASE
      WHEN da.date = CURRENT_DATE THEN
        CASE WHEN da.measurement_count >= 2 THEN da.last_electrical_energy_kwh END
      WHEN da.next_date = da.date + 1 THEN da.next_electrical_energy_kwh
    END - da.first_electrical_energy_kwh) AS electrical_energy_kwh,
    (CASE
      WHEN da.date = CURRENT_DATE THEN
        CASE WHEN da.measurement_count >= 2 THEN da.last_thermal_energy_heating_kwh END
      WHEN da.next_date = da.date + 1 THEN da.next_thermal_energy_heating_kwh
    END - da.first_thermal_energy_heating_kwh) AS thermal_energy_heating_kwh,
    (CASE
      WHEN da.date = CURRENT_DATE THEN
        CASE WHEN da.measurement_count >= 2 THEN da.last_electrical_energy_heating_kwh END
      WHEN da.next_date = da.date + 1 THEN da.next_electrical_energy_heating_kwh
    END - da.first_electrical_energy_heating_kwh) AS electrical_energy_heating_kwh
) calc ON true
LEFT JOIN public.heating_systems hs ON da.heating_id = hs.heating_id
ORDER BY da.date DESC, hs.name;


