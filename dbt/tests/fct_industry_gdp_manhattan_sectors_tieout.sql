-- Plan §4 item 14 (source card bea_county_gdp.md §5): Manhattan 2022-2024, where nothing is withheld, the 20 sector
-- lines (3..82 plus 83 government) add to line 1 (all industry total) in current dollars within 0.1%.
with manhattan as (
    select
        year,
        sum(gdp_current_thousands) filter (where line_code not in (1, 2)) as sector_sum,
        max(gdp_current_thousands) filter (where line_code = 1)           as total,
        count(*) filter (where is_withheld)                               as n_withheld,
        count(*)                                                          as n_lines
    from {{ ref('fct_industry_gdp') }}
    where area_key = 'manhattan' and year between 2022 and 2024
    group by year
)

select *, sector_sum / total - 1 as rel_diff
from manhattan
where n_lines <> 22 or n_withheld > 0 or total is null
   or abs(sector_sum / total - 1) > 0.001
