-- Plan §4 item 11 (source card nysdol_qcew.md §5): Manhattan 2024 private all-industries employment is 2,240,745 as published.
select year, area_key, ownership, industry_key, employment
from {{ ref('fct_industry_employment_annual') }}
where year = 2024 and area_key = 'manhattan' and ownership = 'Private' and industry_key = '00'
  and employment is distinct from 2240745
union all
select 2024, 'manhattan', 'Private', '00', null
where not exists (
    select 1 from {{ ref('fct_industry_employment_annual') }}
    where year = 2024 and area_key = 'manhattan' and ownership = 'Private' and industry_key = '00'
)
