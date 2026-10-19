-- mart.dim_cluster: the umbrella slicer (brief S6, D6): one row per Career Clusters sub-cluster with its
-- cluster and the S7 featured area. Jobs, majors and industries reach it through the three hidden
-- bridging tables (Microsoft many-to-many guidance); the slicer filters and never sums.
{{ config(alias='dim_cluster') }}

select
    subcluster_id,
    cluster_id,
    cluster_name,
    subcluster_name,
    featured_area,
    coalesce(featured_area, 'Other') as featured_area_or_other,
    'career_clusters' as source_key
from {{ ref('dim_career_cluster') }}
