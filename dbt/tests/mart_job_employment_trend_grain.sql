-- mart.job_employment_trend grain: one row per year x soc_code x area_key.
select year, soc_code, area_key, count(*) as n
from {{ ref('mart_job_employment_trend') }}
group by 1, 2, 3
having count(*) > 1
