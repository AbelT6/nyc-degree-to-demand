-- Traced record and 2025 series checks (plan docs/step4-facts-plan.md §4 item 2):
-- 2025 Software Developers (15-1252) in the NY metro: employment 100k-150k (the staged value is 121,000; the plan's
-- 60k-90k band was the NYC-only figure), annual_p50 130k-200k, published, deflator 1 so real = nominal;
-- no 2025 row is top-coded (BLS stopped top-coding in the May 2025 release), and every 2025 row carries no_topcode.
with f as (
    select * from {{ ref('fct_job_employment_wage_annual') }}
)

select 'software_developers_2025' as problem,
       'employment ' || coalesce(employment::text, 'null') || ' p50 ' || coalesce(annual_p50::text, 'null')
       || ' flag ' || quality_flag || ' real_p50 ' || coalesce(annual_p50_2025usd::text, 'null') as detail
from f
where year = 2025 and soc_code = '15-1252'
  and not (employment between 100000 and 150000
           and annual_p50 between 130000 and 200000
           and quality_flag = 'published'
           and abs(annual_p50_2025usd - annual_p50) < 1e-6)

union all
select 'software_developers_2025_missing', 'no row'
from (select 1) as x
where not exists (select 1 from f where year = 2025 and soc_code = '15-1252')

union all
select 'top_coded_in_2025', soc_code
from f
where year = 2025 and is_top_coded

union all
select 'series_note_2025', soc_code || ' ' || coalesce(series_note, 'null')
from f
where year = 2025 and series_note is distinct from 'no_topcode'
