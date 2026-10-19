-- As-published tie-outs (plan docs/step4-facts-plan.md §4 item 4): 702 rows = staging; total row 00-0000 mean wage
-- 95,518; exactly 22 rows entry_wage_at_floor and 5 median_at_floor (both counts equal the staging counts).
with f as (
    select * from {{ ref('fct_job_wage_nyc') }}
),

s as (
    select * from {{ source('staging', 'stg_nysdol__occupation_wages') }}
)

select 'row_count' as problem, (select count(*) from f)::text || ' vs staging ' || (select count(*) from s)::text as detail
where (select count(*) from f) <> (select count(*) from s)

union all
select 'total_mean_wage', coalesce(mean_wage::text, 'null')
from f
where soc_code = '00-0000' and mean_wage is distinct from 95518

union all
select 'entry_wage_at_floor_count', count(*) filter (where entry_wage_at_floor)::text
from f
having count(*) filter (where entry_wage_at_floor) <> 22
    or count(*) filter (where entry_wage_at_floor) <> (select count(*) filter (where entry_wage_at_floor) from s)

union all
select 'median_at_floor_count', count(*) filter (where median_at_floor)::text
from f
having count(*) filter (where median_at_floor) <> 5
    or count(*) filter (where median_at_floor) <> (select count(*) filter (where median_at_floor) from s)
