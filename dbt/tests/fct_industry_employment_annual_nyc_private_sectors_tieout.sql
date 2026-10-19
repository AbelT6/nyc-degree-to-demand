-- Plan §4 item 11: NYC private sector rows (incl. 99 unclassified) add to the NYC private all-industries row within ±3 jobs every year.
with sectors as (
    select year, sum(employment) as sector_sum
    from {{ ref('fct_industry_employment_annual') }}
    where area_key = 'nyc' and ownership = 'Private' and industry_key <> '00'
    group by year
),

total as (
    select year, employment as total
    from {{ ref('fct_industry_employment_annual') }}
    where area_key = 'nyc' and ownership = 'Private' and industry_key = '00'
)

select t.year, t.total, s.sector_sum, s.sector_sum - t.total as diff
from total as t
left join sectors as s using (year)
where s.sector_sum is null or abs(s.sector_sum - t.total) > 3
