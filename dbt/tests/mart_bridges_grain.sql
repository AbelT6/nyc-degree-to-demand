-- The three hidden mart bridges are unique on their composite keys. A duplicate bridge row would double every
-- value that flows through the bidirectional cluster relationship in Power BI (mart review, item 2.4).
select 'bridge_job_cluster' as bridge, soc_code as key_1, subcluster_id::text as key_2, count(*) as n
from {{ ref('mart_bridge_job_cluster') }} group by 2, 3 having count(*) > 1
union all
select 'bridge_major_cluster', major_award_key, subcluster_id::text, count(*)
from {{ ref('mart_bridge_major_cluster') }} group by 2, 3 having count(*) > 1
union all
select 'bridge_industry_cluster', industry_key, subcluster_id::text, count(*)
from {{ ref('mart_bridge_industry_cluster') }} group by 2, 3 having count(*) > 1
