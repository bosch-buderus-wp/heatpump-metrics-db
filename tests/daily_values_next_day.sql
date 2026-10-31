-- Run after all migrations against a disposable local database. Fixtures roll back.
begin;
set local timezone = 'UTC';

create function pg_temp.assert_true(ok boolean, message text) returns void language plpgsql as $$
begin
  if ok is distinct from true then raise exception 'Assertion failed: %', message; end if;
end $$;

insert into auth.users(id) values ('fb000000-0000-0000-0000-000000000001');
insert into public.heating_systems(heating_id, user_id, name, model_idu, model_odu, thermometer_offset_k)
select ('fb000000-0000-0000-0000-' || lpad(n::text, 12, '0'))::uuid,
  'fb000000-0000-0000-0000-000000000001', 'Daily fixture ' || n, 'WLW186i_E', '7', 2
from generate_series(10, 14) n;

-- One hourly sequence crosses a month boundary; filtering to January must still
-- use the first February counter reading.
insert into public.measurements(heating_id, user_id, created_at, thermal_energy_kwh,
  electrical_energy_kwh, thermal_energy_heating_kwh, electrical_energy_heating_kwh,
  outdoor_temperature_c, flow_temperature_c)
select 'fb000000-0000-0000-0000-000000000010', 'fb000000-0000-0000-0000-000000000001',
  '2020-01-31 00:00+00'::timestamptz + n * interval '1 hour',
  100 + 4*n, 50 + n, 80 + 3*n, 40 + 0.75*n, 8, 30
from generate_series(0, 24) n;

-- A single upload per day is enough; a missing calendar day is not silently bridged.
insert into public.measurements(heating_id, user_id, created_at, thermal_energy_kwh,
  electrical_energy_kwh, thermal_energy_heating_kwh, electrical_energy_heating_kwh,
  outdoor_temperature_c)
values
  ('fb000000-0000-0000-0000-000000000011', 'fb000000-0000-0000-0000-000000000001', '2020-02-10 08:00+00', 10, 5, 10, 5, 8),
  ('fb000000-0000-0000-0000-000000000011', 'fb000000-0000-0000-0000-000000000001', '2020-02-11 08:00+00', 35, 10, 35, 10, 8),
  ('fb000000-0000-0000-0000-000000000011', 'fb000000-0000-0000-0000-000000000001', '2020-02-13 08:00+00', 80, 20, 80, 20, 8),
  -- Negative deltas are retained, including values that may occur during defrosting.
  ('fb000000-0000-0000-0000-000000000011', 'fb000000-0000-0000-0000-000000000001', '2020-02-20 08:00+00', 100, 25, 100, 25, 8),
  ('fb000000-0000-0000-0000-000000000011', 'fb000000-0000-0000-0000-000000000001', '2020-02-21 08:00+00', 90, 30, 90, 30, 8),
  -- A missing counter affects only that counter's delta.
  ('fb000000-0000-0000-0000-000000000012', 'fb000000-0000-0000-0000-000000000001', '2020-03-01 08:00+00', null, 10, null, 10, 8),
  ('fb000000-0000-0000-0000-000000000012', 'fb000000-0000-0000-0000-000000000001', '2020-03-02 08:00+00', 50, 15, 50, 15, 8);

-- Today is a partial day: two readings yield a partial delta; one yields NULL.
insert into public.measurements(heating_id, user_id, created_at, thermal_energy_kwh, electrical_energy_kwh)
values
  ('fb000000-0000-0000-0000-000000000013', 'fb000000-0000-0000-0000-000000000001', current_date::timestamptz + interval '1 hour', 100, 20),
  ('fb000000-0000-0000-0000-000000000013', 'fb000000-0000-0000-0000-000000000001', current_date::timestamptz + interval '2 hours', 110, 22),
  ('fb000000-0000-0000-0000-000000000014', 'fb000000-0000-0000-0000-000000000001', current_date::timestamptz + interval '1 hour', 100, 20);

set local role anon;
select pg_temp.assert_true((
  select thermal_energy_kwh = 96 and electrical_energy_kwh = 24
    and thermal_energy_heating_kwh = 72 and electrical_energy_heating_kwh = 18
    and az = 4 and az_heating = 4
  from public.daily_values_view
  where heating_id = 'fb000000-0000-0000-0000-000000000010'
    and date >= '2020-01-01' and date <= '2020-01-31'
), 'hourly energy and COP include the next month');
select pg_temp.assert_true((
  select outdoor_temperature_c = 6 from public.daily_values_view
  where heating_id = 'fb000000-0000-0000-0000-000000000010' and date = '2020-01-31'
), 'corrected view applies outdoor sensor offset');
select pg_temp.assert_true((
  select outdoor_temperature_c = 8 and thermal_energy_heating_kwh = 72 from public.daily_values
  where heating_id = 'fb000000-0000-0000-0000-000000000010' and date = '2020-01-31'
), 'legacy view keeps uncorrected temperature and the same energy');
select pg_temp.assert_true((
  select thermal_energy_heating_kwh = 25 and electrical_energy_heating_kwh = 5 and az_heating = 5
  from public.daily_values_view where heating_id = 'fb000000-0000-0000-0000-000000000011' and date = '2020-02-10'
), 'one upload per day');
select pg_temp.assert_true(exists (
  select 1 from public.daily_values_view where heating_id = 'fb000000-0000-0000-0000-000000000011'
    and date = '2020-02-11' and thermal_energy_heating_kwh is null and electrical_energy_heating_kwh is null
), 'missing next calendar day yields NULL');
select pg_temp.assert_true((
  select thermal_energy_heating_kwh = -10 from public.daily_values_view
  where heating_id = 'fb000000-0000-0000-0000-000000000011' and date = '2020-02-20'
), 'negative deltas are preserved');
select pg_temp.assert_true(exists (
  select 1 from public.daily_values_view where heating_id = 'fb000000-0000-0000-0000-000000000012'
    and date = '2020-03-01' and thermal_energy_kwh is null and electrical_energy_kwh = 5
), 'NULL counter does not affect other energy channels');
select pg_temp.assert_true((
  select thermal_energy_kwh = 10 and electrical_energy_kwh = 2 and az = 5
  from public.daily_values_view where heating_id = 'fb000000-0000-0000-0000-000000000013' and date = current_date
), 'current day retains partial value');
select pg_temp.assert_true(exists (
  select 1 from public.daily_values_view where heating_id = 'fb000000-0000-0000-0000-000000000014'
    and date = current_date and thermal_energy_kwh is null and electrical_energy_kwh is null
), 'one current-day upload does not become zero consumption');
rollback;
