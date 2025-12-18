-- Create building_type ENUM
CREATE TYPE building_type AS ENUM (
  'single_family_detached',
  'semi_detached',
  'terraced_mid',
  'terraced_end',
  'multi_family_small',
  'multi_family_large',
  'apartment',
  'commercial',
  'other'
);

-- Create building_energy_standard ENUM
CREATE TYPE building_energy_standard AS ENUM (
  'unknown',
  'passive_house',
  'kfw_40_plus',
  'kfw_40',
  'kfw_55',
  'kfw_70',
  'kfw_85',
  'kfw_100',
  'kfw_115',
  'kfw_denkmalschutz',
  'old_building_unrenovated',
  'energetically_renovated',
  'nearly_zero_energy_building',
  'minergie'
);

-- Add building_construction_year column to heating_systems table
ALTER TABLE heating_systems
ADD COLUMN building_construction_year INTEGER CHECK (building_construction_year >= 1800 AND building_construction_year <= 2100);

-- Add design_outdoor_temp_c column to heating_systems table
ALTER TABLE heating_systems
ADD COLUMN design_outdoor_temp_c DOUBLE PRECISION CHECK (design_outdoor_temp_c >= -50 AND design_outdoor_temp_c <= 30);

-- Add building_type column to heating_systems table
ALTER TABLE heating_systems
ADD COLUMN building_type building_type;

-- Add country column to heating_systems table
ALTER TABLE heating_systems
ADD COLUMN country TEXT;

-- Add building_energy_standard column to heating_systems table
ALTER TABLE heating_systems
ADD COLUMN building_energy_standard building_energy_standard;

-- Add usage flags to heating_systems table
ALTER TABLE heating_systems
ADD COLUMN used_for_heating BOOLEAN DEFAULT TRUE;

ALTER TABLE heating_systems
ADD COLUMN used_for_dhw BOOLEAN DEFAULT FALSE;

ALTER TABLE heating_systems
ADD COLUMN used_for_cooling BOOLEAN DEFAULT FALSE;
