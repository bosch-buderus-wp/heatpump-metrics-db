create or replace function public.build_daily_values_view_filter_clause(filter_model jsonb)
returns text
language plpgsql
immutable
as $$
declare
  logic_operator text := coalesce(lower(filter_model->>'logic'), 'and');
  item jsonb;
  field_name text;
  column_name text;
  operator_name text;
  value_text text;
  clause_text text;
  clause_parts text[] := '{}';
  joiner text;
begin
  if filter_model is null or jsonb_typeof(filter_model) <> 'object' then
    return 'true';
  end if;

  if logic_operator not in ('and', 'or') then
    raise exception 'Unsupported filter logic: %', logic_operator;
  end if;

  for item in
    select value
    from jsonb_array_elements(coalesce(filter_model->'items', '[]'::jsonb))
  loop
    field_name := item->>'field';
    operator_name := item->>'operator';

    if field_name is null or operator_name is null then
      continue;
    end if;

    column_name := case field_name
      when 'date' then 'date'
      when 'heating_id' then 'heating_id'
      when 'user_id' then 'user_id'
      when 'name' then 'name'
      when 'building_energy_standard' then 'building_energy_standard'
      when 'building_type' then 'building_type'
      when 'heating_type' then 'heating_type'
      when 'model_idu' then 'model_idu'
      when 'model_odu' then 'model_odu'
      when 'sw_idu' then 'sw_idu'
      when 'sw_odu' then 'sw_odu'
      when 'country' then 'country'
      when 'postal_code' then 'postal_code'
      when 'used_for_heating' then 'used_for_heating'
      when 'used_for_dhw' then 'used_for_dhw'
      when 'used_for_cooling' then 'used_for_cooling'
      when 'heated_area_m2' then 'heated_area_m2'
      when 'heating_load_kw' then 'heating_load_kw'
      when 'design_outdoor_temp_c' then 'design_outdoor_temp_c'
      when 'building_construction_year' then 'building_construction_year'
      when 'az' then 'az'
      when 'azHeating' then 'az_heating'
      when 'az_heating' then 'az_heating'
      when 'outdoor_temperature_c' then 'outdoor_temperature_c'
      when 'flow_temperature_c' then 'flow_temperature_c'
      when 'thermal_energy_kwh' then 'thermal_energy_kwh'
      when 'electrical_energy_kwh' then 'electrical_energy_kwh'
      when 'thermal_energy_heating_kwh' then 'thermal_energy_heating_kwh'
      when 'electrical_energy_heating_kwh' then 'electrical_energy_heating_kwh'
      else null
    end;

    if column_name is null then
      raise exception 'Unsupported filter field: %', field_name;
    end if;

    if operator_name not in (
      'contains',
      'equals',
      'is',
      'startsWith',
      'endsWith',
      '>',
      '>=',
      '<',
      '<=',
      'isEmpty',
      'isNotEmpty',
      'isAnyOf'
    ) then
      raise exception 'Unsupported filter operator: %', operator_name;
    end if;

    if operator_name in ('isEmpty', 'isNotEmpty') then
      clause_text := case
        when operator_name = 'isEmpty' then
          format('(%1$I is null or %1$I::text = '''')', column_name)
        else
          format('(%1$I is not null and %1$I::text <> '''')', column_name)
      end;
      clause_parts := array_append(clause_parts, clause_text);
      continue;
    end if;

    if not (item ? 'value') or item->'value' is null then
      continue;
    end if;

    if jsonb_typeof(item->'value') = 'string' and item->>'value' = '' then
      continue;
    end if;

    if operator_name = 'isAnyOf' then
      if jsonb_typeof(item->'value') <> 'array' then
        raise exception 'isAnyOf requires an array value for field %', field_name;
      end if;

      if column_name in ('used_for_heating', 'used_for_dhw', 'used_for_cooling') then
        select '(' || string_agg(format('%I = %L::boolean', column_name, element_value), ' or ') || ')'
          into clause_text
        from jsonb_array_elements_text(item->'value') as values_table(element_value);
      elsif column_name in (
        'heated_area_m2',
        'heating_load_kw',
        'design_outdoor_temp_c',
        'building_construction_year',
        'az',
        'az_heating',
        'outdoor_temperature_c',
        'flow_temperature_c',
        'thermal_energy_kwh',
        'electrical_energy_kwh',
        'thermal_energy_heating_kwh',
        'electrical_energy_heating_kwh'
      ) then
        select '(' || string_agg(format('%I = %L::double precision', column_name, element_value), ' or ') || ')'
          into clause_text
        from jsonb_array_elements_text(item->'value') as values_table(element_value);
      elsif column_name = 'date' then
        select '(' || string_agg(format('%I = %L::date', column_name, element_value), ' or ') || ')'
          into clause_text
        from jsonb_array_elements_text(item->'value') as values_table(element_value);
      else
        select '(' || string_agg(format('%I = %L', column_name, element_value), ' or ') || ')'
          into clause_text
        from jsonb_array_elements_text(item->'value') as values_table(element_value);
      end if;

      if clause_text is not null then
        clause_parts := array_append(clause_parts, clause_text);
      end if;
      continue;
    end if;

    value_text := item->>'value';

    if operator_name in ('contains', 'startsWith', 'endsWith') then
      clause_text := case operator_name
        when 'contains' then format('%1$I is not null and %1$I::text ilike %2$L', column_name, '%' || value_text || '%')
        when 'startsWith' then format('%1$I is not null and %1$I::text ilike %2$L', column_name, value_text || '%')
        else format('%1$I is not null and %1$I::text ilike %2$L', column_name, '%' || value_text)
      end;
      clause_parts := array_append(clause_parts, clause_text);
      continue;
    end if;

    if column_name in ('used_for_heating', 'used_for_dhw', 'used_for_cooling') then
      if operator_name not in ('equals', 'is') then
        raise exception 'Unsupported boolean operator % for field %', operator_name, field_name;
      end if;

      clause_text := format('%I = %L::boolean', column_name, value_text);
      clause_parts := array_append(clause_parts, clause_text);
      continue;
    end if;

    if column_name in (
      'heated_area_m2',
      'heating_load_kw',
      'design_outdoor_temp_c',
      'building_construction_year',
      'az',
      'az_heating',
      'outdoor_temperature_c',
      'flow_temperature_c',
      'thermal_energy_kwh',
      'electrical_energy_kwh',
      'thermal_energy_heating_kwh',
      'electrical_energy_heating_kwh'
    ) then
      clause_text := case operator_name
        when 'equals' then format('%I = %L::double precision', column_name, value_text)
        when 'is' then format('%I = %L::double precision', column_name, value_text)
        when '>' then format('%I > %L::double precision', column_name, value_text)
        when '>=' then format('%I >= %L::double precision', column_name, value_text)
        when '<' then format('%I < %L::double precision', column_name, value_text)
        when '<=' then format('%I <= %L::double precision', column_name, value_text)
        else null
      end;
      if clause_text is null then
        raise exception 'Unsupported numeric operator % for field %', operator_name, field_name;
      end if;
      clause_parts := array_append(clause_parts, clause_text);
      continue;
    end if;

    if column_name = 'date' then
      clause_text := case operator_name
        when 'equals' then format('%I = %L::date', column_name, value_text)
        when 'is' then format('%I = %L::date', column_name, value_text)
        when '>' then format('%I > %L::date', column_name, value_text)
        when '>=' then format('%I >= %L::date', column_name, value_text)
        when '<' then format('%I < %L::date', column_name, value_text)
        when '<=' then format('%I <= %L::date', column_name, value_text)
        else null
      end;
      if clause_text is null then
        raise exception 'Unsupported date operator % for field %', operator_name, field_name;
      end if;
      clause_parts := array_append(clause_parts, clause_text);
      continue;
    end if;

    clause_text := case operator_name
      when 'equals' then format('%I = %L', column_name, value_text)
      when 'is' then format('%I = %L', column_name, value_text)
      else null
    end;
    if clause_text is null then
      raise exception 'Unsupported text operator % for field %', operator_name, field_name;
    end if;

    clause_parts := array_append(clause_parts, clause_text);
  end loop;

  if array_length(clause_parts, 1) is null then
    return 'true';
  end if;

  joiner := case when logic_operator = 'or' then ' or ' else ' and ' end;
  return '(' || array_to_string(clause_parts, joiner) || ')';
end;
$$;

create or replace function public.sample_daily_values_view_by_outdoor_temperature(
  filter_model jsonb default '{"logic":"and","items":[]}'::jsonb,
  max_rows integer default 1000,
  outdoor_temperature_bin_width_k numeric default 2,
  current_user_id uuid default null
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
      where outdoor_temperature_c is not null
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
  $sql$, filter_clause, current_user_id, safe_max_rows, safe_bin_width);

  return query execute sql;
end;
$$;

grant execute on function public.build_daily_values_view_filter_clause(jsonb) to anon, authenticated, service_role;
grant execute on function public.sample_daily_values_view_by_outdoor_temperature(jsonb, integer, numeric, uuid) to anon, authenticated, service_role;
