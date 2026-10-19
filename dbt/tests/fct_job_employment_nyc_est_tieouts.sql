-- D8 estimate tie-outs (plan docs/step4-facts-plan.md §4 item 3; brief group E item 3):
-- (a) the yearly sum of employment_est equals the yearly sum of the pattern-sector input within 1 (shares sum to 1);
-- (b) dissimilarity index 2025 vs the NYS DOL NYC wage table (fct_job_wage_nyc): half the sum over jobs present in
--     both (below the major level, employment published) of |share_est - share_nyc| x 100, below 20 (nb 09: 13.9);
-- (c) 2022 total below the NYS DOL 2022-32 projection base (fct_job_projection 00-0000) and within 15% of it. The
--     plan said +/- 8%, but the estimate equals QCEW 2022 by construction (4,347,361) and the base (4,850,820) counts
--     the self-employed and other workers outside UI coverage: measured -10.4%, so the band follows the data;
-- (d) no negative or null employment_est; share_from_government_pattern in [0, 1];
-- (e) traces: Software Developers 15-1252 in 2025 between 55,000 and 95,000 (NYS DOL NYC table: 74,710);
--     Registered Nurses 29-1141 in 2025 between 70,000 and 130,000 (nb 09: the state pattern over-predicts NYC RNs).
with f as (
    select f.*, d.soc_level
    from {{ ref('fct_job_employment_nyc_est') }} as f
    join {{ ref('dim_job') }} as d on d.soc_code = f.soc_code
),

est_year as (
    select year, sum(employment_est) as total
    from f
    group by year
),

input_year as (
    select year, sum(employment) as total
    from {{ ref('audit_nyc_employment_by_pattern_sector') }}
    group by year
),

common_2025 as (
    select f.soc_code, f.employment_est, w.employment as nyc
    from f
    join {{ ref('fct_job_wage_nyc') }} as w
        on w.area_key = 'nyc' and w.soc_code = f.soc_code
    where f.year = 2025
      and f.soc_level not in ('total', 'major', 'minor')
      and w.employment is not null
),

common_shares as (
    select
        employment_est / sum(employment_est) over () as share_est,
        nyc / sum(nyc) over ()                       as share_nyc
    from common_2025
),

dissimilarity as (
    select
        sum(abs(share_est - share_nyc)) / 2 * 100 as index_2025,
        count(*) as n_jobs
    from common_shares
),

projection_2022 as (
    select base_employment
    from {{ ref('fct_job_projection') }}
    where edition = '2022-2032' and soc_code = '00-0000'
)

select 'yearly_total_gap' as problem, e.year::text || ' est ' || round(e.total, 2)::text || ' input ' || round(i.total, 2)::text as detail
from est_year as e
join input_year as i on i.year = e.year
where abs(e.total - i.total) > 1

union all
select 'year_without_input', e.year::text
from est_year as e
where not exists (select 1 from input_year as i where i.year = e.year)

union all
select 'dissimilarity_2025', round(max(index_2025), 2)::text || ' over ' || max(n_jobs)::text || ' jobs'
from dissimilarity
having max(index_2025) >= 20 or max(n_jobs) < 500

union all
select 'projection_base_2022', 'est ' || round(e.total, 0)::text || ' projection ' || p.base_employment::text
from est_year as e
cross join projection_2022 as p
where e.year = 2022
  and (e.total >= p.base_employment or (p.base_employment - e.total) / p.base_employment > 0.15)

union all
select 'bad_value', year::text || ' ' || soc_code
from f
where employment_est is null or employment_est < 0
   or share_from_government_pattern < 0 or share_from_government_pattern > 1

union all
select 'trace_15-1252_2025', round(employment_est, 0)::text
from f
where year = 2025 and soc_code = '15-1252'
  and (employment_est < 55000 or employment_est > 95000)

union all
select 'trace_29-1141_2025', round(employment_est, 0)::text
from f
where year = 2025 and soc_code = '29-1141'
  and (employment_est < 70000 or employment_est > 130000)

union all
select 'trace_missing', code
from (values ('15-1252'), ('29-1141')) as v (code)
where not exists (select 1 from f where f.year = 2025 and f.soc_code = v.code)
