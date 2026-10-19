-- mart.overview_kpi: the overview page's framed numbers, one row per KPI (docs/mart-plan.md §4g).
-- Every value is computed from the mart views (never from a notebook), with its comparison and the
-- page it links to. Awards KPIs (2024 awards and change since 2019, share of linked bachelor's awards
-- in High-exposure majors) read major_supply_demand.
-- D24 E: every number in a note is built from the same CTEs as the values (no typed-in numbers); pct() and cnt()
-- below are the two formats (signed one-decimal percent with a true minus sign; thousands-separated count).
-- The two NYC job KPIs carry the estimate's own source_key (bls_oews_research, as on job_employment_trend's nyc rows);
-- their notes name the QCEW half of the D8 estimate.
{{ config(alias='overview_kpi') }}

{% call mart_numeric_as_double() %}
with nyc as (
    select
        is_degree_entry,
        sum(nyc_employment_est) filter (where year = 2019) as e2019,
        sum(nyc_employment_est) filter (where year = 2025) as e2025
    from {{ ref('mart_job_employment_trend') }}
    where area_key = 'nyc' and in_both_end_years  -- D37: the same jobs at both ends
    group by 1
),

leaves as (
    select
        sum(annual_openings_avg) as openings,
        sum(growth_openings_avg) as growth,
        sum(separation_openings_avg) as separations
    from {{ ref('mart_job_profile') }}
    where has_projection and annual_openings_avg is not null
),

pay as (
    select
        -- D58 (fact-check): the middle of every study job with an entry wage (208 of 225), the 4 BLS group codes
        -- included (was the 204 detailed codes: $69,556 -> $69,491)
        percentile_cont(0.5) within group (order by entry_wage) as entry_wage_median,
        sum(metro_real_p50_change_2019_2025 * metro_oews_employment_2025)
            filter (where soc_level = 'detailed' and metro_oews_employment_2025 is not null and metro_real_p25_change_2019_2025 is not null and metro_real_p50_change_2019_2025 is not null)
            / sum(metro_oews_employment_2025)
            filter (where soc_level = 'detailed' and metro_oews_employment_2025 is not null and metro_real_p25_change_2019_2025 is not null and metro_real_p50_change_2019_2025 is not null)
            as real_p50_change_degree
    from {{ ref('mart_job_profile') }}
),

all_jobs_pay as (
    -- every detailed metro job with a real p50 in both years, weighted by 2025 employment (nb 43 §3: all jobs +2.5%)
    select
        sum((b.annual_p50_2025usd / a.annual_p50_2025usd - 1) * b.metro_employment) / sum(b.metro_employment) as real_p50_change_all
    from {{ ref('mart_job_employment_trend') }} a
    join {{ ref('mart_job_employment_trend') }} b
        on b.soc_code = a.soc_code and b.area_key = a.area_key and b.year = 2025
    where a.area_key = 'ny_metro' and a.year = 2019 and a.soc_level = 'detailed'
        and a.annual_p50_2025usd is not null and b.annual_p50_2025usd is not null and b.metro_employment is not null
),

postings as (
    select
        sum(active_postings_sa) filter (where month_start = date '2022-06-01') as p_jun2022,
        sum(active_postings_sa) filter (where month_start = date '2025-08-01') as p_aug2025,
        sum(active_postings_sa) filter (where is_latest_revelio_month) as p_latest,
        max(month_start) filter (where is_latest_revelio_month) as latest_month
    from {{ ref('mart_postings_monthly') }}
    where source_key = 'revelio_rpls' and area_key = 'ny_state'
),

health as (
    select change_2019_2025, pct_change_2019_2025, share_of_nyc_private_2025
    from {{ ref('mart_industry_profile') }}
    where industry_key = '62'
),

private_total as (
    -- NYC private payroll jobs (QCEW, all industries) for the health-care note
    select
        max(employment) filter (where year = 2025) - max(employment) filter (where year = 2019) as change_2019_2025
    from {{ ref('mart_industry_employment_trend') }}
    where area_key = 'nyc' and ownership = 'Private' and is_total_row
),

awards as (
    -- first-major associate's + bachelor's awards on every major (reconciles to the IPEDS fact, nb 42)
    select
        sum(awards_2024_nyc)  as a2024_nyc,
        sum(awards_2019_nyc)  as a2019_nyc,
        sum(awards_2024_cuny) as a2024_cuny,
        sum(awards_2019_cuny) as a2019_cuny,
        sum(awards_2024_cuny) filter (where award_level = 3) as a2024_cuny_assoc,
        sum(awards_2019_cuny) filter (where award_level = 3) as a2019_cuny_assoc
    from {{ ref('mart_major_supply_demand') }}
),

