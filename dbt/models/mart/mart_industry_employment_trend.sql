-- mart.industry_employment_trend: one row per year x area (NYC and the five boroughs) x ownership x industry,
-- QCEW annual averages 2019-2025 (docs/mart-plan.md §4e; nb 41; D18).
-- Published rows come straight from fct_industry_employment_annual (NYS DOL for private and the totals, BLS
-- county files for federal / state / local government by sector; undisclosed cells carry disclosed = false and
-- null employment). All-ownership rows by sector exist in QCEW for 10 sectors only, so the NYC all-ownership
-- estimate by sector (private + government by sector, D18) is added from audit_nyc_employment_by_pattern_sector
-- as ownership 'All ownerships (estimate)', employment only; its government remainder sits on GOV-OEWS.
-- Change columns compare the row with the same area x ownership x industry in 2019.
-- D24 A, totals and parts share the rows: base filter = one area_key and one ownership; then read the is_total_row
-- (industry '00') or sum the is_leaf_row rows (the sectors, 99 included). Ownership 'Total, ...' rows total other
-- ownerships and the area 'nyc' totals the boroughs, so never sum across ownership or area. The estimate ownership
-- has no '00' row; its sectors sum to 'Total, All Ownerships' '00'. Undisclosed cells leave a leaf sum short.
{{ config(alias='industry_employment_trend') }}

{% call mart_numeric_as_double() %}
with published as (
    select
        year,
        area_key,
        ownership,
        'published'                 as ownership_kind,
        industry_key,
        establishments,
        employment,
        total_wages,
        avg_annual_pay,
        disclosed,
        source_key
    from {{ ref('fct_industry_employment_annual') }}
),

estimate as (
    select
        year,
        'nyc'                       as area_key,
        'All ownerships (estimate)' as ownership,
        'estimate (D18)'            as ownership_kind,
        industry_key,
        null::numeric               as establishments,
        employment,
        null::numeric               as total_wages,
        null::numeric               as avg_annual_pay,
        true                        as disclosed,
        'nysdol_qcew_annual'        as source_key
    from {{ ref('audit_nyc_employment_by_pattern_sector') }}
),

unioned as (
    select * from published
    union all
    select * from estimate
),

with_base as (
    select
        u.*,
        max(employment) filter (where year = 2019)
            over (partition by area_key, ownership, industry_key) as employment_2019
    from unioned u
)

select
    year,
    make_date(year, 1, 1)                                   as year_start,
    area_key,
    ownership,
    ownership_kind,
    industry_key,
    establishments,
    employment,
    total_wages,
    avg_annual_pay,
    disclosed,
    industry_key = '00'                                     as is_total_row,
    industry_key <> '00'                                    as is_leaf_row,
    ownership like 'Total,%'                                as is_ownership_total,
    employment_2019,
    employment - employment_2019                            as change_vs_2019,
    case when employment_2019 > 0
         then employment / employment_2019 - 1 end          as pct_change_vs_2019,
    source_key,
    case when ownership_kind = 'published'
         then 'QCEW annual averages 2019-2025 (NYS DOL; government by sector from BLS county files)'
         else 'QCEW annual averages 2019-2025; all-ownership by sector = private (NYS DOL) + government by sector (BLS county, D18); estimate'
    end                                                     as as_of
from with_base
{% endcall %}
