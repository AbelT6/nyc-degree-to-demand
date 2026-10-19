-- mart.bridge_major_cluster: hidden bridging table major x sub-cluster (D6: the clusters of the major's
-- D2-passing jobs, with the share of the major's openings weight that sits in the sub-cluster).
{{ config(alias='bridge_major_cluster') }}

{% call mart_numeric_as_double() %}
select major_award_key, subcluster_id, share_openings, share_equal, n_jobs
from {{ ref('bridge_major_cluster') }}
{% endcall %}
