-- mart.job_entry_signal grain: one row per soc_code x measure, and exactly three measures per job.
with v as (
    select * from {{ ref('mart_job_entry_signal') }}
)

select soc_code, measure, 'duplicate job x measure' as problem
from v
group by 1, 2
having count(*) > 1
union all
select soc_code, null, 'job without exactly three measure rows'
from v
group by 1
having count(*) <> 3