high_exposure as (
    -- linked bachelor's majors only (they carry the bridge exposure, D7 band); nb 46: 18%
    select
        sum(awards_2024_nyc)  filter (where ai_band = 'High')::numeric / sum(awards_2024_nyc)  as share_nyc,
        sum(awards_2024_cuny) filter (where ai_band = 'High')::numeric / sum(awards_2024_cuny) as share_cuny
    from {{ ref('mart_major_supply_demand') }}
    where link_status = 'linked' and award_level = 5
),

bls_ai as (
    -- D50 item 1: share of degree-level openings in jobs BLS rates High or Very high (relative AI exposure, 2025-35)
    select
        sum(annual_openings_avg) filter (where bls_ai_tier_rank >= 3)::numeric / sum(annual_openings_avg) as share_degree,
        count(*) filter (where bls_ai_tier is null) as n_untiered
    from {{ ref('mart_job_profile') }}
    where annual_openings_avg is not null
),

bls_ai_less as (
    -- the yardstick: the same share for openings in jobs that usually start with less than an associate's
    -- (NYS DOL 2022-2032 leaves with a BLS tier; same source and projection). D58 (fact-check): every leaf, as the
    -- degree-level side counts them; the detailed-only filter dropped 6 group leaves with 88K openings (Home Health and
    -- Personal Care Aides 31-1120 alone 80K): 41.0% -> 34.4%. Leaves don't overlap; every one here has a tier.
    select
        sum(pr.annual_openings_avg) filter (where b.bls_ai_tier_rank >= 3)::numeric / sum(pr.annual_openings_avg) as share_less
    from {{ ref('fct_job_projection') }} as pr
    join {{ ref('dim_job') }} as j on j.soc_code = pr.soc_code
    join {{ ref('ref_bls_ai_exposure') }} as b on b.soc_code = pr.soc_code
    where pr.edition = '2022-2032' and pr.is_leaf and j.entry_education_rank <= 4
),

grad_premium as (
    -- D58 (fact-check): What we found tile 5. The pooled weighted median of full-time year-round earnings (2024 $)
    -- of NYC residents with a bachelor's only vs a graduate degree, by age band; the population of
    -- int_grad_outcome_person_cut (civilian employed, not enrolled, an occupation) and the median rule of
    -- fct_grad_outcome (smallest earnings where the cumulative weight reaches half). Replaces the ratio of
    -- workers-weighted means of field medians (each level over its own fields), which printed 32% / 13% as "median pay".
    -- 35-64: $100,547 vs $123,424 (+22.8%); 22-34: $86,296 vs $95,459 (+10.6%).
    with p as (
        select
            case when age between 22 and 34 then '22-34' when age between 35 and 64 then '35-64' end as age_band,
            degree_level, earnings_2024usd::numeric as earn, weight::numeric as w
        from {{ source('staging', 'stg_census__acs_pums_person') }}
        where employment_status in ('1', '2') and not enrolled and socp is not null
          and usual_hours >= 35 and weeks_worked >= 50 and earnings_2024usd > 0
          and degree_level in ('bachelor', 'graduate') and age between 22 and 64
    ),
    c as (
        select age_band, degree_level, earn,
               sum(w) over (partition by age_band, degree_level order by earn rows unbounded preceding) as cum,
               sum(w) over (partition by age_band, degree_level) as tot
        from p
    ),
    med as (
        select age_band, degree_level, min(earn) filter (where cum >= tot / 2) as median_earn
        from c group by 1, 2
    )
    select
        max(median_earn) filter (where age_band = '35-64' and degree_level = 'graduate')
            / max(median_earn) filter (where age_band = '35-64' and degree_level = 'bachelor') - 1 as premium_35_64,
        max(median_earn) filter (where age_band = '22-34' and degree_level = 'graduate')
            / max(median_earn) filter (where age_band = '22-34' and degree_level = 'bachelor') - 1 as premium_22_34,
        max(median_earn) filter (where age_band = '35-64' and degree_level = 'bachelor') as bach_35_64,
        max(median_earn) filter (where age_band = '35-64' and degree_level = 'graduate') as grad_35_64
    from med
),

