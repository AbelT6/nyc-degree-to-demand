-- 14 clusters and 71 distinct sub-clusters (72 rows in the file; 'water systems' appears twice).
-- Every sub-cluster name in the SOC, CIP and NAICS crosswalks must match a row case-insensitively.
select 'cluster_count' as problem, count(distinct cluster_id)::text as detail from {{ ref('dim_career_cluster') }} having count(distinct cluster_id) <> 14
union all
select 'subcluster_count', count(*)::text from {{ ref('dim_career_cluster') }} having count(*) <> 71
union all
select 'unmatched_' || src, name from (
    select 'soc' as src, subcluster_name as name from {{ source('staging', 'stg_cte__soc_subcluster') }}
    union select 'cip', subcluster_name from {{ source('staging', 'stg_cte__cip_subcluster') }}
    union select 'naics', subcluster_name from {{ source('staging', 'stg_cte__naics_subcluster') }}
) as s
where lower(trim(name)) not in (select subcluster_match_key from {{ ref('dim_career_cluster') }})
