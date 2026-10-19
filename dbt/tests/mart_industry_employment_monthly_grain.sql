-- mart.industry_employment_monthly grain: one row per month_start x area_key x series_code (latest vintage only).
select month_start, area_key, series_code, count(*) as n
from {{ ref('mart_industry_employment_monthly') }}
group by 1, 2, 3
having count(*) > 1
