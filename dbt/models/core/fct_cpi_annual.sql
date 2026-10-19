-- core.fct_cpi_annual: BLS CPI-U annual averages (series M13) for the NY metro area (S12A) and the US city
-- average (0000), with the deflator every real-dollar column in the project uses.
-- Grain: year x area_key, 2015-2025 (22 rows).
-- Plan: docs/step4-facts-plan.md §3a (design), §4 item 1 (tests), §6 Tier 1 default (real dollars use the NY metro
-- annual average of the data year, as BLS does for its own real-earnings series; card bls_cpi.md §5).
--
-- area_code reaches dim_area through dim_area.cpi_area_code (S12A -> ny_metro, 0000 -> us).
-- deflator_to_2025 = index(2025, same area) / index(year); 1 in 2025 by construction. The 2025 annual average is an
-- 11-month average (the staged file stops at November 2025), which months_collected records; every other year has 12.

with src as (
    select * from {{ source('staging', 'stg_bls__cpi') }}
),

area as (
    select area_key, cpi_area_code
    from {{ ref('dim_area') }}
    where cpi_area_code is not null
),

annual as (
    select
        s.year,
        a.area_key,
        s.index_value::numeric as cpi_index
    from src as s
    join area as a on a.cpi_area_code = s.area_code
    where s.period_type = 'annual_avg'
      and s.year between 2015 and 2025
),

months as (
    select
        s.year,
        a.area_key,
        count(*) filter (where s.index_value is not null) as months_collected
    from src as s
    join area as a on a.cpi_area_code = s.area_code
    where s.period_type = 'month'
    group by s.year, a.area_key
),

base as (
    select area_key, cpi_index as base_index
    from annual
    where year = 2025
)

select
    an.year,
    an.area_key,
    an.cpi_index,
    2025 as base_year,
    b.base_index / an.cpi_index as deflator_to_2025,
    m.months_collected,
    'bls_cu' as source_key
from annual as an
join base as b on b.area_key = an.area_key
left join months as m on m.year = an.year and m.area_key = an.area_key
