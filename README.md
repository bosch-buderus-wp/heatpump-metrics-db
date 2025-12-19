# 🌡️ Heatpump Metrics Database

[![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?logo=supabase&logoColor=white)](https://supabase.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

This repository contains the Supabase schema for the [Heatpump Metrics UI](https://github.com/bosch-buderus-wp/heatpump-metrics-ui). It stores measurement values and characteristics of Bosch/Buderus heat pumps.

---

## 🏗️ Architecture

The database structure is designed for efficient storage of time-series measurements and manual/automated monthly reports.

```
____________         ___________________          ________________
| accounts | ----*-> | heating_systems | -----*-> | measurements |
------------         -------------------          ----------------
      |         _________          |            __________________
      ------1-> | users |          |--------*-> | monthly_values |
                ---------                       ------------------
```

---

## 📊 Data Schema

### Users

`users` table extends `auth.users` and provides API access.

- `user_id` - uuid: ID of the user (references `auth.users.id`)
- `name` - string: Name of the user (optional)
- `api_key` - uuid: API Key for the user (auto-generated)

### Heating Systems

`heating_systems` stores metadata and characteristics of Bosch/Buderus heat pumps.

- `user_id` - uuid: ID of the user --> `auth.users.id`
- `heating_id` - uuid: ID of the heating system
- `name` - string: Name, e.g. "John Doe's home" (optional)
- `country` - string: Country (optional)
- `postal_code` - string: Postal code (optional)
- `heating_load_kw` - float: Heating load in kW (0-100 kW range, optional)
- `heated_area_m2` - integer: heated area in m² (optional)
- `building_construction_year` - integer: Year of building construction (optional)
- `design_outdoor_temp_c` - float: Design outdoor temperature in °C (optional)
- `building_energy_standard` - enum:
  - `unknown`, `passive_house`, `kfw_40_plus`, `kfw_40`, `kfw_55`, `kfw_70`, `kfw_85`, `kfw_100`, `kfw_115`, `kfw_denkmalschutz`, `old_building_unrenovated`, `energetically_renovated`, `nearly_zero_energy_building`, `minergie`
- `building_type` - enum:
  - `single_family_detached`, `semi_detached`, `terraced_mid`, `terraced_end`, `multi_family_small`, `multi_family_large`, `apartment`, `commercial`, `other`
- `notes`- string: Notes like insulation standards, passive house, etc. (optional)
- `used_for_heating` - boolean: System is used for heating (default: true)
- `used_for_dhw` - boolean: System is used for domestic hot water (default: false)
- `used_for_cooling` - boolean: System is used for cooling (default: false)
- `heating_type` - enum: `underfloorheating`, `radiators`, `mixed`
- `model_idu` - enum (Indoor Unit):
  - `CS5800i_E`, `CS5800i_MB`, `CS5800i_M`, `CS6800i_E`, `CS6800i_MB`, `CS6800i_M`, `WLW176i_E`, `WLW176i_TP70`, `WLW176i_TP180`, `WLW186i_E`, `WLW186i_TP70`, `WLW186i_TP180`
- `model_odu` - enum (Outdoor Unit): `4`, `5`, `7`, `10`, `12` [kW]
- `sw_idu`- enum (Software version IDU): `5.27`, `5.35`, `7.10.0`, `9.6.1`, `9.7.0`, `12.11.1`
- `sw_odu`- enum (Software version ODU): `5.27`, `5.35`, `7.10.0`, `9.6.0`, `9.10.0`, `9.12.0`, `9.15.0 `

### Measurements

Hourly data points transmitted via **ems-esp** or alternative means.

- `id` - uuid: ID of the current measurement
- `user_id` - uuid: ID of the user --> `auth.users.id`
- `heating_id` - uuid: ID of the heating system
- `thermal_energy_kwh` - float: Generated thermal energy in kWh (heating and domestic hot water)
- `electrical_energy_kwh` - float: Used electrical energy in kWh (heating and domestic hot water)
- `thermal_energy_heating_kwh` - float: Generated thermal energy for heating in kWh (only heating without domestic hot water)
- `electrical_energy_heating_kwh` - float: Used electrical energy for heating in kWh (only heating without domestic hot water)
- `outdoor_temperature_c` - float: Outdoor temperature in °C
- `flow_temperature_c` - float: Flow temperature in °C

### Monthly Values

Manually inserted or automatically calculated aggregates.

- `id` - uuid: ID of the monthly value
- `user_id` - uuid: ID of the user --> `auth.users.id`
- `heating_id` - uuid: ID of the heating system
- `month` / `year` - integer: Month (1-12) and Year
- `thermal_energy_kwh` / `electrical_energy_kwh` - float: Total energy values
- `thermal_energy_heating_kwh` / `electrical_energy_heating_kwh` - float: Heating-only values
- `outdoor_temperature_c` - float: Average outdoor temperature in °C
- `outdoor_temperature_min_c` / `outdoor_temperature_max_c` - float: Temp range
- `flow_temperature_c` - float: Average flow temperature in °C

---

## 🔐 Security & Access Control

### Authorization Logic

- **`users`**: Protected by RLS—Strictly private (owner-only access).
- **Public Data**: `heating_systems`, `measurements`, `monthly_values`, and `daily_values` are readable by **anyone** to facilitate community comparisons.
- **Write Access**: Strictly limited to the respective system owners via Row Level Security (RLS).

### Ingestion API

The REST API requires a user-level `api_key`. Keys are auto-generated upon account creation via a trigger on `auth.users`.

---

## 🚀 Deployment & Usage

### Initial Setup

```bash
npx supabase login
npx supabase link --project-ref <project-id>
npx supabase db push
npx supabase functions deploy upload-measurement --no-verify-jwt
npx supabase functions deploy delete-account
```

---

## 🔌 Measurement upload

For direct upload from ems-esp, we recommend using our proxy because ems-esp crashes when it connects to the Supabase Edge Functions due to Deno compatibility issues.

**Default Endpoint (e.g. curl):** `https://<project-id>.supabase.co/rest/v1/rpc/upload_measurement`

**ems-esp Endpoint:** `https://heatpump-metrics-proxy.vercel.app/api/proxy`

**Payload Structure:**

```json
{
  "api_key": "<your-api-key>",
  "heating_id": "<your-heating-id>",
  "thermal_energy_kwh": "boiler/nrgtotal",
  "electrical_energy_kwh": "boiler/metertotal",
  "thermal_energy_heating_kwh": "boiler/nrgheat",
  "electrical_energy_heating_kwh": "boiler/meterheat",
  "outdoor_temperature_c": "boiler/outdoortemp",
  "flow_temperature_c": "boiler/curflowtemp"
}
```

---

## ⚙️ Automated Monthly Value Calculation

The system automatically calculates monthly energy consumption and performance metrics from hourly measurements.

### How it works

- **Nightly Job**: Runs at 3:00 AM UTC via `pg_cron`.
- **Current Month**: Updates daily if measurements exist on the 1st day AND within the last 48 hours.
- **Previous Month**: Finalized during days 1-3 of the new month if measurements exist on both 1st and last day.
- **Stale Data Protection**: Removes current month values if no measurements in 48 hours (prevents misleading data if heat pump stops reporting).
- **Manual Override Protection**: Never overwrites user-edited values (marked with `is_manual_override = TRUE`).

### Data Requirements

For automatic calculation, the system requires:

- Measurements on the first day of the month.
- For current month: At least one measurement in the last 48 hours.
- For completed months: Measurements on both first and last day.
- At least 2 non-NULL measurements for energy pairs (Overall COP or Heating COP).

### Calculation Methods

- **Energy values**: `MAX(value) - MIN(value)` (handles monotonically increasing counters).
- **Temperature values**: `AVG()`, `MIN()`, `MAX()` of all measurements in the month.

---

## 📜 License

Distributed under the **MIT License**. See [LICENSE](LICENSE) for more information.

---

## 🔗 Resources

- [Supabase](https://supabase.com/)
- [Supabase CLI](https://supabase.com/docs/guides/local-development/cli/overview)
- [Heatpump Metrics UI](https://github.com/bosch-buderus-wp/heatpump-metrics-ui)
