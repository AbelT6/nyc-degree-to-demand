-- Plan §4 item 12 (source card census_qwi.md §5): NYC 2024 new hires, all ages, all industries (five boroughs, four
-- quarters) = 2,232,885 as measured in staging, tested within ±0.5%.
with nyc as (
    select sum(hires_new) as hires_new, count(*) as n_cells
    from {{ ref('fct_industry_hiring_quarterly') }}
    where year = 2024 and breakdown = 'age' and group_code = 'A00' and industry_key = '00'
)

select *
from nyc
where n_cells <> 20
   or hires_new is null
   or abs(hires_new / 2232885.0 - 1) > 0.005
