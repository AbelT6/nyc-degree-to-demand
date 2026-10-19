-- core.fct_industry_gdp: BEA GDP by county and industry for the five boroughs, 2019-2024 (CAGDP2 current dollars,
-- CAGDP9 real chained 2017 dollars; release 2026-02-05).
-- Grain: year x area_key (borough) x line_code (22 BEA lines: 1 all-industry total, 2 private industries,
-- 20 NAICS sectors incl. 83 government). The 12 combination lines that double-count were dropped in staging.
-- Plan: docs/step4-facts-plan.md §3d, §4 item 14.
--
-- how a source row reaches the dimensions: county_fips -> borough (ref area.county_fips). industry_key: first the
-- seed industry_code_alias (code_system bea_line): line 1 -> 00 all industries; line 2 -> null (an ownership total,
-- weight 0); line 83 -> CES-90 (government = all public ownership, not NAICS 92 although the file labels it 92);
-- every other line by its naics_label -> dim_industry.naics_sector.
--
-- Withheld cells ((D) in the file) are null with is_withheld = true, never 0. Current-dollar sector lines add to
-- line 1 where nothing is withheld (tested, Manhattan 2022-2024); chained dollars do not add across lines, so the
-- mart trends one real line at a time. BEA estimates county GDP from state GDP, mostly with QCEW wages; it is a
-- model, and 2020-2023 are revised each release (release column).

with src as (
    select * from {{ source('staging', 'stg_bea__county_gdp') }}
),

area as (
    select area_key, county_fips
    from {{ ref('area') }}
    where county_fips is not null
),

alias as (
    select source_code, industry_key, weight
    from {{ ref('industry_code_alias') }}
    where code_system = 'bea_line'
),

industry as (
    select industry_key, naics_sector
    from {{ ref('dim_industry') }}
    where naics_sector is not null
)

select
    s.year,
    a.area_key,
    s.line_code,
    s.line_title,
    s.naics_label,
    case
        when al.source_code is not null then (case when al.weight = 1 then al.industry_key end)
        else i.industry_key
    end as industry_key,
    s.gdp_current_thousands::numeric          as gdp_current_thousands,
    s.gdp_real_chained2017_thousands::numeric as gdp_real_chained2017_thousands,
    s.is_withheld,
    s.release,
    'bea_county_gdp' as source_key
from src as s
join area as a
    on a.county_fips = s.county_fips
left join alias as al
    on al.source_code = s.line_code::text
left join industry as i
    on i.naics_sector = s.naics_label
