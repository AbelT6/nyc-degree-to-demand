-- core.fct_industry_hiring_quarterly: Census LEHD QWI hires, separations, jobs and earnings for private UI-covered
-- jobs in the five boroughs by NAICS sector and worker group, 2019Q1-2025Q4 (release R2026Q3).
-- Grain: year x quarter x area_key (borough) x industry_key x breakdown x group_code. breakdown = age (A00 all ages,
-- A01-A08) or education (E1-E5, workers 25+ plus E5 for everyone under 25); the two never cross. A00 is the one total.
-- Plan: docs/step4-facts-plan.md §3d, §4 item 12; labels in seed ref/qwi_group.csv.
--
-- how a source row reaches the dimensions: county_fips -> borough (ref area.county_fips); naics_sector ->
-- dim_industry.naics_sector (ranges 31-33 / 44-45 / 48-49 as published; 00 all industries; 92 public administration
-- is private-ownership only here, as the files are private-only).
--
-- Measures are as staged: a value is present only where its LEHD status flag is 1 (released); flag 5 = suppressed,
-- value null (never 0). Values are noise-infused by LEHD, so groups add to their totals within a few jobs, not
-- exactly. quarter_complete = false for the latest quarter, whose stable-job measures are not yet published.
-- Not seasonally adjusted; the mart compares year over year or sums four quarters. Levels differ from QCEW by
-- +3-6% (different counting rules); never add this fact to fct_industry_employment_annual.

with src as (
    select * from {{ source('staging', 'stg_census__qwi') }}
),

area as (
    select area_key, county_fips
    from {{ ref('area') }}
    where county_fips is not null
),

industry as (
    select industry_key, naics_sector
    from {{ ref('dim_industry') }}
    where naics_sector is not null
)

select
    s.year,
    s.quarter,
    a.area_key,
    i.industry_key,
    s.breakdown,
    s.group_code,
    s.emp_begin::numeric                    as emp_begin,
    s.emp_stable::numeric                   as emp_stable,
    s.hires_all::numeric                    as hires_all,
    s.hires_new::numeric                    as hires_new,
    s.separations::numeric                  as separations,
    s.earn_stable_monthly::numeric          as earn_stable_monthly,
    s.earn_new_hire_stable_monthly::numeric as earn_new_hire_stable_monthly,
    s.job_creation::numeric                 as job_creation,
    s.emp_begin_flag,
    s.emp_stable_flag,
    s.hires_all_flag,
    s.hires_new_flag,
    s.separations_flag,
    s.earn_stable_monthly_flag,
    s.earn_new_hire_stable_monthly_flag,
    s.job_creation_flag,
    s.quarter_complete,
    s.release,
    'census_qwi' as source_key
from src as s
join area as a
    on a.county_fips = s.county_fips
join industry as i
    on i.naics_sector = s.naics_sector
