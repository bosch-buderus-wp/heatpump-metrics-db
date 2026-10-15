-- Raw measurements remain unchanged; exclusion reasons are derived only in views.
-- Electrical counters must not decrease. Only classify an isolated dip/peak when
-- both neighbours agree with a plausible increasing baseline (100 kW upper bound).
-- A sustained reset, a missing neighbour or a gap >24h requires manual review.
create function public.is_isolated_counter_outlier(
  previous_value double precision, current_value double precision,
  next_value double precision, neighbour_seconds double precision
) returns boolean language sql immutable parallel safe
set search_path = pg_catalog
as $$
  select coalesce(
    neighbour_seconds > 0 and neighbour_seconds <= 86400
    and next_value >= previous_value
    and next_value - previous_value <= 1 + 100 * neighbour_seconds / 3600
    and (current_value < previous_value - 1 or current_value > next_value + 1),
    false
  );
$$;

create index measurements_counter_sequence_idx
  on public.measurements(heating_id, created_at, id);

create view public.measurement_quality_view with (security_invoker = true) as
with neighbours as (
  select m.id,
    lag(m.electrical_energy_kwh) over w as previous_total,
    lead(m.electrical_energy_kwh) over w as next_total,
    lag(m.electrical_energy_heating_kwh) over w as previous_heating,
    lead(m.electrical_energy_heating_kwh) over w as next_heating,
    extract(epoch from (lead(m.created_at) over w - lag(m.created_at) over w))::double precision as neighbour_seconds
  from public.measurements m
  window w as (partition by m.heating_id order by m.created_at, m.id)
)
select m.*,
  case
    when public.is_isolated_counter_outlier(n.previous_total, m.electrical_energy_kwh, n.next_total, n.neighbour_seconds)
      then 'isolated_electrical_counter_outlier'
    when public.is_isolated_counter_outlier(n.previous_heating, m.electrical_energy_heating_kwh, n.next_heating, n.neighbour_seconds)
      then 'isolated_heating_electrical_counter_outlier'
  end as calculation_exclusion_reason
from public.measurements m left join neighbours n using (id);

create view public.valid_measurements_view with (security_invoker = true) as
select * from public.measurement_quality_view where calculation_exclusion_reason is null;

grant select on public.measurement_quality_view, public.valid_measurements_view to anon, authenticated, service_role;
grant execute on function public.is_isolated_counter_outlier(double precision, double precision, double precision, double precision)
  to anon, authenticated, service_role;

