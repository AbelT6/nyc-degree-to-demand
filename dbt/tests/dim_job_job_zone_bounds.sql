-- job_zone sits between the min and max of the O*NET codes (or parts) it was chosen from,
-- and the three columns are null together.
select soc_code, job_zone, job_zone_min, job_zone_max
from {{ ref('dim_job') }}
where (job_zone is null) <> (job_zone_min is null)
   or (job_zone is null) <> (job_zone_max is null)
   or job_zone < job_zone_min
   or job_zone > job_zone_max
