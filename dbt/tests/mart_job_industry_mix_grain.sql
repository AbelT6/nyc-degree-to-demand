-- mart.job_industry_mix grain: one row per soc_code x industry_key; rank_in_job contiguous from 1 per job.
with v as (
    select * from {{ ref('mart_job_industry_mix') }}
)

select soc_code, industry_key, 'duplicate job x sector' as problem
from v
group by 1, 2
having count(*) > 1
union all
select soc_code, null, 'rank_in_job not contiguous from 1'
from v
group by 1
having max(rank_in_job) <> count(*) or min(rank_in_job) <> 1
