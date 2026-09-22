-- Families and valid device combinations are the single source of truth for configuration.
create table public.model_families (
  id text primary key,
  label text not null,
  sort_order integer not null unique
);
create table public.model_combinations (
  model_family_id text not null references public.model_families(id),
  model_idu public.model_idu not null,
  model_odu public.model_odu not null,
  idu_label text not null,
  primary key (model_family_id, model_idu, model_odu)
);
alter table public.model_families enable row level security;
alter table public.model_combinations enable row level security;
create policy "Read model families" on public.model_families for select to anon, authenticated using (true);
create policy "Read model combinations" on public.model_combinations for select to anon, authenticated using (true);
grant select on public.model_families, public.model_combinations to anon, authenticated;
revoke insert, update, delete, truncate, references, trigger on public.model_families, public.model_combinations from anon, authenticated;
insert into public.model_families (id, label, sort_order) values
('cs5800_6800', 'CS5800i / CS6800i / WLW176i / WLW186i MB', 0),
('cs3800', 'CS3800i / WLW166i MBB', 1),
('cs8800', 'CS8800i / WLW186i MBE+', 2),
('cs7001', 'CS7001i / WLW196i', 3),
('cs7400', 'CS7400i / WLW196i S+', 4);
insert into public.model_combinations (model_family_id, model_idu, model_odu, idu_label) values
('cs5800_6800', 'CS5800i_E', '4', 'CS5800i E'),
('cs5800_6800', 'CS5800i_E', '5', 'CS5800i E'),
('cs5800_6800', 'CS5800i_E', '7', 'CS5800i E'),
('cs5800_6800', 'CS5800i_E', '10', 'CS5800i E'),
('cs5800_6800', 'CS5800i_E', '12', 'CS5800i E'),
('cs5800_6800', 'CS5800i_MB', '4', 'CS5800i MB'),
('cs5800_6800', 'CS5800i_MB', '5', 'CS5800i MB'),
('cs5800_6800', 'CS5800i_MB', '7', 'CS5800i MB'),
('cs5800_6800', 'CS5800i_MB', '10', 'CS5800i MB'),
('cs5800_6800', 'CS5800i_MB', '12', 'CS5800i MB'),
('cs5800_6800', 'CS5800i_M', '4', 'CS5800i M'),
('cs5800_6800', 'CS5800i_M', '5', 'CS5800i M'),
('cs5800_6800', 'CS5800i_M', '7', 'CS5800i M'),
('cs5800_6800', 'CS5800i_M', '10', 'CS5800i M'),
('cs5800_6800', 'CS5800i_M', '12', 'CS5800i M'),
('cs5800_6800', 'CS6800i_E', '4', 'CS6800i E'),
('cs5800_6800', 'CS6800i_E', '5', 'CS6800i E'),
('cs5800_6800', 'CS6800i_E', '7', 'CS6800i E'),
('cs5800_6800', 'CS6800i_E', '10', 'CS6800i E'),
('cs5800_6800', 'CS6800i_E', '12', 'CS6800i E'),
('cs5800_6800', 'CS6800i_MB', '4', 'CS6800i MB'),
('cs5800_6800', 'CS6800i_MB', '5', 'CS6800i MB'),
('cs5800_6800', 'CS6800i_MB', '7', 'CS6800i MB'),
('cs5800_6800', 'CS6800i_MB', '10', 'CS6800i MB'),
('cs5800_6800', 'CS6800i_MB', '12', 'CS6800i MB'),
('cs5800_6800', 'CS6800i_M', '4', 'CS6800i M'),
('cs5800_6800', 'CS6800i_M', '5', 'CS6800i M'),
('cs5800_6800', 'CS6800i_M', '7', 'CS6800i M'),
('cs5800_6800', 'CS6800i_M', '10', 'CS6800i M'),
('cs5800_6800', 'CS6800i_M', '12', 'CS6800i M'),
('cs5800_6800', 'WLW176i_E', '4', 'WLW176i E'),
('cs5800_6800', 'WLW176i_E', '5', 'WLW176i E'),
('cs5800_6800', 'WLW176i_E', '7', 'WLW176i E'),
('cs5800_6800', 'WLW176i_E', '10', 'WLW176i E'),
('cs5800_6800', 'WLW176i_E', '12', 'WLW176i E'),
('cs5800_6800', 'WLW176i_TP70', '4', 'WLW176i TP70'),
('cs5800_6800', 'WLW176i_TP70', '5', 'WLW176i TP70'),
('cs5800_6800', 'WLW176i_TP70', '7', 'WLW176i TP70'),
('cs5800_6800', 'WLW176i_TP70', '10', 'WLW176i TP70'),
('cs5800_6800', 'WLW176i_TP70', '12', 'WLW176i TP70'),
('cs5800_6800', 'WLW176i_T180', '4', 'WLW176i T180'),
('cs5800_6800', 'WLW176i_T180', '5', 'WLW176i T180'),
('cs5800_6800', 'WLW176i_T180', '7', 'WLW176i T180'),
('cs5800_6800', 'WLW176i_T180', '10', 'WLW176i T180'),
('cs5800_6800', 'WLW176i_T180', '12', 'WLW176i T180'),
('cs5800_6800', 'WLW186i_E', '4', 'WLW186i E'),
('cs5800_6800', 'WLW186i_E', '5', 'WLW186i E'),
('cs5800_6800', 'WLW186i_E', '7', 'WLW186i E'),
('cs5800_6800', 'WLW186i_E', '10', 'WLW186i E'),
('cs5800_6800', 'WLW186i_E', '12', 'WLW186i E'),
('cs5800_6800', 'WLW186i_TP70', '4', 'WLW186i TP70'),
('cs5800_6800', 'WLW186i_TP70', '5', 'WLW186i TP70'),
('cs5800_6800', 'WLW186i_TP70', '7', 'WLW186i TP70'),
('cs5800_6800', 'WLW186i_TP70', '10', 'WLW186i TP70'),
('cs5800_6800', 'WLW186i_TP70', '12', 'WLW186i TP70'),
('cs5800_6800', 'WLW186i_T180', '4', 'WLW186i T180'),
('cs5800_6800', 'WLW186i_T180', '5', 'WLW186i T180'),
('cs5800_6800', 'WLW186i_T180', '7', 'WLW186i T180'),
('cs5800_6800', 'WLW186i_T180', '10', 'WLW186i T180'),
('cs5800_6800', 'WLW186i_T180', '12', 'WLW186i T180'),
('cs3800', 'CS3800i_AWEi', '4', 'CS3800i AWEi'),
('cs3800', 'CS3800i_AWEi', '6', 'CS3800i AWEi'),
('cs3800', 'CS3800i_AWEi', '7', 'CS3800i AWEi'),
('cs3800', 'CS3800i_AWEi', '10', 'CS3800i AWEi'),
('cs3800', 'CS3800i_AWEi', '13', 'CS3800i AWEi'),
('cs3800', 'CS3800i_AWMi', '4', 'CS3800i AWMi'),
('cs3800', 'CS3800i_AWMi', '6', 'CS3800i AWMi'),
('cs3800', 'CS3800i_AWMi', '7', 'CS3800i AWMi'),
('cs3800', 'CS3800i_AWMi', '10', 'CS3800i AWMi'),
('cs3800', 'CS3800i_AWMi', '13', 'CS3800i AWMi'),
('cs3800', 'CS3800i_AWMHi', '4', 'CS3800i AWMHi'),
('cs3800', 'CS3800i_AWMHi', '6', 'CS3800i AWMHi'),
('cs3800', 'CS3800i_AWMHi', '7', 'CS3800i AWMHi'),
('cs3800', 'CS3800i_AWMHi', '10', 'CS3800i AWMHi'),
('cs3800', 'CS3800i_AWMHi', '13', 'CS3800i AWMHi'),
('cs3800', 'WLW166i_MBB_E', '4', 'WLW166i MBB E'),
('cs3800', 'WLW166i_MBB_E', '6', 'WLW166i MBB E'),
('cs3800', 'WLW166i_MBB_E', '7', 'WLW166i MBB E'),
('cs3800', 'WLW166i_MBB_E', '10', 'WLW166i MBB E'),
('cs3800', 'WLW166i_MBB_E', '13', 'WLW166i MBB E'),
('cs3800', 'WLW166i_MBB_T180', '4', 'WLW166i MBB T180'),
('cs3800', 'WLW166i_MBB_T180', '6', 'WLW166i MBB T180'),
('cs3800', 'WLW166i_MBB_T180', '7', 'WLW166i MBB T180'),
('cs3800', 'WLW166i_MBB_T180', '10', 'WLW166i MBB T180'),
('cs3800', 'WLW166i_MBB_T180', '13', 'WLW166i MBB T180'),
('cs3800', 'WLW166i_MBB_T180_HK', '4', 'WLW166i MBB T180 HK'),
('cs3800', 'WLW166i_MBB_T180_HK', '6', 'WLW166i MBB T180 HK'),
('cs3800', 'WLW166i_MBB_T180_HK', '7', 'WLW166i MBB T180 HK'),
('cs3800', 'WLW166i_MBB_T180_HK', '10', 'WLW166i MBB T180 HK'),
('cs3800', 'WLW166i_MBB_T180_HK', '13', 'WLW166i MBB T180 HK'),
('cs8800', 'CS8800i_AWEi_D', '11', 'CS8800i AWEi D'),
('cs8800', 'CS8800i_AWEi_D', '13', 'CS8800i AWEi D'),
('cs8800', 'CS8800i_AWEi_D', '15', 'CS8800i AWEi D'),
('cs8800', 'CS8800i_AWMBi_D', '11', 'CS8800i AWMBi D'),
('cs8800', 'CS8800i_AWMBi_D', '13', 'CS8800i AWMBi D'),
('cs8800', 'CS8800i_AWMBi_D', '15', 'CS8800i AWMBi D'),
('cs8800', 'WLW186i_MBE_PLUS_E', '11', 'WLW186i MBE+ E'),
('cs8800', 'WLW186i_MBE_PLUS_E', '13', 'WLW186i MBE+ E'),
('cs8800', 'WLW186i_MBE_PLUS_E', '15', 'WLW186i MBE+ E'),
('cs8800', 'WLW186i_MBE_PLUS_TP70', '11', 'WLW186i MBE+ TP70'),
('cs8800', 'WLW186i_MBE_PLUS_TP70', '13', 'WLW186i MBE+ TP70'),
('cs8800', 'WLW186i_MBE_PLUS_TP70', '15', 'WLW186i MBE+ TP70'),
('cs7001', 'CS7001i_AWE', '5', 'CS7001i AWE'),
('cs7001', 'CS7001i_AWE', '7', 'CS7001i AWE'),
('cs7001', 'CS7001i_AWE', '9', 'CS7001i AWE'),
('cs7001', 'CS7001i_AWE', '13', 'CS7001i AWE'),
('cs7001', 'CS7001i_AWE', '17', 'CS7001i AWE'),
('cs7001', 'CS7001i_AWB', '5', 'CS7001i AWB'),
('cs7001', 'CS7001i_AWB', '7', 'CS7001i AWB'),
('cs7001', 'CS7001i_AWB', '9', 'CS7001i AWB'),
('cs7001', 'CS7001i_AWB', '13', 'CS7001i AWB'),
('cs7001', 'CS7001i_AWB', '17', 'CS7001i AWB'),
('cs7001', 'CS7001i_AWMB', '5', 'CS7001i AWMB'),
('cs7001', 'CS7001i_AWMB', '7', 'CS7001i AWMB'),
('cs7001', 'CS7001i_AWMB', '9', 'CS7001i AWMB'),
('cs7001', 'CS7001i_AWMB', '13', 'CS7001i AWMB'),
('cs7001', 'CS7001i_AWMB', '17', 'CS7001i AWMB'),
('cs7001', 'CS7001i_AWM', '5', 'CS7001i AWM'),
('cs7001', 'CS7001i_AWM', '7', 'CS7001i AWM'),
('cs7001', 'CS7001i_AWM', '9', 'CS7001i AWM'),
('cs7001', 'CS7001i_AWM', '13', 'CS7001i AWM'),
('cs7001', 'CS7001i_AWM', '17', 'CS7001i AWM'),
('cs7001', 'CS7001i_AWMS', '5', 'CS7001i AWMS'),
('cs7001', 'CS7001i_AWMS', '7', 'CS7001i AWMS'),
('cs7001', 'CS7001i_AWMS', '9', 'CS7001i AWMS'),
('cs7001', 'CS7001i_AWMS', '13', 'CS7001i AWMS'),
('cs7001', 'CS7001i_AWMS', '17', 'CS7001i AWMS'),
('cs7001', 'WLW196i_E', '4', 'WLW196i E'),
('cs7001', 'WLW196i_E', '6', 'WLW196i E'),
('cs7001', 'WLW196i_E', '8', 'WLW196i E'),
('cs7001', 'WLW196i_E', '11', 'WLW196i E'),
('cs7001', 'WLW196i_E', '14', 'WLW196i E'),
('cs7001', 'WLW196i_B', '4', 'WLW196i B'),
('cs7001', 'WLW196i_B', '6', 'WLW196i B'),
('cs7001', 'WLW196i_B', '8', 'WLW196i B'),
('cs7001', 'WLW196i_B', '11', 'WLW196i B'),
('cs7001', 'WLW196i_B', '14', 'WLW196i B'),
('cs7001', 'WLW196i_TP120', '4', 'WLW196i TP120'),
('cs7001', 'WLW196i_TP120', '6', 'WLW196i TP120'),
('cs7001', 'WLW196i_TP120', '8', 'WLW196i TP120'),
('cs7001', 'WLW196i_TP120', '11', 'WLW196i TP120'),
('cs7001', 'WLW196i_TP120', '14', 'WLW196i TP120'),
('cs7001', 'WLW196i_T190', '4', 'WLW196i T190'),
('cs7001', 'WLW196i_T190', '6', 'WLW196i T190'),
('cs7001', 'WLW196i_T190', '8', 'WLW196i T190'),
('cs7001', 'WLW196i_T190', '11', 'WLW196i T190'),
('cs7001', 'WLW196i_T190', '14', 'WLW196i T190'),
('cs7001', 'WLW196i_TS185', '4', 'WLW196i TS185'),
('cs7001', 'WLW196i_TS185', '6', 'WLW196i TS185'),
('cs7001', 'WLW196i_TS185', '8', 'WLW196i TS185'),
('cs7001', 'WLW196i_TS185', '11', 'WLW196i TS185'),
('cs7001', 'WLW196i_TS185', '14', 'WLW196i TS185'),
('cs7400', 'CS7400i_AWE', '5', 'CS7400i AWE'),
('cs7400', 'CS7400i_AWE', '7', 'CS7400i AWE'),
('cs7400', 'CS7400i_AWB', '5', 'CS7400i AWB'),
('cs7400', 'CS7400i_AWB', '7', 'CS7400i AWB'),
('cs7400', 'CS7400i_AWMB', '5', 'CS7400i AWMB'),
('cs7400', 'CS7400i_AWMB', '7', 'CS7400i AWMB'),
('cs7400', 'CS7400i_AWM', '5', 'CS7400i AWM'),
('cs7400', 'CS7400i_AWM', '7', 'CS7400i AWM'),
('cs7400', 'CS7400i_AWMS', '5', 'CS7400i AWMS'),
('cs7400', 'CS7400i_AWMS', '7', 'CS7400i AWMS'),
('cs7400', 'WLW196i_S_PLUS_E', '4', 'WLW196i S+ E'),
('cs7400', 'WLW196i_S_PLUS_E', '6', 'WLW196i S+ E'),
('cs7400', 'WLW196i_S_PLUS_B', '4', 'WLW196i S+ B'),
('cs7400', 'WLW196i_S_PLUS_B', '6', 'WLW196i S+ B'),
('cs7400', 'WLW196i_S_PLUS_TP120', '4', 'WLW196i S+ TP120'),
('cs7400', 'WLW196i_S_PLUS_TP120', '6', 'WLW196i S+ TP120'),
('cs7400', 'WLW196i_S_PLUS_T190', '4', 'WLW196i S+ T190'),
('cs7400', 'WLW196i_S_PLUS_T190', '6', 'WLW196i S+ T190'),
('cs7400', 'WLW196i_S_PLUS_TS185', '4', 'WLW196i S+ TS185'),
('cs7400', 'WLW196i_S_PLUS_TS185', '6', 'WLW196i S+ TS185');

