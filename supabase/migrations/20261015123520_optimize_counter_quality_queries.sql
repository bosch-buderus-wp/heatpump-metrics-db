-- Keep date/family predicates pushable to the raw readings. Neighbours are
-- bounded index lookups instead of window scans over the complete history.
create index measurements_created_at_idx on public.measurements(created_at);

create or replace view public.measurement_quality_view with (security_invoker = true) as
select m.*,
  case
    when public.is_isolated_counter_outlier(previous.electrical_energy_kwh,
      m.electrical_energy_kwh, following.electrical_energy_kwh,
      extract(epoch from (following.created_at - previous.created_at))::double precision)
      then 'isolated_electrical_counter_outlier'
    when public.is_isolated_counter_outlier(previous.electrical_energy_heating_kwh,
      m.electrical_energy_heating_kwh, following.electrical_energy_heating_kwh,
      extract(epoch from (following.created_at - previous.created_at))::double precision)
      then 'isolated_heating_electrical_counter_outlier'
  end as calculation_exclusion_reason
from public.measurements m
left join lateral (
  select p.created_at, p.electrical_energy_kwh, p.electrical_energy_heating_kwh
  from public.measurements p
  where p.heating_id = m.heating_id and (p.created_at, p.id) < (m.created_at, m.id)
  order by p.created_at desc, p.id desc limit 1
) previous on true
left join lateral (
  select n.created_at, n.electrical_energy_kwh, n.electrical_energy_heating_kwh
  from public.measurements n
  where n.heating_id = m.heating_id and (n.created_at, n.id) > (m.created_at, m.id)
  order by n.created_at, n.id limit 1
) following on true;

create or replace view public.measurement_deltas_view with (security_invoker = true) as
with measurements_with_deltas as (
  select m.id, m.heating_id, m.user_id, m.created_at,
    m.outdoor_temperature_c, m.flow_temperature_c,
    case when m.calculation_exclusion_reason is null
      then m.thermal_energy_kwh - previous.thermal_energy_kwh end as thermal_energy_kwh_delta,
    case when m.calculation_exclusion_reason is null
      then m.electrical_energy_kwh - previous.electrical_energy_kwh end as electrical_energy_kwh_delta,
    case when m.calculation_exclusion_reason is null
      then m.thermal_energy_heating_kwh - previous.thermal_energy_heating_kwh end as thermal_energy_heating_kwh_delta,
    case when m.calculation_exclusion_reason is null
      then m.electrical_energy_heating_kwh - previous.electrical_energy_heating_kwh end as electrical_energy_heating_kwh_delta,
    m.calculation_exclusion_reason
  from public.measurement_quality_view m
  left join lateral (
    select p.thermal_energy_kwh, p.electrical_energy_kwh,
      p.thermal_energy_heating_kwh, p.electrical_energy_heating_kwh
    from public.valid_measurements_view p
    where m.calculation_exclusion_reason is null and p.heating_id = m.heating_id
      and (p.created_at, p.id) < (m.created_at, m.id)
    order by p.created_at desc, p.id desc limit 1
  ) previous on true
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
  mwd.calculation_exclusion_reason

FROM measurements_with_deltas mwd
LEFT JOIN heating_systems hs ON mwd.heating_id = hs.heating_id
ORDER BY mwd.created_at DESC;



-- The API roles plan the same bounded lookups and retain existing RLS policies.
analyze public.measurements;
