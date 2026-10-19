-- Plan §4 item 12: age groups A01-A08 add to A00 (emp_begin) in every cell where all nine values are released
-- (flag 1). LEHD noise infusion means the parts miss the total by a few jobs (measured max 3 over 2,480 cells);
-- the tolerance is ±5.
with cells as (
    select
        year, quarter, area_key, industry_key,
        sum(emp_begin) filter (where group_code <> 'A00') as parts,
        max(emp_begin) filter (where group_code = 'A00') as total,
        count(*) filter (where emp_begin_flag = 1)       as n_released,
        count(*)                                         as n_groups
    from {{ ref('fct_industry_hiring_quarterly') }}
    where breakdown = 'age'
    group by 1, 2, 3, 4
)

select *, parts - total as diff
from cells
where n_groups = 9 and n_released = 9
  and abs(parts - total) > 5
