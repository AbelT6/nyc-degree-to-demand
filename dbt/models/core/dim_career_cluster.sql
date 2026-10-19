-- core.dim_career_cluster: one row per Career Clusters sub-cluster (Advance CTE, D6).
-- The files carry no ids, so cluster_id and subcluster_id are dense ranks over the names, ordered
-- cluster then sub-cluster. Names are matched case-insensitively: the NAICS and CIP files spell
-- 'water systems' in lower case (source card issue 6), so the published 72 rows are 71 sub-clusters.
-- Bridges (step 2) join on subcluster_match_key = lower(trim(name)).

with raw as (
    select cluster_name, subcluster_name, lower(trim(subcluster_name)) as subcluster_match_key
    from {{ source('staging', 'stg_cte__cluster') }}
),

canon as (
    select
        cluster_name,
        subcluster_match_key,
        -- prefer the spelling that starts with a capital letter, then the alphabetically first
        (array_agg(subcluster_name order by (left(subcluster_name, 1) = upper(left(subcluster_name, 1))) desc, subcluster_name))[1]
            as subcluster_name,
        count(*) as spellings_in_source
    from raw
    group by cluster_name, subcluster_match_key
)

select
    dense_rank() over (order by cluster_name, subcluster_match_key) as subcluster_id,
    dense_rank() over (order by cluster_name) as cluster_id,
    cluster_name,
    subcluster_name,
    subcluster_match_key,
    spellings_in_source,
    -- brief S7 featured areas (D11): Business pools three clusters
    case cluster_name
        when 'Digital Technology' then 'Tech'
        when 'Healthcare & Human Services' then 'Healthcare'
        when 'Financial Services' then 'Business'
        when 'Management & Entrepreneurship' then 'Business'
        when 'Marketing & Sales' then 'Business'
        when 'Education' then 'Education'
    end as featured_area
from canon
