-- Add columns to track automatic calculation and manual overrides
ALTER TABLE monthly_values
ADD COLUMN is_manual_override BOOLEAN DEFAULT FALSE,
ADD COLUMN last_auto_calculated_at TIMESTAMP WITH TIME ZONE;

-- Function to calculate monthly values from measurements
-- This is the nightly job that runs at 3 AM - only processes current and previous month
CREATE OR REPLACE FUNCTION calculate_monthly_values()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER -- Runs with elevated privileges to bypass RLS
AS $$
DECLARE
  rec RECORD;
  current_year INTEGER;
  current_month INTEGER;
  previous_year INTEGER;
  previous_month INTEGER;
  calculate_previous BOOLEAN;
BEGIN
  -- Get current year and month
  current_year := EXTRACT(YEAR FROM CURRENT_DATE);
  current_month := EXTRACT(MONTH FROM CURRENT_DATE);
  
  -- Calculate previous month (for finalization in first 3 days of new month)
  calculate_previous := EXTRACT(DAY FROM CURRENT_DATE) <= 3;
  
  IF calculate_previous THEN
    -- Calculate previous month's year and month
    IF current_month = 1 THEN
      previous_year := current_year - 1;
      previous_month := 12;
    ELSE
      previous_year := current_year;
      previous_month := current_month - 1;
    END IF;
  END IF;
  
  -- Loop through all heating systems
  FOR rec IN 
    SELECT DISTINCT heating_id, user_id 
    FROM measurements
  LOOP
    -- Process current month
    PERFORM calculate_monthly_value_for_month(rec.heating_id, rec.user_id, current_year, current_month, TRUE);
    
    -- Process previous month if within first 3 days
    IF calculate_previous THEN
      PERFORM calculate_monthly_value_for_month(rec.heating_id, rec.user_id, previous_year, previous_month, FALSE);
    END IF;
  END LOOP;
END;
$$;

-- Helper function to calculate a specific month's values
-- This can also be called manually for historical data imports
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
    SELECT 1 FROM measurements 
    WHERE heating_id = p_heating_id 
      AND DATE(created_at) = first_day
  ) INTO has_first_day;
  
  IF p_is_current_month THEN
    -- For current month: check for recent measurements (last 48 hours)
    SELECT EXISTS(
      SELECT 1 FROM measurements 
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
      FROM measurements
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
      SELECT 1 FROM measurements 
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
      FROM measurements
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

-- Enable pg_cron extension (requires superuser/admin privileges)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule the function to run daily at 3:00 AM UTC
SELECT cron.schedule('calculate-monthly-values', '0 3 * * *', 'SELECT calculate_monthly_values();');

-- Comment explaining the pg_cron setup
COMMENT ON FUNCTION calculate_monthly_values IS 
'Automatically calculates monthly values from measurements. 
For current month: Requires measurements on first day AND within last 48 hours.
For completed months: Requires measurements on both first AND last day of month.
Never overwrites manually overridden values (is_manual_override = TRUE).
Should be scheduled to run daily at 3:00 AM via pg_cron.';