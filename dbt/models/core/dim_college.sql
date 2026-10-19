-- core.dim_college: one row per IPEDS institution (unitid) that appears in any NYC directory year,
-- with attributes from its latest directory row. Latest row, not latest year: 52 colleges last
-- appear 2015-2023 and completions still reference them (docs/step1-dimensions-plan.md §6).

with latest as (
    select distinct on (unitid)
        unitid, year, name, city, county_fips, borough, sector, control, level, is_cuny, system_name, closed_date
    from {{ source('staging', 'stg_ipeds__institutions') }}
    order by unitid, year desc
),

span as (
    select unitid, min(year) as first_directory_year, count(*) as directory_years
    from {{ source('staging', 'stg_ipeds__institutions') }}
    group by unitid
),

latest_year as (
    select max(year) as year from {{ source('staging', 'stg_ipeds__institutions') }}
)

select
    l.unitid,
    l.name as college_name,
    l.city,
    l.borough,
    l.county_fips,
    l.sector,
    l.control,
    l.level,
    l.is_cuny,
    l.system_name,
    l.year as directory_year,
    s.first_directory_year,
    s.directory_years,
    l.year = y.year as is_in_latest_directory,
    -- IPEDS writes CLOSEDAT as MM/DD/YYYY; anything else (none in the loaded years) stays null
    case when l.closed_date ~ '^\d{2}/\d{2}/\d{4}$' then to_date(l.closed_date, 'MM/DD/YYYY') end as closed_date,
    coalesce(l.closed_date ~ '^\d{2}/\d{2}/\d{4}$', false) as is_closed
from latest as l
join span as s on s.unitid = l.unitid
cross join latest_year as y
