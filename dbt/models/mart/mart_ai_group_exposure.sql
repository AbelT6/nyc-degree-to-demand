-- mart.ai_group_exposure: one row per SOC major group (the 23 job-group rows of mart.dim_job; Military 55-0000
-- carries postings only, no OEWS group row). Implements docs/mart-plan.md §4f and docs/explore-plan.md §3f
-- (D7 observed exposure, D10 postings windows, D21 one-year window):
--   * exposure_observed = NY-metro OEWS May 2025 employment-weighted mean of dim_job.ai_observed_exposure over
--     the group's scored detailed jobs; exposure_beta_gpt4 (Eloundou) the same way, beside it, never blended;
--     high_share = share of the scored employment in the High band (>= 0.30); coverage = scored detailed
--     employment / the published major-group row, flagged under 85% (low_coverage);
--   * postings = Revelio New York State seasonally adjusted active postings summed over sectors per group;
--     pct_change_long = Jun 2022 -> latest month; pct_change_1y = Aug 2025 -> latest ("since the Aug 2025
--     data break", the headline, D21); pct_change_1y_jun = Jun 2025 -> latest (the D10 sensitivity);
--     tagging_break_group marks the five groups the Aug 2025 re-tagging moved (29, 00, 33, 25, 43);
--   * indeed_* = the U.S. Indeed Hiring Lab index change over the same months, monthly mean of the daily
--     seasonally adjusted category index, each category mapped to one group by ref_indeed_category_soc_group,
--     unweighted mean over the group's categories (the index has no counts to weight with).
-- The employment-weighted Pearson across the 22 civilian groups is a singular test
-- (tests/mart_ai_group_exposure_tieout.sql), not a column; in_correlation marks the rows it uses.
{{ config(alias='ai_group_exposure') }}

{% call mart_numeric_as_double() %}
with groups as (
    select soc_code, left(soc_code, 2) as soc_group_code
    from {{ ref('mart_dim_job') }}
    where job_kind = 'job group'
),

detailed as (
    select j.major_code, e.employment, j.ai_observed_exposure, j.ai_beta_gpt4, j.ai_band
    from {{ ref('fct_job_employment_wage_annual') }} as e
    join {{ ref('dim_job') }} as j on j.soc_code = e.soc_code
    where e.area_key = 'ny_metro' and e.year = 2025 and e.occ_level = 'detailed'
),

exposure as (
    select
        major_code,
        sum(employment) filter (where ai_observed_exposure is not null) as emp_scored,
        sum(employment * ai_observed_exposure) filter (where ai_observed_exposure is not null)
            / nullif(sum(employment) filter (where ai_observed_exposure is not null), 0) as exposure_observed,
        sum(employment * ai_beta_gpt4) filter (where ai_beta_gpt4 is not null)
            / nullif(sum(employment) filter (where ai_beta_gpt4 is not null), 0) as exposure_beta_gpt4,
        coalesce(sum(employment) filter (where ai_band = 'High'), 0)
            / nullif(sum(employment) filter (where ai_observed_exposure is not null), 0) as high_share
    from detailed
    group by major_code
),

group_emp as (
    select soc_code, employment as emp_metro_2025
    from {{ ref('fct_job_employment_wage_annual') }}
    where area_key = 'ny_metro' and year = 2025 and occ_level = 'major'
),

windows as (
    select
        date '2022-06-01' as long_start,
        date '2025-08-01' as one_year_start,
        date '2025-06-01' as sensitivity_start,
        max(month) as latest_month
    from {{ ref('fct_postings_revelio_monthly') }}
    where area_key = 'ny_state'
),

postings as (
    select
        p.soc_group_code,
        sum(p.active_postings_sa) filter (where p.month = w.long_start) as postings_jun2022,
        sum(p.active_postings_sa) filter (where p.month = w.sensitivity_start) as postings_jun2025,
        sum(p.active_postings_sa) filter (where p.month = w.one_year_start) as postings_aug2025,
        sum(p.active_postings_sa) filter (where p.month = w.latest_month) as postings_latest
    from {{ ref('fct_postings_revelio_monthly') }} as p
    cross join windows as w
    where p.area_key = 'ny_state'
    group by p.soc_group_code
),

indeed_monthly as (
    select category, date_trunc('month', date)::date as month_start, avg(index_sa) as index_sa
    from {{ ref('fct_postings_indeed_index') }}
    where area_key = 'us' and measure = 'total' and is_category_series
    group by category, date_trunc('month', date)
    having count(*) >= 28
),

indeed_category as (
    select
        m.category,
        max(m.index_sa) filter (where m.month_start = w.latest_month)
            / nullif(max(m.index_sa) filter (where m.month_start = w.long_start), 0) - 1 as chg_long,
        max(m.index_sa) filter (where m.month_start = w.latest_month)
            / nullif(max(m.index_sa) filter (where m.month_start = w.one_year_start), 0) - 1 as chg_1y,
        max(m.index_sa) filter (where m.month_start = w.latest_month)
            / nullif(max(m.index_sa) filter (where m.month_start = w.sensitivity_start), 0) - 1 as chg_1y_jun
    from indeed_monthly as m
    cross join windows as w
    group by m.category
),

indeed_group as (
    select
        s.soc_major_code,
        avg(c.chg_long) as indeed_pct_change_long,
        avg(c.chg_1y) as indeed_pct_change_1y,
        avg(c.chg_1y_jun) as indeed_pct_change_1y_jun,
        count(*) as indeed_n_categories,
        count(*) filter (where s.map_flag = 'split') as indeed_n_split_categories
    from {{ ref('ref_indeed_category_soc_group') }} as s
    join indeed_category as c on c.category = s.category
    group by s.soc_major_code
)

select
    g.soc_code,
    g.soc_group_code,
    x.exposure_observed,
    x.exposure_beta_gpt4,
    x.high_share,
    ge.emp_metro_2025,
    x.emp_scored,
    x.emp_scored / nullif(ge.emp_metro_2025, 0) as coverage,
    coalesce(x.emp_scored / nullif(ge.emp_metro_2025, 0) < 0.85, true) as low_coverage,
    p.postings_jun2022,
    p.postings_jun2025,
    p.postings_aug2025,
    p.postings_latest,
    p.postings_latest / nullif(p.postings_jun2022, 0) - 1 as pct_change_long,
    p.postings_latest / nullif(p.postings_aug2025, 0) - 1 as pct_change_1y,
    p.postings_latest / nullif(p.postings_jun2025, 0) - 1 as pct_change_1y_jun,
    g.soc_group_code in ('29', '00', '33', '25', '43') as tagging_break_group,
    i.indeed_pct_change_long,
    i.indeed_pct_change_1y,
    i.indeed_pct_change_1y_jun,
    coalesce(i.indeed_n_categories, 0) as indeed_n_categories,
    coalesce(i.indeed_n_split_categories, 0) as indeed_n_split_categories,
    x.exposure_observed is not null and ge.emp_metro_2025 is not null
        and p.postings_latest is not null and g.soc_group_code <> '55' as in_correlation,
    w.long_start,
    w.one_year_start,
    w.sensitivity_start,
    w.latest_month,
    to_char(w.long_start, 'Mon YYYY') || ' to ' || to_char(w.latest_month, 'Mon YYYY') as window_long_label,
    'since the Aug 2025 data break (' || to_char(w.one_year_start, 'Mon YYYY') || ' to '
        || to_char(w.latest_month, 'Mon YYYY') || ')' as window_1y_label,
    'since_aug_2025_data_break' as wording_key,
    'revelio_rpls' as source_key,
    'anthropic_ai_exposure' as source_key_exposure,
    'bls_oews_metro' as source_key_employment,
    'indeed_hiring_lab' as source_key_indeed,
    'Anthropic observed exposure (Mar 2026) weighted by OEWS NY metro May 2025; Revelio RPLS New York State Jan 2022 to '
        || to_char(w.latest_month, 'Mon YYYY') || '; Indeed Hiring Lab U.S. index to the same month' as as_of
from groups as g
cross join windows as w
left join exposure as x on x.major_code = g.soc_code
left join group_emp as ge on ge.soc_code = g.soc_code
left join postings as p on p.soc_group_code = g.soc_group_code
left join indeed_group as i on i.soc_major_code = g.soc_code
{% endcall %}
