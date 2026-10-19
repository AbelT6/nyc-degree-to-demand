-- mart.bridge_industry_cluster: hidden bridging table sector x sub-cluster (Advance CTE; sectors 54 and
-- 92 sit in two clusters).
{{ config(alias='bridge_industry_cluster') }}

select industry_key, subcluster_id
from {{ ref('bridge_industry_cluster') }}
