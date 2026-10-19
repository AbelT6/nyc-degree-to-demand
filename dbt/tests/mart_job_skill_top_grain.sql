-- mart.job_skill_top grain: one row per soc_code x domain x rank; ranks contiguous from 1; at most 8 elements per
-- skill or knowledge domain and 10 software products; importance non-increasing down the rank within a domain.
with v as (
    select * from {{ ref('mart_job_skill_top') }}
)

select soc_code, domain, rank, 'duplicate job x domain x rank' as problem
from v
group by 1, 2, 3
having count(*) > 1
union all
select soc_code, domain, max(rank), 'ranks not contiguous from 1'
from v
group by 1, 2
having max(rank) <> count(*) or min(rank) <> 1
union all
select soc_code, domain, max(rank), 'more rows than the cap (8 skills, 10 software)'
from v
group by 1, 2
having max(rank) > case when domain = 'software' then 10 else 8 end
union all
select soc_code, domain, rank, 'importance rises down the rank'
from (
    select soc_code, domain, rank, importance,
        lag(importance) over (partition by soc_code, domain order by rank) as prev
    from v
    where domain <> 'software'
) x
where importance > prev
