-- Plan §4 item 11: NYC Private + 'Total, All Government' = 'Total, All Ownerships' within ±1 job every year (all industries).
with by_year as (
    select
        year,
        max(employment) filter (where ownership = 'Private')               as private,
        max(employment) filter (where ownership = 'Total, All Government') as government,
        max(employment) filter (where ownership = 'Total, All Ownerships') as total
    from {{ ref('fct_industry_employment_annual') }}
    where area_key = 'nyc' and industry_key = '00'
    group by year
)

select *, private + government - total as diff
from by_year
where private is null or government is null or total is null
   or abs(private + government - total) > 1
