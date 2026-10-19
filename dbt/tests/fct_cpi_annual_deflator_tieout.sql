-- CPI tie-outs (plan docs/step4-facts-plan.md §4 item 1): 22 rows (2015-2025 x 2 areas); deflator_to_2025 = 1 in 2025;
-- NY metro 2025 / 2019 index ratio = 1.242 +- 0.001 (the +24.2% in §3a); months_collected = 11 in 2025, 12 otherwise.
with f as (
    select * from {{ ref('fct_cpi_annual') }}
)

select 'row_count' as problem, count(*)::text as detail
from f
having count(*) <> 22

union all
select 'deflator_not_one_in_2025', area_key || ' ' || deflator_to_2025::text
from f
where year = 2025 and abs(deflator_to_2025 - 1) > 1e-9

union all
select 'ny_2019_to_2025_ratio', (a.cpi_index / b.cpi_index)::text
from f as a
join f as b on b.area_key = a.area_key and b.year = 2019
where a.area_key = 'ny_metro' and a.year = 2025
  and abs(a.cpi_index / b.cpi_index - 1.242) > 0.001

union all
select 'months_collected', year::text || ' ' || area_key || ' ' || months_collected::text
from f
where months_collected <> case when year = 2025 then 11 else 12 end
