-- mart.job_employment_trend: one row per year x job x area, 2019-2025 (docs/mart-plan.md §4b; explore-plan §3d; D8; nb 40 §2).
--   * area 'nyc'      = the D8 estimate (QCEW NYC x same-year NY staffing pattern, government filed by sector, D18),
--                       labeled employment_kind 'estimate'; every code the research estimates publish, including the
--                       12 broad / aggregate codes OEWS research uses as its lowest level (soc_level on the row; filter
--                       soc_level = 'detailed' for job pages, keep every level for totals, which equal the QCEW NYC total).
--   * area 'ny_metro' = the published OEWS NY metro series (detailed and major-group rows), with the nominal and real
--                       (2025 dollars, NY metro CPI) annual p25 and p50; quality_flag 'split' marks years carried from a
--                       SOC 2010 / hybrid code, series_note the 2024 metro redraw and the 2025 top-code change.
-- 2020 is shown, never used as a base (§3d): employment_2019 and pct_change_vs_2019 repeat the 2019 base on every row.
-- D24 A: the estimate and the published count never share a column. nyc_employment_est is filled on nyc rows only,
-- metro_employment on ny_metro rows only; each sums cleanly on its own (nyc: every level = the QCEW NYC total; metro:
-- filter is_group_total = false, the major-group rows are totals of the detailed rows).
-- in_both_end_years (D37) = the code has a count in this area in 2019 and in 2025, so a change from 2019 compares the
-- same jobs at both ends; the overview's degree-level / all other lines and headline sum only these codes (nyc: 212
-- degree-level codes, +204,310 = +16.8%; the 10 codes OEWS split in 2021 have no 2019 count and leave).
{{ config(alias='job_employment_trend') }}

{% call mart_numeric_as_double() %}
with nyc as (
    select
        e.year,
        e.area_key,
        e.soc_code,
        e.employment_est                            as employment,
        'estimate'                                  as employment_kind,
        e.method,
        e.n_sectors_contributing,
        e.pattern_coverage_min,
        e.share_from_government_pattern,
        null::numeric                               as annual_p25,
        null::numeric                               as annual_p50,
        null::numeric                               as annual_p25_2025usd,
        null::numeric                               as annual_p50_2025usd,
        null::text                                  as quality_flag,
        null::text                                  as series_note,
        e.source_key
    from {{ ref('fct_job_employment_nyc_est') }} as e
    where e.year between 2019 and 2025
),

metro as (
    select
        w.year,
        w.area_key,
        w.soc_code,
        w.employment,
        'published'                                 as employment_kind,
        'oews_metro_survey'                         as method,
        null::integer                               as n_sectors_contributing,
        null::numeric                               as pattern_coverage_min,
        null::numeric                               as share_from_government_pattern,
        w.annual_p25,
        w.annual_p50,
        w.annual_p25_2025usd,
        w.annual_p50_2025usd,
        w.quality_flag,
        w.series_note,
        w.source_key
    from {{ ref('fct_job_employment_wage_annual') }} as w
    where w.year between 2019 and 2025 and w.occ_level in ('detailed', 'major')
),

unioned as (
    select * from nyc
    union all
    select * from metro
)

select
    u.year,
    make_date(u.year, 1, 1)                                                                 as year_start,
    u.area_key,
    u.soc_code,
    j.soc_level,
    j.is_degree_entry,
    j.is_all_other,
    case when u.area_key = 'nyc' then u.employment end                                      as nyc_employment_est,
    case when u.area_key = 'ny_metro' then u.employment end                                 as metro_employment,
    u.area_key = 'ny_metro' and j.soc_level = 'major'                                       as is_group_total,
    u.employment_kind,
    u.method,
    max(u.employment) filter (where u.year = 2019) over (partition by u.area_key, u.soc_code) as employment_2019,
    case when max(u.employment) filter (where u.year = 2019) over (partition by u.area_key, u.soc_code) > 0
         then u.employment / max(u.employment) filter (where u.year = 2019) over (partition by u.area_key, u.soc_code) - 1
    end                                                                                     as pct_change_vs_2019,
    coalesce(bool_or(u.year = 2019 and u.employment is not null) over (partition by u.area_key, u.soc_code)
             and bool_or(u.year = 2025 and u.employment is not null) over (partition by u.area_key, u.soc_code), false)
                                                                                            as in_both_end_years,
    u.n_sectors_contributing,
    u.pattern_coverage_min,
    u.share_from_government_pattern,
    u.annual_p25,
    u.annual_p50,
    u.annual_p25_2025usd,
    u.annual_p50_2025usd,
    u.quality_flag,
    u.series_note,
    u.source_key,
    case when u.area_key = 'nyc'
         then 'NYC estimate (D8): NYS DOL QCEW annual average x OEWS research NY staffing pattern, same year, 2019-2025'
         else 'OEWS NY metro (35620) May 2019 - May 2025; real dollars = NY metro CPI-U, 2025 base'
    end                                                                                     as as_of
from unioned as u
join {{ ref('dim_job') }} as j on j.soc_code = u.soc_code
{% endcall %}
