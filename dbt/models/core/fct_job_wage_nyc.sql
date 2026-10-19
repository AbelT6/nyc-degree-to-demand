-- core.fct_job_wage_nyc: NYS DOL occupational wages for New York City (OEWS regional estimates), as published.
-- Grain: vintage x area_key ('nyc') x soc_code, every published level (total, major, detailed); 702 rows.
-- Plan: docs/step4-facts-plan.md §3a (design), §4 item 4 (tests).
--
-- The staged file is already on SOC 2018 codes and every code exists in dim_job, so soc_code is carried as-is.
-- NYS DOL area code 7 reaches dim_area through dim_area.nysdol_area_code (-> nyc). Values are the published
-- integers: employment, mean, median, entry (approx. mean of the lowest third) and experienced (mean of the top
-- two-thirds) wages; entry_wage_at_floor / median_at_floor mark values NYS DOL raised to the NYC minimum wage.
-- Nothing is split or imputed, so there is no quality_flag; the vintage identifies the release.

with src as (
    select * from {{ source('staging', 'stg_nysdol__occupation_wages') }}
),

area as (
    select area_key, nysdol_area_code
    from {{ ref('dim_area') }}
    where nysdol_area_code is not null
)

select
    s.vintage,
    s.wage_reference,
    s.survey_reference,
    a.area_key,
    s.soc_code,
    s.employment::numeric          as employment,
    s.mean_wage::numeric           as mean_wage,
    s.median_wage::numeric         as median_wage,
    s.entry_wage::numeric          as entry_wage,
    s.experienced_wage::numeric    as experienced_wage,
    s.entry_wage_at_floor,
    s.median_at_floor,
    'nysdol_oews_regions' as source_key
from src as s
join area as a on a.nysdol_area_code = s.area_code
