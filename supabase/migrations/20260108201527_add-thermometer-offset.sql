-- Add thermometer_offset_k column to heating_systems table
-- This column stores the calibration offset for outdoor temperature sensors.
-- Positive values indicate the thermometer reads too high (e.g., +2.5 K means the sensor shows 2.5 K higher than actual).
-- Negative values indicate the thermometer reads too low.
-- Using Kelvin as unit since temperature differences are equivalent in K and °C (ΔT in K = ΔT in °C).
ALTER TABLE heating_systems
ADD COLUMN thermometer_offset_k DOUBLE PRECISION DEFAULT 0 CHECK (thermometer_offset_k >= -20 AND thermometer_offset_k <= 20);

COMMENT ON COLUMN heating_systems.thermometer_offset_k IS 'Calibration offset for outdoor temperature sensor in Kelvin. Positive values mean the thermometer reads too high. Range: -20 to +20 K.';
