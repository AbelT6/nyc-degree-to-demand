-- Risk 7 (plan docs/step4-facts-plan.md §5): no (year, area, ownership, industry) cell carries both a NYS DOL and a BLS row.
select year, area_key, ownership, industry_key, count(distinct source_key) as n_sources
from {{ ref('fct_industry_employment_annual') }}
group by 1, 2, 3, 4
having count(distinct source_key) > 1
