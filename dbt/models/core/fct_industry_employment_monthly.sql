-- core.fct_industry_employment_monthly: NYS DOL Current Employment Statistics (CES) nonfarm payroll jobs for NYC by
-- CES industry series, monthly, January 2019 to the latest published month (not seasonally adjusted).
-- Grain: year x month x series_code (105 series; NYC only, area_key = 'nyc'). The annual average (source month 0) is
-- not stored; the mart averages the twelve months.
-- Plan: docs/step4-facts-plan.md §3d, §4 item 13.
--
-- how a source row reaches the dimensions: industry_key = 'CES-' || supersector_code, the NYS DOL supersector the
-- series belongs to (dim_industry.ces_nysdol_code; all 21 codes present). Detail series keep their supersector as
-- industry_key; the series itself stays identifiable by series_code. ces_level: aggregate for the five totals
-- (00 Total Nonfarm, 05 Total Private, 06 Goods Producing, 07 Service-Providing, 08 Private Service Providing),
-- supersector when the series is the supersector's own series (code = supersector_code || '000000'), else detail
-- (the one code-20 series, Specialty Trade Contractors, is a detail row because NYS DOL publishes construction
-- inside supersector 15 for NYC).
--
-- CES is a payroll survey benchmarked to QCEW each March; the latest months are preliminary (vintage = download
-- date). Its level runs +3.5-5.2% above QCEW NYC total employment (tested); never add it to the QCEW facts.

with src as (
    select * from {{ source('staging', 'stg_nysdol__ces_monthly') }}
),

industry as (
    select industry_key
    from {{ ref('dim_industry') }}
)

select
    s.year,
    s.month,
    'nyc' as area_key,
    s.series_code,
    s.series_title,
    s.supersector_code,
    i.industry_key,
    case
        when s.supersector_code in ('00', '05', '06', '07', '08') then 'aggregate'
        when s.series_code = s.supersector_code || '000000' then 'supersector'
        else 'detail'
    end as ces_level,
    s.employment::numeric as employment,
    s.vintage,
    'nysdol_ces' as source_key
from src as s
join industry as i
    on i.industry_key = 'CES-' || s.supersector_code
