-- core.fct_industry_employment_annual: QCEW annual average jobs, establishments and wages for NYC and the five
-- boroughs by ownership and NAICS sector, 2019-2025.
-- Grain: year x area_key x ownership x industry_key. NAICS levels 0 (00, all industries) and 2 (sectors, 99
-- unclassified) only; decision §6.4 (3-/4-digit detail is incomplete from 2022 and dim_industry has no rows for it).
-- Plan: docs/step4-facts-plan.md §3d, §4 item 11, §5 risk 7, §6.4.
--
-- source_key            rows                                how a source row reaches the dimensions
-- nysdol_qcew_annual    NYS DOL rows as published           area_code 'NYC' -> nyc; county FIPS -> borough (ref area.county_fips);
--                                                           naics_code -> dim_industry.qcew_ny_code (00 -> 00; 31/44/48 -> ranges)
-- bls_qcew_county       BLS county government fills         own_code 1/2/3 -> Federal / State / Local Government; county_fips -> borough;
--                                                           industry_code -> dim_industry.qcew_bls_code (agglvl 71 code 10 -> 00)
--
-- BLS rows are added only for (year, area, ownership, industry) cells NYS DOL does not publish (NYS DOL suppresses
-- by dropping the row). Two kinds: (a) borough x government x sector rows straight from the county files; (b) NYC x
-- government x sector rows built by adding the five boroughs: a borough with no BLS row has no such establishments
-- (QCEW publishes every cell with establishments), so its absence is a true zero; a borough whose cell is undisclosed
-- contributes nothing and makes the NYC row disclosed = false (n_boroughs_disclosed says how many did contribute).
-- Measures on undisclosed rows are null (never 0); on a disclosed = false NYC row they are the sum of the disclosed
-- boroughs only. avg_annual_pay = total_wages / employment on every row (NYS DOL publishes it rounded; BLS likewise),
-- numeric, unrounded; the mart rounds. Mixed sources never share a cell (risk 7; tested).

with area as (
    select area_key, county_fips, qcew_ny_area_code
    from {{ ref('area') }}
),

industry as (
    select industry_key, qcew_ny_code, qcew_bls_code
    from {{ ref('dim_industry') }}
),

-- Part 1: NYS DOL, levels 0 and 2 (1,827 rows).
nysdol as (
    select
        s.year,
        a.area_key,
        s.ownership,
        i.industry_key,
        s.establishments::numeric as establishments,
        s.employment::numeric     as employment,
        s.total_wages::numeric    as total_wages,
        true                      as disclosed,
        s.naics_detail_complete,
        null::integer             as n_boroughs_disclosed,
        'nysdol_qcew_annual'      as source_key
    from {{ source('staging', 'stg_nysdol__qcew_annual') }} as s
    join area as a
        on a.qcew_ny_area_code = s.area_code
    join industry as i
        on i.qcew_ny_code = s.naics_code
    where s.naics_level in (0, 2)
),

-- Part 2: BLS county files, government ownerships only, on the fact's keys.
bls as (
    select
        b.year,
        a.area_key,
        case b.own_code
            when '1' then 'Federal Government'
            when '2' then 'State Government'
            when '3' then 'Local Government'
        end as ownership,
        i.industry_key,
        b.estabs::numeric      as establishments,
        b.emp::numeric         as employment,
        b.total_wages::numeric as total_wages,
        b.disclosed
    from {{ source('staging', 'stg_bls__qcew_county') }} as b
    join area as a
        on a.county_fips = b.county_fips
    join industry as i
        on i.qcew_bls_code = b.industry_code
    where b.own_code in ('1', '2', '3')
      and b.agglvl_code in ('71', '74')
),

-- (a) Borough rows NYS DOL lacks.
bls_borough_fill as (
    select
        b.year,
        b.area_key,
        b.ownership,
        b.industry_key,
        b.establishments,
        case when b.disclosed then b.employment end  as employment,
        case when b.disclosed then b.total_wages end as total_wages,
        b.disclosed,
        null::boolean as naics_detail_complete,
        null::integer as n_boroughs_disclosed,
        'bls_qcew_county' as source_key
    from bls as b
    where not exists (
        select 1
        from nysdol as n
        where n.year = b.year
          and n.area_key = b.area_key
          and n.ownership = b.ownership
          and n.industry_key = b.industry_key
    )
),

-- (b) NYC rows NYS DOL lacks: the five boroughs added, disclosed only when every present borough is disclosed.
-- A partial sum (some borough undisclosed) is a lower bound, not a total, and would sit next to complete NYS DOL
-- years as a false series break (review: NYC local 61 = 202 k in 2019 and 211 k in 2025 from NYS DOL,
-- 137-142 k from three disclosed boroughs in between). So measures are null unless every borough is disclosed;
-- n_boroughs_disclosed keeps the count. D8 (audit_nyc_employment_by_pattern_sector) reads the borough rows instead.
bls_nyc_sum as (
    select
        b.year,
        'nyc' as area_key,
        b.ownership,
        b.industry_key,
        case when bool_and(b.disclosed) then sum(b.establishments) end as establishments,
        case when bool_and(b.disclosed) then sum(b.employment)     end as employment,
        case when bool_and(b.disclosed) then sum(b.total_wages)    end as total_wages,
        bool_and(b.disclosed)                            as disclosed,
        null::boolean                                    as naics_detail_complete,
        count(*) filter (where b.disclosed)::integer     as n_boroughs_disclosed,
        'bls_qcew_county'                                as source_key
    from bls as b
    where not exists (
        select 1
        from nysdol as n
        where n.year = b.year
          and n.area_key = 'nyc'
          and n.ownership = b.ownership
          and n.industry_key = b.industry_key
    )
    group by b.year, b.ownership, b.industry_key
),

unioned as (
    select * from nysdol
    union all
    select * from bls_borough_fill
    union all
    select * from bls_nyc_sum
)

select
    year,
    area_key,
    ownership,
    industry_key,
    establishments,
    employment,
    total_wages,
    case when employment > 0 then total_wages / employment end as avg_annual_pay,
    disclosed,
    naics_detail_complete,
    n_boroughs_disclosed,
    source_key
from unioned
