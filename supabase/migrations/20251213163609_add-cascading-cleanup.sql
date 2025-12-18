-- Add ON DELETE CASCADE to heating_systems for user deletion
ALTER TABLE heating_systems
DROP CONSTRAINT heating_systems_user_id_fkey,
ADD CONSTRAINT heating_systems_user_id_fkey 
  FOREIGN KEY (user_id) 
  REFERENCES auth.users(id) 
  ON DELETE CASCADE;

-- Add ON DELETE CASCADE to measurements table
ALTER TABLE measurements
DROP CONSTRAINT measurements_heating_id_fkey,
ADD CONSTRAINT measurements_heating_id_fkey 
  FOREIGN KEY (heating_id) 
  REFERENCES heating_systems(heating_id) 
  ON DELETE CASCADE;

-- Add ON DELETE CASCADE to monthly_values table
ALTER TABLE monthly_values
DROP CONSTRAINT monthly_values_heating_id_fkey,
ADD CONSTRAINT monthly_values_heating_id_fkey 
  FOREIGN KEY (heating_id) 
  REFERENCES heating_systems(heating_id) 
  ON DELETE CASCADE;
