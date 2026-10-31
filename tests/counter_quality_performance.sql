-- Disposable PostgreSQL 17 test DB, all migrations applied. Fixtures roll back.
-- Roughly 400,000 readings: ensure an API day query stays inside its time budget.
begin;
set local timezone = 'UTC';
insert into auth.users(id) values ('fc000000-0000-0000-0000-000000000001');
insert into public.heating_systems(heating_id,user_id,name,model_idu,model_odu)
select ('fc000000-0000-0000-0000-'||lpad(n::text,12,'0'))::uuid,
'fc000000-0000-0000-0000-000000000001','Performance fixture '||n,'WLW186i_E','7'
from generate_series(100,199) n;
insert into public.measurements(heating_id,user_id,created_at,thermal_energy_kwh,electrical_energy_kwh,
thermal_energy_heating_kwh,electrical_energy_heating_kwh,outdoor_temperature_c,flow_temperature_c)
select hs.heating_id,hs.user_id,'2026-05-01'::timestamptz+h*interval '1 hour',
10000+h*4,2500+h,8000+h*3.6,2000+h*0.9,10,30
from public.heating_systems hs cross join generate_series(0,4020) h
where hs.user_id='fc000000-0000-0000-0000-000000000001';
analyze public.measurements;
analyze public.heating_systems;
-- Match the existing app's public role, date/family filters and row limit.
set local role anon;
set local statement_timeout = '3s';
explain (analyze, buffers, format json)
select * from public.measurement_deltas_view
where model_family_id='cs5800_6800'
  and created_at >= '2026-10-14 22:00+00' and created_at < '2026-10-15 22:00+00'
order by created_at desc limit 1200;
-- History-wide analysis must meet the same API time budget as a single day.
explain (analyze, buffers, format json)
select count(*) from public.sample_daily_values_view_by_outdoor_temperature(
  model_family => 'cs5800_6800', max_rows => 1000, outdoor_temperature_bin_width_k => 2);
-- A date filter must remain within budget when the view needs the following day.
explain (analyze, buffers, format json)
select * from public.daily_values_view
where model_family_id = 'cs5800_6800'
  and date >= '2026-09-01' and date <= '2026-09-30'
order by date desc;
-- Match the first page of the building comparison.
explain (analyze, buffers, format json)
select date, heating_id, heated_area_m2, thermal_energy_heating_kwh, building_energy_standard
from public.daily_values_view
where model_family_id = 'cs5800_6800'
  and date >= '2026-01-01' and date < '2027-01-01'
order by date, heating_id limit 1000;
rollback;
