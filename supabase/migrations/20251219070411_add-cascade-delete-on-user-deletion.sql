-- Add ON DELETE CASCADE to measurements table for user deletion
ALTER TABLE measurements
DROP CONSTRAINT measurements_user_id_fkey,
ADD CONSTRAINT measurements_user_id_fkey 
  FOREIGN KEY (user_id) 
  REFERENCES auth.users(id) 
  ON DELETE CASCADE;

-- Add ON DELETE CASCADE to monthly_values table for user deletion
ALTER TABLE monthly_values
DROP CONSTRAINT monthly_values_user_id_fkey,
ADD CONSTRAINT monthly_values_user_id_fkey 
  FOREIGN KEY (user_id) 
  REFERENCES auth.users(id) 
  ON DELETE CASCADE;
