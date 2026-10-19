-- Detailed majors by crosswalk status must match the profile in plan §6: 1,948 linked, 194 no_job_link, 183 not in the crosswalk.
select cip_soc_status, count(*) as n
from {{ ref('dim_major') }}
where cip_level = 'detailed'
group by cip_soc_status
having (cip_soc_status = 'linked' and count(*) <> 1948)
    or (cip_soc_status = 'no_job_link' and count(*) <> 194)
    or (cip_soc_status = 'not_in_crosswalk' and count(*) <> 183)
    or cip_soc_status is null