alter table public.heating_systems
  add column model_family_id text not null default 'cs5800_6800' references public.model_families(id),
  add constraint heating_systems_model_combination_fkey
    foreign key (model_family_id, model_idu, model_odu)
    references public.model_combinations(model_family_id, model_idu, model_odu),
  add constraint heating_systems_family_firmware_check
    check (model_family_id = 'cs5800_6800' or (sw_idu is null and sw_odu is null));
create index heating_systems_model_family_idx on public.heating_systems(model_family_id);

-- MATCH SIMPLE permits historical incomplete configurations. Only unchanged historical
-- configurations may remain incomplete; every new or changed selection must be complete.
create function public.validate_heating_system_model() returns trigger
language plpgsql security invoker set search_path = public as $$
begin
  if new.model_idu is null or new.model_odu is null then
    if tg_op = 'UPDATE' then
      if (new.model_family_id, new.model_idu, new.model_odu)
         is not distinct from (old.model_family_id, old.model_idu, old.model_odu) then
        return new;
      end if;
    end if;
    raise exception 'Select a complete model combination' using errcode = '23514';
  end if;
  return new;
end;
$$;
create trigger validate_heating_system_model before insert or update on public.heating_systems
for each row execute function public.validate_heating_system_model();

-- Append metadata without changing existing column positions or aggregation semantics.
do $$
declare view_name text; definition text;
begin
  foreach view_name in array array['daily_values', 'daily_values_view', 'measurement_deltas_view',
                                  'monthly_values_view', 'heating_systems_with_location_view'] loop
    definition := rtrim(pg_get_viewdef(format('public.%I', view_name)::regclass, true), E';\n ');
    execute format('create or replace view public.%I with (security_invoker = true) as
      select original.*, hs.model_family_id from (%s) original
      join public.heating_systems hs on hs.heating_id = original.heating_id', view_name, definition);
  end loop;
end;
$$;

-- Replace the old signature, retaining a default for existing callers.
drop function public.sample_daily_values_view_by_outdoor_temperature(jsonb, integer, numeric, uuid);
create or replace function public.sample_daily_values_view_by_outdoor_temperature(
  filter_model jsonb default '{"logic":"and","items":[]}'::jsonb,
  max_rows integer default 1000,
  outdoor_temperature_bin_width_k numeric default 2,
  current_user_id uuid default null,
  model_family text default 'cs5800_6800'
)
returns table (
  az double precision,
  az_heating double precision,
  building_construction_year integer,
  building_energy_standard public.building_energy_standard,
  building_type public.building_type,
  country text,
  date date,
  design_outdoor_temp_c double precision,
  electrical_energy_heating_kwh double precision,
  electrical_energy_kwh double precision,
  flow_temperature_c double precision,
  heated_area_m2 integer,
  heating_id uuid,
  heating_load_kw double precision,
  heating_type public.heating_type,
  model_idu public.model_idu,
  model_odu public.model_odu,
  name text,
  outdoor_temperature_c double precision,
  postal_code text,
  sw_idu public.sw_idu,
  sw_odu public.sw_odu,
  thermal_energy_heating_kwh double precision,
  thermal_energy_kwh double precision,
  thermometer_offset_k double precision,
  used_for_cooling boolean,
  used_for_dhw boolean,
  used_for_heating boolean,
  user_id uuid
)
language plpgsql
security invoker
set search_path = public
as $$
declare
  safe_max_rows integer := greatest(coalesce(max_rows, 1000), 1);
  safe_bin_width numeric := greatest(coalesce(outdoor_temperature_bin_width_k, 2), 0.1);
  filter_clause text := public.build_daily_values_view_filter_clause(filter_model);
  sql text;
begin
  if model_family is null or not exists (select 1 from public.model_families where id = model_family) then
    raise exception 'Unknown model family' using errcode = '22023';
  end if;
  sql := format($sql$
    with base_rows as (
      select
        az,
        az_heating,
        building_construction_year,
        building_energy_standard,
        building_type,
        country,
        date,
        design_outdoor_temp_c,
        electrical_energy_heating_kwh,
        electrical_energy_kwh,
        flow_temperature_c,
        heated_area_m2,
        heating_id,
        heating_load_kw,
        heating_type,
        model_idu,
        model_odu,
        name,
        outdoor_temperature_c,
        postal_code,
        sw_idu,
        sw_odu,
        thermal_energy_heating_kwh,
        thermal_energy_kwh,
        thermometer_offset_k,
        used_for_cooling,
        used_for_dhw,
        used_for_heating,
        user_id
      from public.daily_values_view
      where model_family_id = %5$L
        and outdoor_temperature_c is not null
        and %1$s
    ),
    counts as (
      select
        count(*)::integer as total_count,
        count(*) filter (
          where %2$L::uuid is not null and user_id = %2$L::uuid
        )::integer as user_count
      from base_rows
    ),
    all_rows_if_small as (
      select *
      from base_rows
      where (select total_count from counts) <= %3$s
    ),
    user_rows as (
      select *
      from base_rows
      where %2$L::uuid is not null and user_id = %2$L::uuid
    ),
    community_rows as (
      select *
      from base_rows
      where %2$L::uuid is null or user_id is distinct from %2$L::uuid
    ),
    budget as (
      select
        total_count,
        user_count,
        least(user_count, %3$s) as reserved_user_rows,
        greatest(%3$s - least(user_count, %3$s), 0) as community_budget
      from counts
    ),
    sample_candidate_rows as (
      select u.*, true as is_user_priority
      from user_rows u
      cross join budget b
      where b.total_count > %3$s
        and b.user_count >= %3$s

      union all

      select c.*, false as is_user_priority
      from community_rows c
      cross join budget b
      where b.total_count > %3$s
        and b.user_count < %3$s
        and b.community_budget > 0
    ),
    sample_budget as (
      select
        case
          when total_count <= %3$s then 0
          when user_count >= %3$s then %3$s
          else community_budget
        end as sample_budget
      from budget
    ),
    binned_rows as (
      select
        r.*,
        floor(r.outdoor_temperature_c / %4$L::numeric)::integer as temp_bin
      from sample_candidate_rows r
    ),
    bin_counts as (
      select
        temp_bin,
        count(*)::integer as bin_count
      from binned_rows
      group by temp_bin
    ),
    ranked_bins as (
      select
        temp_bin,
        bin_count,
        row_number() over (order by temp_bin asc) as bin_rank,
        count(*) over ()::integer as bin_total
      from bin_counts
    ),
    quota_stage_1 as (
      select
        rb.temp_bin,
        rb.bin_count,
        case
          when sb.sample_budget >= rb.bin_total then 1
          when mod(
            rb.bin_rank - 1,
            greatest(ceil(rb.bin_total::numeric / sb.sample_budget::numeric)::integer, 1)
          ) = 0 then 1
          else 0
        end as mandatory_quota
      from ranked_bins rb
      cross join sample_budget sb
    ),
    quota_summary as (
      select
        coalesce(sum(mandatory_quota), 0)::integer as mandatory_total,
        coalesce(sum(bin_count - mandatory_quota), 0)::integer as additional_capacity
      from quota_stage_1
    ),
    quota_stage_2 as (
      select
        q1.temp_bin,
        q1.bin_count,
        q1.mandatory_quota,
        case
          when qs.additional_capacity <= 0 then 0
          else floor(
            greatest(sb.sample_budget - qs.mandatory_total, 0)::numeric
            * greatest(q1.bin_count - q1.mandatory_quota, 0)::numeric
            / qs.additional_capacity::numeric
          )::integer
        end as proportional_quota,
        case
          when qs.additional_capacity <= 0 then 0
          else (
            greatest(sb.sample_budget - qs.mandatory_total, 0)::numeric
            * greatest(q1.bin_count - q1.mandatory_quota, 0)::numeric
            / qs.additional_capacity::numeric
          ) - floor(
            greatest(sb.sample_budget - qs.mandatory_total, 0)::numeric
            * greatest(q1.bin_count - q1.mandatory_quota, 0)::numeric
            / qs.additional_capacity::numeric
          )
        end as proportional_remainder
      from quota_stage_1 q1
      cross join quota_summary qs
      cross join sample_budget sb
    ),
    quota_base as (
      select
        temp_bin,
        bin_count,
        mandatory_quota + least(proportional_quota, greatest(bin_count - mandatory_quota, 0)) as base_quota,
        greatest(bin_count - mandatory_quota - proportional_quota, 0) as remaining_capacity,
        proportional_remainder
      from quota_stage_2
    ),
    leftover as (
      select
        greatest((select sample_budget from sample_budget) - coalesce(sum(base_quota), 0), 0)::integer as leftover_budget
      from quota_base
    ),
    quota_ranked as (
      select
        qb.*,
        row_number() over (
          order by qb.proportional_remainder desc, qb.bin_count asc, qb.temp_bin asc
        ) as remainder_rank
      from quota_base qb
      where qb.remaining_capacity > 0
    ),
    final_quotas as (
      select
        qb.temp_bin,
        least(
          qb.bin_count,
          qb.base_quota + case
            when qr.remainder_rank is not null
             and qr.remainder_rank <= (select leftover_budget from leftover)
            then 1
            else 0
          end
        )::integer as target_quota
      from quota_base qb
      left join quota_ranked qr using (temp_bin)
    ),
    ranked_rows as (
      select
        br.*,
        fq.target_quota,
        row_number() over (
          partition by br.temp_bin
          order by br.date desc, br.heating_id, br.user_id
        ) as rn_in_bin,
        count(*) over (partition by br.temp_bin)::integer as bin_size
      from binned_rows br
      join final_quotas fq using (temp_bin)
      where fq.target_quota > 0
    ),
    bucketed_rows as (
      select
        rr.*,
        least(
          rr.target_quota,
          greatest(
            1,
            ceil(rr.rn_in_bin * rr.target_quota::numeric / rr.bin_size::numeric)::integer
          )
        ) as sample_bucket
      from ranked_rows rr
    ),
    sampled_candidate_rows as (
      select distinct on (temp_bin, sample_bucket)
        az,
        az_heating,
        building_construction_year,
        building_energy_standard,
        building_type,
        country,
        date,
        design_outdoor_temp_c,
        electrical_energy_heating_kwh,
        electrical_energy_kwh,
        flow_temperature_c,
        heated_area_m2,
        heating_id,
        heating_load_kw,
        heating_type,
        model_idu,
        model_odu,
        name,
        outdoor_temperature_c,
        postal_code,
        sw_idu,
        sw_odu,
        thermal_energy_heating_kwh,
        thermal_energy_kwh,
        thermometer_offset_k,
        used_for_cooling,
        used_for_dhw,
        used_for_heating,
        user_id
      from bucketed_rows
      order by temp_bin, sample_bucket, rn_in_bin
    ),
    final_rows as (
      select *
      from all_rows_if_small

      union all

      select
        az,
        az_heating,
        building_construction_year,
        building_energy_standard,
        building_type,
        country,
        date,
        design_outdoor_temp_c,
        electrical_energy_heating_kwh,
        electrical_energy_kwh,
        flow_temperature_c,
        heated_area_m2,
        heating_id,
        heating_load_kw,
        heating_type,
        model_idu,
        model_odu,
        name,
        outdoor_temperature_c,
        postal_code,
        sw_idu,
        sw_odu,
        thermal_energy_heating_kwh,
        thermal_energy_kwh,
        thermometer_offset_k,
        used_for_cooling,
        used_for_dhw,
        used_for_heating,
        user_id
      from sampled_candidate_rows
      cross join budget b
      where b.total_count > %3$s
        and b.user_count >= %3$s

      union all

      select
        az,
        az_heating,
        building_construction_year,
        building_energy_standard,
        building_type,
        country,
        date,
        design_outdoor_temp_c,
        electrical_energy_heating_kwh,
        electrical_energy_kwh,
        flow_temperature_c,
        heated_area_m2,
        heating_id,
        heating_load_kw,
        heating_type,
        model_idu,
        model_odu,
        name,
        outdoor_temperature_c,
        postal_code,
        sw_idu,
        sw_odu,
        thermal_energy_heating_kwh,
        thermal_energy_kwh,
        thermometer_offset_k,
        used_for_cooling,
        used_for_dhw,
        used_for_heating,
        user_id
      from user_rows
      cross join budget b
      where b.total_count > %3$s
        and b.user_count < %3$s

      union all

      select
        az,
        az_heating,
        building_construction_year,
        building_energy_standard,
        building_type,
        country,
        date,
        design_outdoor_temp_c,
        electrical_energy_heating_kwh,
        electrical_energy_kwh,
        flow_temperature_c,
        heated_area_m2,
        heating_id,
        heating_load_kw,
        heating_type,
        model_idu,
        model_odu,
        name,
        outdoor_temperature_c,
        postal_code,
        sw_idu,
        sw_odu,
        thermal_energy_heating_kwh,
        thermal_energy_kwh,
        thermometer_offset_k,
        used_for_cooling,
        used_for_dhw,
        used_for_heating,
        user_id
      from sampled_candidate_rows
      cross join budget b
      where b.total_count > %3$s
        and b.user_count < %3$s
    )
    select *
    from final_rows
    order by date desc, heating_id, user_id
    limit %3$s
  $sql$, filter_clause, current_user_id, safe_max_rows, safe_bin_width, model_family);

  return query execute sql;
end;
$$;

grant execute on function public.build_daily_values_view_filter_clause(jsonb) to anon, authenticated, service_role;
grant execute on function public.sample_daily_values_view_by_outdoor_temperature(jsonb, integer, numeric, uuid, text) to anon, authenticated, service_role;
