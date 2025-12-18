-- Create daily_values view
-- This view aggregates hourly measurements into daily values per heating system
-- Computes deltas for energy values and averages for temperatures
CREATE OR REPLACE VIEW daily_values AS
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

-- Note: Since we're using security_invoker = true, the view will automatically
-- respect the RLS policies on the underlying measurements and heating_systems tables
