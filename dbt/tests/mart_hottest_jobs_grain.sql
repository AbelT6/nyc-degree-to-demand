-- mart.hottest_jobs grain: one row per list_key x rank, ranks contiguous from 1, and a job at most once per list.
with v as (
    select * from {{ ref('mart_hottest_jobs') }}
)

select list_key, rank, 'duplicate list x rank' as problem
from v
group by 1, 2
having count(*) > 1
union all
select list_key, max(rank), 'ranks not contiguous from 1'
from v
group by 1
having max(rank) <> count(*) or min(rank) <> 1
union all
select list_key, min(rank), 'job listed twice in ' || soc_code
from v
group by list_key, soc_code
having count(*) > 1
