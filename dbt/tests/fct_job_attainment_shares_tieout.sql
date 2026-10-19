-- Tie-out (plan §4 item 5): shares sum to 100 +- 0.2 per job, every job has all 7 levels, and there are 832 jobs.
with per_job as (
    select soc_code, sum(pct_of_workers) as total, count(*) as n_levels
    from {{ ref('fct_job_attainment') }}
    group by soc_code
)
select soc_code, total::text as detail, 'sum off' as reason
from per_job
where abs(total - 100) > 0.2
union all
select soc_code, n_levels::text, 'not 7 levels'
from per_job
where n_levels <> 7
union all
select 'all', count(*)::text, 'not 832 jobs'
from per_job
having count(*) <> 832
