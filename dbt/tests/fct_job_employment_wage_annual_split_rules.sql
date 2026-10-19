-- Split and combined rows follow the §3a wage rule (plan docs/step4-facts-plan.md §3a, §5 risk 4, §7):
-- (a) a split row (one source, weight < 1) carries its source row's wages unchanged;
-- (b) a combined row's annual_mean lies within the range of its sources' annual means;
-- (c) jobs_per_1000 and location_quotient appear only on published rows; employment_rse_pct never on combined rows;
-- (d) 2021 onward has only published rows (the files are on SOC 2018, identity bridge).
with f as (
    select * from {{ ref('fct_job_employment_wage_annual') }}
),

s as (
    select * from {{ source('staging', 'stg_bls__oews_metro_occupations') }}
),

-- the single source behind a split row: source_codes is 'system:code*weight'
split_rows as (
    select f.*, split_part(split_part(f.source_codes, ':', 2), '*', 1) as src_code
    from f
    where f.quality_flag = 'split'
),

combined_sources as (
    select f.year, f.soc_code, f.annual_mean,
           min(s.annual_mean) as lo, max(s.annual_mean) as hi
    from f
    join s on s.year = f.year
          and position(':' || s.occ_code || '*' in f.source_codes) > 0
    where f.quality_flag = 'combined'
    group by f.year, f.soc_code, f.annual_mean
)

select 'split_wage_changed' as problem, r.year::text || ' ' || r.soc_code || ' <- ' || r.src_code as detail
from split_rows as r
join s on s.year = r.year and s.occ_code = r.src_code
where r.annual_mean is distinct from s.annual_mean::numeric
   or r.annual_p50 is distinct from s.annual_p50::numeric
   or r.hourly_p10 is distinct from s.hourly_p10::numeric
   or r.annual_p90 is distinct from s.annual_p90::numeric

union all
select 'combined_mean_out_of_range', year::text || ' ' || soc_code || ' ' || annual_mean::text
from combined_sources
where annual_mean is not null and (annual_mean < lo - 1e-6 or annual_mean > hi + 1e-6)

union all
select 'ratio_on_unpublished_row', year::text || ' ' || soc_code || ' ' || quality_flag
from f
where quality_flag <> 'published' and (jobs_per_1000 is not null or location_quotient is not null)

union all
select 'rse_on_combined_row', year::text || ' ' || soc_code
from f
where quality_flag = 'combined' and (employment_rse_pct is not null or mean_rse_pct is not null)

union all
select 'unpublished_after_2020', year::text || ' ' || soc_code || ' ' || quality_flag
from f
where year >= 2021 and quality_flag <> 'published'
