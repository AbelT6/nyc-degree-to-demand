-- core.bridge_job_cluster: SOC 2018 job x Career Clusters sub-cluster, as published (D6, many-to-many).
-- Every Advance CTE SOC code is a dim_job row (851 jobs, 1,203 rows). Joined on the case-insensitive key.

select
    s.soc_code,
    c.subcluster_id,
    c.cluster_id,
    c.cluster_name,
    c.subcluster_name,
    c.featured_area,
    'career_clusters' as source_key
from {{ source('staging', 'stg_cte__soc_subcluster') }} as s
join {{ ref('dim_career_cluster') }} as c
    on c.subcluster_match_key = lower(trim(s.subcluster_name))
