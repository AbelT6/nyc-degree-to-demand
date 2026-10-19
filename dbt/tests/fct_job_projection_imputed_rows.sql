-- Imputed rows (plan §6.4): exactly 60, all detailed dim_job codes, none with a staging 2022-32 row, no negative
-- value, annual = growth + separation within 1e-6, separation >= 0; the 11 collapsed codes never appear in 2022-32.
with imputed as (
    select f.*, d.soc_level
    from {{ ref('fct_job_projection') }} as f
    join {{ ref('dim_job') }} as d on d.soc_code = f.soc_code
    where f.quality_flag = 'imputed'
)

select 'imputed_count', count(*)::text from imputed having count(*) <> 60
union all
select 'imputed_not_2022_32', edition || ' ' || soc_code from imputed where edition <> '2022-2032'
union all
select 'imputed_not_detailed', soc_code from imputed where soc_level <> 'detailed'
union all
select 'imputed_code_published', i.soc_code
from imputed as i
where exists (select 1 from {{ source('staging', 'stg_nysdol__occupation_projections') }} s
              where s.edition = '2022-2032' and s.soc_code = i.soc_code)
union all
select 'imputed_negative', soc_code from imputed
where least(base_employment, projected_employment, annual_openings_avg, separation_openings_avg) < 0
union all
select 'imputed_openings_identity', soc_code from imputed
where abs(annual_openings_avg - growth_openings_avg - separation_openings_avg) > 1e-6
   or abs(employment_change - (projected_employment - base_employment)) > 1e-6
   or abs(growth_openings_avg - employment_change / 10) > 1e-6
union all
select 'imputed_missing_fill_keys', soc_code from imputed
where fill_group is null or fill_candidate is null or weight_basis is null
union all
select 'collapsed_code_in_fact', f.soc_code
from {{ ref('fct_job_projection') }} as f
join {{ source('staging', 'stg_nysdol__occupation_projections') }} as s
    on s.edition = f.edition and s.soc_code = f.soc_code and s.quality_flag = 'publisher_defect'
