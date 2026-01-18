-- Update measurement_deltas view to allow negative deltas
-- Negative deltas are important for tracking defrost cycles
DROP VIEW IF EXISTS measurement_deltas;

CREATE VIEW measurement_deltas AS
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
    
  FROM measurements m
  WINDOW w AS (PARTITION BY m.heating_id ORDER BY m.created_at)
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
  END as az_heating
  
FROM measurements_with_deltas mwd
LEFT JOIN heating_systems hs ON mwd.heating_id = hs.heating_id
ORDER BY mwd.created_at DESC;

-- Enable RLS on the view
ALTER VIEW measurement_deltas SET (security_invoker = true);

-- Note: Since we're using security_invoker = true, the view will automatically
-- respect the RLS policies on the underlying measurements and heating_systems tables
