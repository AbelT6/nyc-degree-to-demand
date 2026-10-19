-- mart.industry_employment_trend grain: one row per year x area_key x ownership x industry_key.
select year, area_key, ownership, industry_key, count(*) as n
from {{ ref('mart_industry_employment_trend') }}
group by 1, 2, 3, 4
having count(*) > 1
