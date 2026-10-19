-- mart.hottest_jobs: one row per list x rank (docs/mart-plan.md §4b; explore-plan §3b; nb 40 §3-§4, §7; D1, D8, D11).
-- Four lists read off job_profile, no blended score (S10):
--   * most_openings            projected 2022-32 annual openings, degree-reachable leaves, All Other codes excluded (top 25);
--                              D1-imputed rows allowed and flagged. Companion value = growth share with its band.
--   * fastest_growing          actual NYC change 2019 -> 2025 (D8 estimate), floor 1,000 estimated jobs in both years,
--                              ranked by ABSOLUTE change with percent beside; projected 2022-32 change
--                              and the metro published change beside; split_2019 flags reclassification (growth_note).
--   * fastest_growing_pct      the same universe ranked by percent change, kept as the page's toggle.
--   * other_jobs_most_openings the "Other jobs in this area" list: All Other codes (D11) by openings, every row.
-- Both lists show the NYS DOL NYC entry wage and NYS DOL's own Employment Prospects rating as the external check.
{{ config(alias='hottest_jobs') }}

{% call mart_numeric_as_double() %}
with p as (
    select * from {{ ref('mart_job_profile') }}
),

lists as (
    select
        'most_openings'                                 as list_key,
        'Most projected annual openings, 2022-2032'     as list_label,
        1                                               as list_sort,
        list1_rank                                      as rank,
        annual_openings_avg                             as ranked_value,
        'openings a year (2022-2032 average)'           as ranked_value_kind,
        growth_share                                    as companion_value,
        'share of openings from growth'                 as companion_kind,
        p.*
    from p
    where list1_rank <= 25

    union all

    select
        'fastest_growing',
        'Fastest growing 2019 to 2025 (NYC estimate), jobs added',
        2,
        list2_rank,
        nyc_change_2019_2025,
        'jobs added 2019-2025 (NYC estimate)',
        nyc_pct_change_2019_2025,
        'percent change 2019-2025',
        p.*
    from p
    where list2_rank <= 25

    union all

    select
        'fastest_growing_pct',
        'Fastest growing 2019 to 2025 (NYC estimate), percent',
        3,
        list2_rank_pct,
        nyc_pct_change_2019_2025,
        'percent change 2019-2025 (NYC estimate)',
        nyc_change_2019_2025,
        'jobs added 2019-2025',
        p.*
    from p
    where list2_rank_pct <= 25

    union all

    select
        'other_jobs_most_openings',
        'Other jobs in this area (All Other codes), by openings',
        4,
        other_list_rank,
        annual_openings_avg,
        'openings a year (2022-2032 average)',
        growth_share,
        'share of openings from growth',
        p.*
    from p
    where other_list_rank is not null
)

select
    list_key,
    list_label,
    list_sort,
    rank,
    soc_code,
    soc_title,
    soc_level,
    is_all_other,
    major_code,
    major_group_title,
    entry_education,
    entry_experience,
    ranked_value,
    ranked_value_kind,
    companion_value,
    companion_kind,
    annual_openings_avg,
    growth_openings_avg,
    separation_openings_avg,
    growth_share,
    growth_share_band,
    pct_change_2022_2032,
    base_employment,
    is_imputed,
    projection_quality_flag,
    nyc_employment_2019,
    nyc_employment_2025,
    nyc_change_2019_2025,
    nyc_pct_change_2019_2025,
    metro_pct_change_2019_2025,
    split_2019,
    growth_note,
    clears_floor_1000,
    entry_wage,
    median_wage,
    entry_wage_at_floor,
    employment_prospects,
    prospects_usable,
    bls_experience_band,
    acs_young_share_band,
    onet_newcomer_band,
    ai_band,
    wording_key,
    source_key,
    source_key_nyc_estimate,
    source_key_wage,
    source_key_prospects,
    as_of
from lists
{% endcall %}
