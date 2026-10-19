-- mart.industry_hiring_trend grain: one row per year x industry_key.
select year, industry_key, count(*) as n
from {{ ref('mart_industry_hiring_trend') }}
group by 1, 2
having count(*) > 1
