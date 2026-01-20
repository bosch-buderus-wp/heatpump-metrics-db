-- Create monthly_values_view
-- This view presents monthly_values with all heating_systems metadata and computed COP values
-- Similar structure to daily_values and measurement_deltas views
CREATE OR REPLACE VIEW monthly_values_view AS
SELECT 
  mv.id,
  mv.year,
  mv.month,
  mv.heating_id,
  mv.user_id,
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
  mv.thermal_energy_kwh,
  mv.electrical_energy_kwh,
  mv.thermal_energy_heating_kwh,
  mv.electrical_energy_heating_kwh,
  
  -- Apply thermometer offset to outdoor temperatures
  CASE 
    WHEN hs.thermometer_offset_k IS NOT NULL AND mv.outdoor_temperature_c IS NOT NULL
    THEN mv.outdoor_temperature_c - hs.thermometer_offset_k
    ELSE mv.outdoor_temperature_c
  END as outdoor_temperature_c,
  
  CASE 
    WHEN hs.thermometer_offset_k IS NOT NULL AND mv.outdoor_temperature_min_c IS NOT NULL
    THEN mv.outdoor_temperature_min_c - hs.thermometer_offset_k
    ELSE mv.outdoor_temperature_min_c
  END as outdoor_temperature_min_c,
  
  CASE 
    WHEN hs.thermometer_offset_k IS NOT NULL AND mv.outdoor_temperature_max_c IS NOT NULL
    THEN mv.outdoor_temperature_max_c - hs.thermometer_offset_k
    ELSE mv.outdoor_temperature_max_c
  END as outdoor_temperature_max_c,
  
  mv.flow_temperature_c,
  
  -- Computed COP values
  CASE 
    WHEN mv.electrical_energy_kwh > 0 AND mv.thermal_energy_kwh IS NOT NULL 
    THEN mv.thermal_energy_kwh / mv.electrical_energy_kwh
    ELSE NULL
  END as az,
  
  CASE 
    WHEN mv.electrical_energy_heating_kwh > 0 AND mv.thermal_energy_heating_kwh IS NOT NULL 
    THEN mv.thermal_energy_heating_kwh / mv.electrical_energy_heating_kwh
    ELSE NULL
  END as az_heating,
  
  mv.is_manual_override,
  mv.last_auto_calculated_at,
  mv.created_at
  
FROM monthly_values mv
LEFT JOIN heating_systems hs ON mv.heating_id = hs.heating_id
ORDER BY mv.year DESC, mv.month DESC, hs.name;

-- Enable RLS on the view
ALTER VIEW monthly_values_view SET (security_invoker = true);

-- Note: Since we're using security_invoker = true, the view will automatically
-- respect the RLS policies on the underlying monthly_values and heating_systems tables
