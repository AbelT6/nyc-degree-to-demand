-- mart.job_entry_signal: one row per degree-reachable job x junior signal (3) (docs/mart-plan.md §4b; D5; nb 43 §4).
-- The three D5 estimates are shown side by side as a range, never blended (Spearman 0.13 between the ACS and O*NET
-- shares): BLS work experience in a related occupation (none / under 5 years / 5 years plus, national); ACS share of NYC
-- workers in the job aged 22-29 (MOE from replicate weights; suppressed under 30 responses, band high >= 30%);
-- O*NET newcomer share = incumbents who needed a month or less of related experience (band high >= 25%).
-- The grid is complete over the job_profile universe (221 detailed + 4 broad / aggregate degree-reachable leaves,
-- x 3 measures) so a page always has three rows: signal_status says whether the row is readable, suppressed (ACS
-- under 30 responses; O*NET suppressed by O*NET), or not available (no source row).
{{ config(alias='job_entry_signal') }}

{% call mart_numeric_as_double() %}
with jobs as (
    select soc_code
    from {{ ref('dim_job') }}
    where is_degree_entry and soc_level in ('detailed', 'broad', 'bls_aggregate')
),

measures (measure, measure_sort, measure_label, wording_key, default_source_key) as (
    values
        ('bls_experience', 1, 'Work experience in a related job typically required (BLS, national)',            'bls_experience_required',        'bls_ep_education'),
        ('acs_young_share', 2, 'Share of NYC workers in this job aged 22 to 29 (ACS)',                           'acs_share_of_workers_22_29',     'acs_pums'),
        ('onet_newcomer',   3, 'Share of workers who needed a month or less of related experience (O*NET)',      'onet_newcomer_share',            'onet')
),

grid as (
    select j.soc_code, m.*
    from jobs as j
    cross join measures as m
),

signal as (
    select *
    from {{ ref('fct_job_entry_signal') }}
)

select
    g.soc_code,
    g.measure,
    g.measure_sort,
    g.measure_label,
    g.wording_key,
    case
        when s.soc_code is null then 'not available'
        when s.suppressed then 'suppressed'
        else 'readable'
    end                                                     as signal_status,
    case when s.suppressed then null else s.value end       as value,
    case when s.suppressed then null else s.band end        as band,
    case
        when s.suppressed or s.band is null then null
        when g.measure = 'bls_experience' and s.band = 'none'          then 'no related experience required'
        when g.measure = 'bls_experience' and s.band = 'under_5_years' then 'under five years of related experience'
        when g.measure = 'bls_experience' and s.band = '5_years_plus'  then 'five years or more of related experience'
        when g.measure = 'acs_young_share' and s.band = 'high' then 'high share of young workers (30% or more)'
        when g.measure = 'acs_young_share' and s.band = 'mid'  then 'middle share of young workers'
        when g.measure = 'acs_young_share' and s.band = 'low'  then 'low share of young workers'
        when g.measure = 'onet_newcomer' and s.band = 'high'   then 'often takes newcomers (25% or more needed a month or less)'
        when g.measure = 'onet_newcomer' and s.band = 'mid'    then 'sometimes takes newcomers'
        when g.measure = 'onet_newcomer' and s.band = 'low'    then 'rarely takes newcomers'
    end                                                     as band_label,
    case when s.suppressed then null else s.moe_90 end      as moe_90,
    s.n,
    s.n_young,
    coalesce(s.suppressed, s.soc_code is null)              as suppressed,
    s.quality_flag,
    s.note,
    coalesce(s.source_key, g.default_source_key)            as source_key,
    case g.measure
        when 'bls_experience'  then 'BLS Employment Projections Table 5.4 (2025 edition), typical work experience'
        when 'acs_young_share' then 'ACS PUMS 2020-2024 5-year, NYC residents employed, share aged 22-29; 90% MOE from replicate weights; suppressed under 30 responses'
        else 'O*NET 31.0 Related Work Experience categories none / up to 1 month'
    end                                                     as as_of
from grid as g
left join signal as s on s.soc_code = g.soc_code and s.measure = g.measure
{% endcall %}