living as (
    select
        max(annual_usd) filter (where is_report_line)                       as mit,
        max(annual_usd) filter (where line_key = 'nyc_tcol_single_adult')   as city
    from {{ ref('ref_living_wage') }}
),

below_living as (
    -- D50 item 2: openings whose NYS DOL entry wage starts below MIT's line; denominator = openings in jobs with an entry wage
    select
        sum(p.annual_openings_avg) filter (where p.entry_wage < l.mit)::numeric
            / sum(p.annual_openings_avg) filter (where p.entry_wage is not null)                                        as share_all,
        sum(p.annual_openings_avg) filter (where p.entry_wage < l.mit and p.entry_education = 'Associate''s degree')::numeric
            / sum(p.annual_openings_avg) filter (where p.entry_wage is not null and p.entry_education = 'Associate''s degree') as share_assoc,
        sum(p.annual_openings_avg) filter (where p.entry_wage < l.mit and p.entry_education = 'Bachelor''s degree')::numeric
            / sum(p.annual_openings_avg) filter (where p.entry_wage is not null and p.entry_education = 'Bachelor''s degree') as share_bach
    from {{ ref('mart_job_profile') }} as p
    cross join living as l
),

kpis as (
    select 10 as sort_order, 'nyc_degree_jobs_2025' as kpi_key, 'NYC jobs reachable with an associate''s or bachelor''s, 2025 (estimate; jobs with a 2019 count, D37)' as kpi_label,
        'jobs' as page_key, e2025 as value, 'count' as value_format, e2019 as comparison_value, '2019' as comparison_label,
        'higher' as direction_good, 'NYC estimate (QCEW × state staffing pattern, D8); the metro series is shown beside it on the jobs page' as note,
        'bls_oews_research' as source_key
    from nyc where is_degree_entry
    union all
    select 20, 'nyc_degree_jobs_change', 'Change in degree-reachable NYC jobs, 2019 → 2025', 'jobs',
        e2025 / e2019 - 1, 'percent', (select e2025 / e2019 - 1 from nyc where not is_degree_entry), 'every other entry level',
        'higher',
        'Degree-reachable ' || replace(to_char((e2025 / e2019 - 1) * 100, 'FMSG990.0'), '-', '−') || '%' || ' vs other '
            || (select replace(to_char((e2025 / e2019 - 1) * 100, 'FMSG990.0'), '-', '−') || '%' from nyc where not is_degree_entry) || ' (D37: jobs counted in 2019 and 2025)',
        'bls_oews_research'
    from nyc where is_degree_entry
    union all
    select 30, 'openings_per_year', 'Projected openings a year in degree-reachable jobs, 2022–2032', 'jobs',
        openings, 'count', growth, 'of them from growth', 'none',
        'NYS DOL 2022-2032; openings = growth + people leaving (plan §3g)', 'nysdol_projections'
    from leaves
    union all
    select 40, 'replacement_share', 'Share of degree-reachable openings that replace people leaving', 'jobs',
        separations / openings, 'percent', growth / openings, 'from growth', 'none',
        to_char((separations / openings) * 100, 'FM990') || '%' || ' replacement: most openings in these jobs replace people leaving (nb 40 §7)', 'nysdol_projections'
    from leaves
    union all
    select 50, 'entry_wage_median', 'Median NYC entry wage across degree-reachable jobs', 'entry',
        entry_wage_median, 'usd', null, null, 'higher',
        'NYS DOL entry wage = mean of the lowest-paid third of workers, not new-graduate pay (O4)', 'nysdol_oews_regions'
    from pay
    union all
    select 60, 'real_pay_change_degree', 'Real median pay change 2019 → 2025, degree-reachable jobs (NY metro, 2025 $)', 'entry',
        real_p50_change_degree, 'percent', (select real_p50_change_all from all_jobs_pay), 'all jobs',
        'higher', 'Employment-weighted mean of each job''s real p50 change (nb 43 §3)', 'bls_oews_metro'
    from pay
    -- (sort 70, 'postings_since_aug2025', Revelio RPLS, removed for the public release: Revelio's site terms bar public use
    --  without written consent, read; the postings CTE stays for when consent is given)
    union all
    select 80, 'health_care_jobs_change', 'Health Care and Social Assistance payroll jobs added, 2019 → 2025', 'industries',
        change_2019_2025, 'count', pct_change_2019_2025, 'percent change', 'none',
        replace(to_char(change_2019_2025, 'FMSG999,999,999'), '-', '−') || ' jobs against '
            || (select replace(to_char(change_2019_2025, 'FMSG999,999,999'), '-', '−') from private_total)
            || ' for all NYC private jobs; ' || to_char((share_of_nyc_private_2025) * 100, 'FM990.0') || '%' || ' of private jobs in 2025 (nb 41)',
        'nysdol_qcew_annual'
    from health
    union all
    select 90, 'awards_2024', 'Associate''s and bachelor''s degrees awarded by NYC colleges, 2024', 'majors',
        a2024_nyc, 'count', a2024_cuny, 'of them at CUNY', 'none',
        'IPEDS completions, first majors, associate''s and bachelor''s; ' || to_char((a2019_nyc), 'FM999,999,999') || ' in 2019 (nb 42)', 'ipeds_completions'
    from awards
    union all
    select 100, 'awards_change_since_2019', 'Change in associate''s and bachelor''s awards, 2019 → 2024', 'majors',
        a2024_nyc::numeric / a2019_nyc - 1, 'percent', a2024_cuny::numeric / a2019_cuny - 1, 'CUNY', 'none',
        'All NYC colleges vs CUNY; CUNY associate''s awards '
            || case when a2024_cuny_assoc < a2019_cuny_assoc then 'fell ' else 'rose ' end
            || to_char(abs(a2024_cuny_assoc::numeric / a2019_cuny_assoc - 1) * 100, 'FM990') || '% (nb 42)', 'ipeds_completions'
    from awards
    union all
    select 110, 'high_exposure_awards_share', 'Share of linked bachelor''s awards in majors with High AI exposure, 2024', 'ai',
        share_nyc, 'percent', share_cuny, 'CUNY', 'none',
        'Majors linked to jobs; exposure is observed AI use, not job loss (D7, nb 46)', 'anthropic_ai_exposure'
    from high_exposure
    union all
    select 120, 'bls_ai_high_share', 'Share of degree-level openings a year in jobs BLS rates High or Very high for AI exposure', 'ai',
        share_degree, 'percent', (select share_less from bls_ai_less), 'jobs that need less schooling', 'none',
        'BLS relative AI exposure (2025-35, published 2026-08-27) x NYS DOL 2022-2032 openings; relative to other jobs, not a forecast (D50 item 1); '
            || n_untiered || ' degree-level rows without a tier', 'bls_ai_exposure'
    from bls_ai
    union all
    select 130, 'living_wage_line', 'Living wage, one adult, NY metro, 2026, before taxes (MIT)', 'entry',
        mit, 'usd', city, 'NYC True Cost of Living, single adult (2022 data, taxes and savings included)', 'none',
        'The report line is MIT''s (same year as the wages, pre-tax like them); the city''s line is named in the note (D50 item 2)', 'mit_living_wage'
    from living
    union all
    select 140, 'below_living_wage_share', 'Share of degree-level openings a year whose entry wage starts below the living wage (MIT)', 'entry',
        share_all, 'percent', share_assoc, 'associate''s-entry jobs', 'none',
        'NYS DOL entry wage 2025 vs MIT 2026, openings weighted; bachelor''s-entry jobs '
            || to_char(share_bach * 100, 'FM990') || '%' || ' (D50 item 2)', 'mit_living_wage'
    from below_living
    union all
    select 150, 'grad_premium_pooled', 'Graduate degree vs bachelor''s only: median full-time pay, ages 35-64 (NYC residents, ACS 2020-2024)', 'graduates',
        premium_35_64, 'percent', premium_22_34, 'ages 22-34', 'none',
        'Pooled weighted medians, 2024 $: bachelor''s only ' || to_char(bach_35_64, 'FM$999,999') || ', graduate '
            || to_char(grad_35_64, 'FM$999,999') || ' at 35-64 (D58)', 'acs_pums'
    from grad_premium
)

select
    kpi_key,
    kpi_label,
    page_key,
    value,
    value_format,
    comparison_value,
    comparison_label,
    direction_good,
    note,
    sort_order,
    source_key,
    'NYS DOL 2022-2032 projections; QCEW 2025; OEWS May 2025; NYS DOL wages 2025; IPEDS 2024; BLS AI exposure 2025-35; MIT living wage 2026' as as_of
from kpis
{% endcall %}
