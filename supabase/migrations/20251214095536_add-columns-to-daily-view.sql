-- Add all columns from heating_systems to daily_values view
-- Drop and recreate to avoid column position conflicts
DROP VIEW IF EXISTS daily_values;

CREATE VIEW daily_values AS
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
    
  FROM measurements m
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
  END as az_heating
  
FROM daily_aggregates da
LEFT JOIN heating_systems hs ON da.heating_id = hs.heating_id
ORDER BY da.date DESC, hs.name;

-- Enable RLS on the view
ALTER VIEW daily_values SET (security_invoker = true);
