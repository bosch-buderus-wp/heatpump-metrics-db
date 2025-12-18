-- Create ENUMs
CREATE TYPE heating_type AS ENUM ('underfloorheating', 'radiators', 'mixed');
-- Indoor Unit (IDU): Let's differentiate here also between the 2 brands
CREATE TYPE model_idu AS ENUM (
  'CS5800i_E',
  'CS5800i_MB',
  'CS5800i_M',
  'CS6800i_E',
  'CS6800i_MB',
  'CS6800i_M',
  'WLW176i_E',
  'WLW176i_TP70',
  'WLW176i_T180',
  'WLW186i_E',
  'WLW186i_TP70',
  'WLW186i_T180'
);
-- Outdoor Unit (ODU): We have the brand info in the ODU. Let's just use the power here.
CREATE TYPE model_odu AS ENUM ('4', '5', '7', '10', '12');

-- Software versions of the Indoor Unit (IDU)
CREATE TYPE sw_idu AS ENUM (
  '5.27',
  '5.35',
  '7.10.0',
  '9.6.1',
  '9.7.0',
  '12.11.1'
);
-- Software versions of the Outdoor Unit (ODU)
CREATE TYPE sw_odu AS ENUM (
  '5.27',
  '5.35',
  '7.10.0',
  '9.6.0',
  '9.10.0',
  '9.15.0'
);

-- Create users table (extends auth.users)
-- Every user gets a unique API key
CREATE TABLE users (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT,
  api_key UUID DEFAULT gen_random_uuid() UNIQUE NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create heating_systems table
CREATE TABLE heating_systems (
  heating_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) NOT NULL DEFAULT auth.uid(),
  name TEXT,
  postal_code TEXT,
  heating_load DOUBLE PRECISION,
  heated_area_m2 INTEGER,
  notes TEXT,
  heating_type heating_type,
  model_idu model_idu,
  model_odu model_odu,
  sw_idu sw_idu,
  sw_odu sw_odu,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create measurements table
CREATE TABLE measurements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) NOT NULL DEFAULT auth.uid(),
  heating_id UUID REFERENCES heating_systems(heating_id) NOT NULL,
  thermal_energy_kwh DOUBLE PRECISION,
  electrical_energy_kwh DOUBLE PRECISION,
  thermal_energy_heating_kwh DOUBLE PRECISION,
  electrical_energy_heating_kwh DOUBLE PRECISION,
  outdoor_temperature_c DOUBLE PRECISION,
  flow_temperature_c DOUBLE PRECISION,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- Create monthly_values table
CREATE TABLE monthly_values (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) NOT NULL DEFAULT auth.uid(),
  heating_id UUID REFERENCES heating_systems(heating_id) NOT NULL,
  month INTEGER NOT NULL CHECK (month >= 1 AND month <= 12),
  year INTEGER NOT NULL CHECK (year >= 2025 AND year <= 2050),
  thermal_energy_kwh DOUBLE PRECISION,
  electrical_energy_kwh DOUBLE PRECISION,
  thermal_energy_heating_kwh DOUBLE PRECISION,
  electrical_energy_heating_kwh DOUBLE PRECISION,
  outdoor_temperature_c DOUBLE PRECISION,
  flow_temperature_c DOUBLE PRECISION,
  outdoor_temperature_min_c DOUBLE PRECISION,
  outdoor_temperature_max_c DOUBLE PRECISION,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
  UNIQUE (user_id, heating_id, month, year)
);

-- Enable RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE heating_systems ENABLE ROW LEVEL SECURITY;
ALTER TABLE measurements ENABLE ROW LEVEL SECURITY;
ALTER TABLE monthly_values ENABLE ROW LEVEL SECURITY;

-- Create Policies

-- users
CREATE POLICY "Users can view their own profile" ON users
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can update their own profile" ON users
  FOR UPDATE USING (auth.uid() = user_id);

-- heating_systems
CREATE POLICY "Anyone can view heating systems" ON heating_systems
  FOR SELECT USING (true);

CREATE POLICY "Users can insert their own heating systems" ON heating_systems
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own heating systems" ON heating_systems
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own heating systems" ON heating_systems
  FOR DELETE USING (auth.uid() = user_id);

-- measurements
CREATE POLICY "Anyone can view measurements" ON measurements
  FOR SELECT USING (true);

CREATE POLICY "Users can insert their own measurements" ON measurements
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own measurements" ON measurements
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own measurements" ON measurements
  FOR DELETE USING (auth.uid() = user_id);

-- monthly_values
CREATE POLICY "Anyone can view monthly values" ON monthly_values
  FOR SELECT USING (true);

CREATE POLICY "Users can insert their own monthly values" ON monthly_values
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own monthly values" ON monthly_values
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own monthly values" ON monthly_values
  FOR DELETE USING (auth.uid() = user_id);

-- Function to create a user entry when a new user is created in auth.users
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (user_id)
  VALUES (new.id);
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to call handle_new_user on auth.users insert
CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Create RPC function to upload measurements
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
BEGIN
  -- Look up the user_id associated with the provided API key
  SELECT user_id INTO target_user_id
  FROM users
  WHERE users.api_key = upload_measurement.api_key;

  -- If no user found, raise an error
  IF target_user_id IS NULL THEN
    RAISE EXCEPTION 'Invalid API Key';
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
