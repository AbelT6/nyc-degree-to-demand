-- mart.job_industry_mix: one row per job x sector with a readable share (docs/mart-plan.md §4b; D3; explore-plan §3g churn; D8/D18).
--   * share_of_job / share_of_industry = the D3 bridge (OEWS research estimates for New York, May 2025 headline);
--     rows where the NY cell is suppressed (share_of_job null) are not listed.
--   * nyc_jobs_in_sector_2025_est = the D8 estimate's own sector contribution for this job (NYC sector jobs 2025, D18
--     government filing, x the job's share of the sector in the same-year NY pattern); its sum over the job's sectors
--     is the job's NYC estimate in job_employment_trend (the GOV-OEWS row carries the government contribution).
--   * The sector's 2024 QWI separation and new-hire rates (2019 beside, 48-49 break note) from industry_hiring_trend;
--     GOV-OEWS and 92 have no QWI row (has_qwi_rate = false) and drop from the job's churn sentence on job_profile.
-- Rates and shares describe the sector, not the job's own turnover (QWI has no occupation).
-- industry_short_title = the bar label on the job page's employer bars (dim_industry; GOV-OEWS -> "Government").
{{ config(alias='job_industry_mix') }}

{% call mart_numeric_as_double() %}
with b as (
    select *
    from {{ ref('bridge_industry_job') }}
    where share_of_job is not null
),

jobs as (
    select soc_code, soc_level, is_degree_entry
    from {{ ref('dim_job') }}
    where soc_level in ('detailed', 'broad', 'bls_aggregate')
),

hiring as (
    select industry_key, year, separation_rate, new_hire_rate, rate_note
    from {{ ref('mart_industry_hiring_trend') }}
    where year in (2019, 2024)
),

pattern as (
    select a.industry_key, a.soc_code, a.share_of_sector, a.quality_flag as pattern_quality_flag,
        s.employment as nyc_sector_jobs_2025, a.share_of_sector * s.employment as nyc_jobs_in_sector_2025_est
    from {{ ref('audit_industry_job_pattern_annual') }} as a
    join {{ ref('audit_nyc_employment_by_pattern_sector') }} as s on s.year = a.year and s.industry_key = a.industry_key
    where a.year = 2025
)

select
    b.soc_code,
    j.soc_level,
    j.is_degree_entry,
    b.industry_key,
    i.industry_title,
    i.industry_short_title,
    b.naics_sector,
    row_number() over (partition by b.soc_code order by b.share_of_job desc, b.industry_key) as rank_in_job,
    b.share_of_job,
    b.share_of_industry,
    b.emp_ny_2025,
    b.ny_emp_prse,
    p.share_of_sector                                                       as nyc_pattern_share_2025,
    p.nyc_sector_jobs_2025,
    p.nyc_jobs_in_sector_2025_est,
    p.pattern_quality_flag,
    h24.separation_rate                                                     as separation_rate_2024,
    h24.new_hire_rate                                                       as new_hire_rate_2024,
    h19.separation_rate                                                     as separation_rate_2019,
    h19.new_hire_rate                                                       as new_hire_rate_2019,
    h24.separation_rate is not null                                         as has_qwi_rate,
    h24.rate_note,
    i.break_note,
    b.source_key_ny                                                         as source_key,
    'census_qwi'                                                            as source_key_churn,
    'nysdol_qcew_annual'                                                    as source_key_nyc_jobs,
    'OEWS research estimates for New York, May 2025 (D3); NYC sector jobs 2025 = QCEW x same-year NY pattern (D8/D18); Census QWI 2024 rates, 2019 beside' as as_of
from b
join jobs as j on j.soc_code = b.soc_code
join {{ ref('mart_dim_industry') }} as i on i.industry_key = b.industry_key
left join pattern as p on p.industry_key = b.industry_key and p.soc_code = b.soc_code
left join hiring as h24 on h24.industry_key = b.industry_key and h24.year = 2024
left join hiring as h19 on h19.industry_key = b.industry_key and h19.year = 2019
{% endcall %}
