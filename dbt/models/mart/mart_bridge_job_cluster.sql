-- mart.bridge_job_cluster: hidden bridging table job x sub-cluster (D6 many-to-many, as published).
-- Restricted to codes present in mart.dim_job (detailed jobs); the row-count test reports any drop.
{{ config(alias='bridge_job_cluster') }}

select b.soc_code, b.subcluster_id
from {{ ref('bridge_job_cluster') }} b
join {{ ref('mart_dim_job') }} j on j.soc_code = b.soc_code