CREATE OR REPLACE VIEW daily_values WITH (security_invoker = true) AS
WITH daily_aggregates AS (
  SELECT
    DATE(m.created_at) as date,
    m.heating_id,
    m.user_id,

    -- Get first and last measurements of the day for delta calculation
    (ARRAY_AGG(m.thermal_energy_kwh ORDER BY m.created_at DESC))[1] -
    (ARRAY_AGG(m.thermal_energy_kwh ORDER BY m.created_at ASC))[1] as thermal_energy_kwh,

    (ARRAY_AGG(m.electrical_energy_kwh ORDER BY m.created_at DESC))[1] -
    (ARRAY_AGG(m.electrical_energy_kwh ORDER BY m.created_at ASC))[1] as electrical_energy_kwh,

    (ARRAY_AGG(m.thermal_energy_heating_kwh ORDER BY m.created_at DESC))[1] -
    (ARRAY_AGG(m.thermal_energy_heating_kwh ORDER BY m.created_at ASC))[1] as thermal_energy_heating_kwh,

    (ARRAY_AGG(m.electrical_energy_heating_kwh ORDER BY m.created_at DESC))[1] -
    (ARRAY_AGG(m.electrical_energy_heating_kwh ORDER BY m.created_at ASC))[1] as electrical_energy_heating_kwh,

    -- Average temperatures
    AVG(m.outdoor_temperature_c) as outdoor_temperature_c,
    AVG(m.flow_temperature_c) as flow_temperature_c,

    -- Count to filter out days with insufficient data
    COUNT(*) as measurement_count

  FROM public.valid_measurements_view m
  GROUP BY DATE(m.created_at), m.heating_id, m.user_id
  HAVING COUNT(*) >= 2  -- Need at least 2 measurements to calculate delta
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
  da.thermal_energy_kwh,
  da.electrical_energy_kwh,
  da.thermal_energy_heating_kwh,
  da.electrical_energy_heating_kwh,
  da.outdoor_temperature_c,
  da.flow_temperature_c,

  -- Computed COP values
  CASE
    WHEN da.electrical_energy_kwh > 0 AND da.thermal_energy_kwh IS NOT NULL
    THEN da.thermal_energy_kwh / da.electrical_energy_kwh
    ELSE NULL
  END as az,

  CASE
    WHEN da.electrical_energy_heating_kwh > 0 AND da.thermal_energy_heating_kwh IS NOT NULL
    THEN da.thermal_energy_heating_kwh / da.electrical_energy_heating_kwh
    ELSE NULL
  END as az_heating,
  hs.model_family_id

FROM daily_aggregates da
LEFT JOIN heating_systems hs ON da.heating_id = hs.heating_id
ORDER BY da.date DESC, hs.name;


CREATE OR REPLACE VIEW daily_values_view WITH (security_invoker = true) AS
WITH daily_aggregates AS (
  SELECT
    DATE(m.created_at) as date,
    m.heating_id,
    m.user_id,

    -- Get first and last measurements of the day for delta calculation
    (ARRAY_AGG(m.thermal_energy_kwh ORDER BY m.created_at DESC))[1] -
    (ARRAY_AGG(m.thermal_energy_kwh ORDER BY m.created_at ASC))[1] as thermal_energy_kwh,

    (ARRAY_AGG(m.electrical_energy_kwh ORDER BY m.created_at DESC))[1] -
    (ARRAY_AGG(m.electrical_energy_kwh ORDER BY m.created_at ASC))[1] as electrical_energy_kwh,

    (ARRAY_AGG(m.thermal_energy_heating_kwh ORDER BY m.created_at DESC))[1] -
    (ARRAY_AGG(m.thermal_energy_heating_kwh ORDER BY m.created_at ASC))[1] as thermal_energy_heating_kwh,

    (ARRAY_AGG(m.electrical_energy_heating_kwh ORDER BY m.created_at DESC))[1] -
    (ARRAY_AGG(m.electrical_energy_heating_kwh ORDER BY m.created_at ASC))[1] as electrical_energy_heating_kwh,

    -- Average temperatures
    AVG(m.outdoor_temperature_c) as outdoor_temperature_c,
    AVG(m.flow_temperature_c) as flow_temperature_c,

    -- Count to filter out days with insufficient data
    COUNT(*) as measurement_count

  FROM public.valid_measurements_view m
  GROUP BY DATE(m.created_at), m.heating_id, m.user_id
  HAVING COUNT(*) >= 2  -- Need at least 2 measurements to calculate delta
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
  da.thermal_energy_kwh,
  da.electrical_energy_kwh,
  da.thermal_energy_heating_kwh,
  da.electrical_energy_heating_kwh,

  -- Apply thermometer offset to outdoor temperature
  CASE
    WHEN hs.thermometer_offset_k IS NOT NULL AND da.outdoor_temperature_c IS NOT NULL
    THEN da.outdoor_temperature_c - hs.thermometer_offset_k
    ELSE da.outdoor_temperature_c
  END as outdoor_temperature_c,

  da.flow_temperature_c,

  -- Computed COP values
  CASE
    WHEN da.electrical_energy_kwh > 0 AND da.thermal_energy_kwh IS NOT NULL
    THEN da.thermal_energy_kwh / da.electrical_energy_kwh
    ELSE NULL
  END as az,

  CASE
    WHEN da.electrical_energy_heating_kwh > 0 AND da.thermal_energy_heating_kwh IS NOT NULL
    THEN da.thermal_energy_heating_kwh / da.electrical_energy_heating_kwh
    ELSE NULL
  END as az_heating,
  hs.model_family_id

FROM daily_aggregates da
LEFT JOIN heating_systems hs ON da.heating_id = hs.heating_id
ORDER BY da.date DESC, hs.name;


CREATE OR REPLACE VIEW public.measurement_deltas_view WITH (security_invoker = true) AS
WITH measurements_with_deltas AS (
  SELECT
    m.id,
    m.heating_id,
    m.user_id,
    m.created_at,
    m.thermal_energy_kwh,
    m.electrical_energy_kwh,
    m.thermal_energy_heating_kwh,
    m.electrical_energy_heating_kwh,
    m.outdoor_temperature_c,
    m.flow_temperature_c,

    -- Calculate deltas using LAG window function
    -- Allow negative deltas (important for defrost cycles)
    CASE
      WHEN LAG(m.thermal_energy_kwh) OVER w IS NOT NULL
      THEN m.thermal_energy_kwh - LAG(m.thermal_energy_kwh) OVER w
      ELSE NULL
    END as thermal_energy_kwh_delta,

    CASE
      WHEN LAG(m.electrical_energy_kwh) OVER w IS NOT NULL
      THEN m.electrical_energy_kwh - LAG(m.electrical_energy_kwh) OVER w
      ELSE NULL
    END as electrical_energy_kwh_delta,

    CASE
      WHEN LAG(m.thermal_energy_heating_kwh) OVER w IS NOT NULL
      THEN m.thermal_energy_heating_kwh - LAG(m.thermal_energy_heating_kwh) OVER w
      ELSE NULL
    END as thermal_energy_heating_kwh_delta,

    CASE
      WHEN LAG(m.electrical_energy_heating_kwh) OVER w IS NOT NULL
      THEN m.electrical_energy_heating_kwh - LAG(m.electrical_energy_heating_kwh) OVER w
      ELSE NULL
    END as electrical_energy_heating_kwh_delta

  FROM public.valid_measurements_view m
  WINDOW w AS (PARTITION BY m.heating_id ORDER BY m.created_at, m.id)
  union all
  select m.id, m.heating_id, m.user_id, m.created_at,
    m.thermal_energy_kwh, m.electrical_energy_kwh,
    m.thermal_energy_heating_kwh, m.electrical_energy_heating_kwh,
    m.outdoor_temperature_c, m.flow_temperature_c,
    null::double precision, null::double precision, null::double precision, null::double precision
  from public.measurement_quality_view m
  where m.calculation_exclusion_reason is not null
)
SELECT
  mwd.id,
  mwd.created_at,
  mwd.heating_id,
  mwd.user_id,
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
  mwd.thermal_energy_kwh_delta as thermal_energy_kwh,
  mwd.electrical_energy_kwh_delta as electrical_energy_kwh,
  mwd.thermal_energy_heating_kwh_delta as thermal_energy_heating_kwh,
  mwd.electrical_energy_heating_kwh_delta as electrical_energy_heating_kwh,

  -- Apply thermometer offset to outdoor temperature
  CASE
    WHEN hs.thermometer_offset_k IS NOT NULL AND mwd.outdoor_temperature_c IS NOT NULL
    THEN mwd.outdoor_temperature_c - hs.thermometer_offset_k
    ELSE mwd.outdoor_temperature_c
  END as outdoor_temperature_c,

  mwd.flow_temperature_c,

  -- Computed COP values
  CASE
    WHEN mwd.electrical_energy_kwh_delta > 0 AND mwd.thermal_energy_kwh_delta IS NOT NULL
    THEN mwd.thermal_energy_kwh_delta / mwd.electrical_energy_kwh_delta
    ELSE NULL
  END as az,

  CASE
    WHEN mwd.electrical_energy_heating_kwh_delta > 0 AND mwd.thermal_energy_heating_kwh_delta IS NOT NULL
    THEN mwd.thermal_energy_heating_kwh_delta / mwd.electrical_energy_heating_kwh_delta
    ELSE NULL
  END as az_heating,
  hs.model_family_id,
  quality.calculation_exclusion_reason

FROM measurements_with_deltas mwd
LEFT JOIN heating_systems hs ON mwd.heating_id = hs.heating_id
JOIN public.measurement_quality_view quality ON quality.id = mwd.id
ORDER BY mwd.created_at DESC;


CREATE OR REPLACE FUNCTION calculate_monthly_value_for_month(
  p_heating_id UUID,
  p_user_id UUID,
  p_year INTEGER,
  p_month INTEGER,
  p_is_current_month BOOLEAN DEFAULT FALSE
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  first_day DATE;
  last_day DATE;
  has_first_day BOOLEAN;
  has_last_day BOOLEAN;
  has_recent_measurement BOOLEAN;
  month_start TIMESTAMP WITH TIME ZONE;
  month_end TIMESTAMP WITH TIME ZONE;
BEGIN
  first_day := make_date(p_year, p_month, 1);
  last_day := (DATE_TRUNC('month', first_day) + INTERVAL '1 month' - INTERVAL '1 day')::DATE;

  month_start := DATE_TRUNC('month', first_day);
  month_end := month_start + INTERVAL '1 month';

  -- Check if measurements exist on first day of month
  SELECT EXISTS(
    SELECT 1 FROM public.valid_measurements_view
    WHERE heating_id = p_heating_id
      AND DATE(created_at) = first_day
  ) INTO has_first_day;

  IF p_is_current_month THEN
    -- For current month: check for recent measurements (last 48 hours)
    SELECT EXISTS(
      SELECT 1 FROM public.valid_measurements_view
      WHERE heating_id = p_heating_id
        AND created_at >= CURRENT_TIMESTAMP - INTERVAL '48 hours'
    ) INTO has_recent_measurement;

    -- Only calculate if we have measurements on first day AND recent measurements
    IF has_first_day AND has_recent_measurement THEN
      -- Insert or update monthly value (only if not manually overridden)
      INSERT INTO monthly_values (
        user_id,
        heating_id,
        month,
        year,
        thermal_energy_kwh,
        electrical_energy_kwh,
        thermal_energy_heating_kwh,
        electrical_energy_heating_kwh,
        outdoor_temperature_c,
        flow_temperature_c,
        outdoor_temperature_min_c,
        outdoor_temperature_max_c,
        is_manual_override,
        last_auto_calculated_at
      )
      SELECT
        p_user_id,
        p_heating_id,
        p_month,
        p_year,
        MAX(thermal_energy_kwh) - MIN(thermal_energy_kwh) as thermal_energy_kwh,
        MAX(electrical_energy_kwh) - MIN(electrical_energy_kwh) as electrical_energy_kwh,
        MAX(thermal_energy_heating_kwh) - MIN(thermal_energy_heating_kwh) as thermal_energy_heating_kwh,
        MAX(electrical_energy_heating_kwh) - MIN(electrical_energy_heating_kwh) as electrical_energy_heating_kwh,
        AVG(outdoor_temperature_c) as outdoor_temperature_c,
        AVG(flow_temperature_c) as flow_temperature_c,
        MIN(outdoor_temperature_c) as outdoor_temperature_min_c,
        MAX(outdoor_temperature_c) as outdoor_temperature_max_c,
        FALSE,
        CURRENT_TIMESTAMP
      FROM public.valid_measurements_view
      WHERE heating_id = p_heating_id
        AND created_at >= month_start
        AND created_at < month_end
      HAVING (COUNT(thermal_energy_kwh) >= 2 AND COUNT(electrical_energy_kwh) >= 2)
         OR (COUNT(thermal_energy_heating_kwh) >= 2 AND COUNT(electrical_energy_heating_kwh) >= 2)  -- Need matching pairs for COP calculation

      ON CONFLICT (user_id, heating_id, month, year)
      DO UPDATE SET
        thermal_energy_kwh = EXCLUDED.thermal_energy_kwh,
        electrical_energy_kwh = EXCLUDED.electrical_energy_kwh,
        thermal_energy_heating_kwh = EXCLUDED.thermal_energy_heating_kwh,
        electrical_energy_heating_kwh = EXCLUDED.electrical_energy_heating_kwh,
        outdoor_temperature_c = EXCLUDED.outdoor_temperature_c,
        flow_temperature_c = EXCLUDED.flow_temperature_c,
        outdoor_temperature_min_c = EXCLUDED.outdoor_temperature_min_c,
        outdoor_temperature_max_c = EXCLUDED.outdoor_temperature_max_c,
        last_auto_calculated_at = CURRENT_TIMESTAMP
      WHERE monthly_values.is_manual_override = FALSE;  -- Only update if not manually overridden

    ELSE
      -- No first day or no recent measurements: delete auto-calculated value for current month
      DELETE FROM monthly_values
      WHERE heating_id = p_heating_id
        AND month = p_month
        AND year = p_year
        AND is_manual_override = FALSE;
    END IF;
  ELSE
    -- For completed months: check for measurements on last day
    SELECT EXISTS(
      SELECT 1 FROM public.valid_measurements_view
      WHERE heating_id = p_heating_id
        AND DATE(created_at) = last_day
    ) INTO has_last_day;

    -- Only calculate if we have measurements on both first AND last day
    IF has_first_day AND has_last_day THEN
      -- Insert or update monthly value (only if not manually overridden)
      INSERT INTO monthly_values (
        user_id,
        heating_id,
        month,
        year,
        thermal_energy_kwh,
        electrical_energy_kwh,
        thermal_energy_heating_kwh,
        electrical_energy_heating_kwh,
        outdoor_temperature_c,
        flow_temperature_c,
        outdoor_temperature_min_c,
        outdoor_temperature_max_c,
        is_manual_override,
        last_auto_calculated_at
      )
      SELECT
        p_user_id,
        p_heating_id,
        p_month,
        p_year,
        MAX(thermal_energy_kwh) - MIN(thermal_energy_kwh) as thermal_energy_kwh,
        MAX(electrical_energy_kwh) - MIN(electrical_energy_kwh) as electrical_energy_kwh,
        MAX(thermal_energy_heating_kwh) - MIN(thermal_energy_heating_kwh) as thermal_energy_heating_kwh,
        MAX(electrical_energy_heating_kwh) - MIN(electrical_energy_heating_kwh) as electrical_energy_heating_kwh,
        AVG(outdoor_temperature_c) as outdoor_temperature_c,
        AVG(flow_temperature_c) as flow_temperature_c,
        MIN(outdoor_temperature_c) as outdoor_temperature_min_c,
        MAX(outdoor_temperature_c) as outdoor_temperature_max_c,
        FALSE,
        CURRENT_TIMESTAMP
      FROM public.valid_measurements_view
      WHERE heating_id = p_heating_id
        AND created_at >= month_start
        AND created_at < month_end
      HAVING (COUNT(thermal_energy_kwh) >= 2 AND COUNT(electrical_energy_kwh) >= 2)
         OR (COUNT(thermal_energy_heating_kwh) >= 2 AND COUNT(electrical_energy_heating_kwh) >= 2)  -- Need matching pairs for COP calculation

      ON CONFLICT (user_id, heating_id, month, year)
      DO UPDATE SET
        thermal_energy_kwh = EXCLUDED.thermal_energy_kwh,
        electrical_energy_kwh = EXCLUDED.electrical_energy_kwh,
        thermal_energy_heating_kwh = EXCLUDED.thermal_energy_heating_kwh,
        electrical_energy_heating_kwh = EXCLUDED.electrical_energy_heating_kwh,
        outdoor_temperature_c = EXCLUDED.outdoor_temperature_c,
        flow_temperature_c = EXCLUDED.flow_temperature_c,
        outdoor_temperature_min_c = EXCLUDED.outdoor_temperature_min_c,
        outdoor_temperature_max_c = EXCLUDED.outdoor_temperature_max_c,
        last_auto_calculated_at = CURRENT_TIMESTAMP
      WHERE monthly_values.is_manual_override = FALSE;  -- Only update if not manually overridden
    END IF;
  END IF;
END;
$$;


-- Retain the existing restriction: this maintenance helper is not a public RPC.
revoke execute on function public.calculate_monthly_value_for_month(uuid, uuid, integer, integer, boolean) from public, anon, authenticated;

-- Refresh only existing automatic months containing excluded readings. Historical
-- data and the current month are repaired without touching manual monthly values.
do $$
declare affected record;
begin
  for affected in
    select distinct mv.heating_id, mv.user_id, mv.year, mv.month
    from public.monthly_values mv
    join public.measurement_quality_view q on q.heating_id = mv.heating_id
      and q.created_at >= make_date(mv.year, mv.month, 1)::timestamptz
      and q.created_at < (make_date(mv.year, mv.month, 1) + interval '1 month')::timestamptz
    where mv.is_manual_override = false and q.calculation_exclusion_reason is not null
      and make_date(mv.year, mv.month, 1) <= date_trunc('month', current_date)::date
  loop
    perform public.calculate_monthly_value_for_month(affected.heating_id, affected.user_id,
      affected.year, affected.month,
      make_date(affected.year, affected.month, 1) = date_trunc('month', current_date)::date);
  end loop;
end;
$$;
