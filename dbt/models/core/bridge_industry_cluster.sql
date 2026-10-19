-- core.bridge_industry_cluster: NAICS sector x Career Clusters sub-cluster, as published (D6).
-- 112 rows; sectors 54 and 92 sit in two clusters.

select
    n.naics_sector,
    i.industry_key,
    c.subcluster_id,
    c.cluster_id,
    c.cluster_name,
    c.subcluster_name,
    c.featured_area,
    'career_clusters' as source_key
from {{ source('staging', 'stg_cte__naics_subcluster') }} as n
join {{ ref('dim_industry') }} as i on i.naics_sector = n.naics_sector
join {{ ref('dim_career_cluster') }} as c
    on c.subcluster_match_key = lower(trim(n.subcluster_name))
