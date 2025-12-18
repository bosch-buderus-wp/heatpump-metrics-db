-- Rename heating_load to heating_load_kw to clarify the unit
ALTER TABLE heating_systems 
RENAME COLUMN heating_load TO heating_load_kw;

-- Add plausibility check constraint
-- Heating load typically ranges from 0-100 kW:
-- - Passive houses: 3-6 kW (very low)
-- - Average homes: 8-15 kW
-- - Larger homes: 15-30 kW
-- - Multi-family buildings: 20-300 kW
ALTER TABLE heating_systems
ADD CONSTRAINT heating_load_kw_check 
CHECK (heating_load_kw >= 0 AND heating_load_kw <= 300);
