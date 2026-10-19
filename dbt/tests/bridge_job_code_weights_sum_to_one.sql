-- Weights in bridge_job_code sum to 1 for every code_system x source_code (tolerance 1e-9).
select code_system, source_code, sum(weight) as total
from {{ ref('bridge_job_code') }}
group by 1, 2
having abs(sum(weight) - 1) > 1e-9
