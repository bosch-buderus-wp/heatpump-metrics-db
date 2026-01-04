-- Add validation to upload_measurement to ensure heating_id belongs to the authenticated user
CREATE OR REPLACE FUNCTION upload_measurement(
  api_key UUID,
  heating_id UUID,
  thermal_energy_kwh DOUBLE PRECISION DEFAULT NULL,
  electrical_energy_kwh DOUBLE PRECISION DEFAULT NULL,
  thermal_energy_heating_kwh DOUBLE PRECISION DEFAULT NULL,
  electrical_energy_heating_kwh DOUBLE PRECISION DEFAULT NULL,
  outdoor_temperature_c DOUBLE PRECISION DEFAULT NULL,
  flow_temperature_c DOUBLE PRECISION DEFAULT NULL
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER -- Runs with privileges of the creator (admin) to bypass RLS
AS $$
DECLARE
  target_user_id UUID;
  new_measurement_id UUID;
  heating_id_check UUID;
BEGIN
  -- Look up the user_id associated with the provided API key
  SELECT user_id INTO target_user_id
  FROM users
  WHERE users.api_key = upload_measurement.api_key;

  -- If no user found, raise an error
  IF target_user_id IS NULL THEN
    RAISE EXCEPTION 'Invalid API Key';
  END IF;

  -- Verify that the heating_id belongs to the authenticated user
  SELECT heating_systems.heating_id INTO heating_id_check
  FROM heating_systems
  WHERE heating_systems.heating_id = upload_measurement.heating_id
    AND heating_systems.user_id = target_user_id;

  -- If heating system not found or doesn't belong to user, raise an error
  IF heating_id_check IS NULL THEN
    RAISE EXCEPTION 'Heating system not found or does not belong to user';
  END IF;

  -- Insert the measurement
  INSERT INTO measurements (
    user_id,
    heating_id,
    thermal_energy_kwh,
    electrical_energy_kwh,
    thermal_energy_heating_kwh,
    electrical_energy_heating_kwh,
    outdoor_temperature_c,
    flow_temperature_c
  ) VALUES (
    target_user_id,
    heating_id,
    thermal_energy_kwh,
    electrical_energy_kwh,
    thermal_energy_heating_kwh,
    electrical_energy_heating_kwh,
    outdoor_temperature_c,
    flow_temperature_c
  ) RETURNING id INTO new_measurement_id;

  -- Return success response
  RETURN json_build_object(
    'success', true,
    'measurement_id', new_measurement_id
  );
END;
$$;
