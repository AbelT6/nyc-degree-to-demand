-- mart.job_escape_route is unique at origin_soc_code x route_rank (plan §4b); route_rank 0 is the single
-- "no route listed" row an origin gets when nothing reaches r >= 0.75, so it never sits beside ranks 1-3.
select origin_soc_code, route_rank, count(*) as n
from {{ ref('mart_job_escape_route') }}
group by 1, 2
having count(*) > 1
union all
select origin_soc_code, 0, count(*)
from {{ ref('mart_job_escape_route') }}
group by origin_soc_code
having bool_or(route_rank = 0) and count(*) > 1
