-- core.fct_postings_revelio_monthly: Revelio Labs Public Labor Statistics active job postings for New York State,
-- monthly, by SOC major group x NAICS sector (Jan 2022 -> Sep 2026). The one labeled non-government layer (D10).
-- Grain: month x area_key ('ny_state') x soc_group_code x industry_code_source (22,899 rows = staging, nothing dropped).
-- Plan: docs/step4-facts-plan.md §3f, §4 item 16, §5 risk 6; decision D10.
--
-- how a source code reaches the dimensions
--   soc2d_code   22 SOC major groups + 55 Military -> dim_job.soc_code = code || '-0000' (soc_major_code)
--                00 Unknown/Other                   -> soc_major_code null (never 00-0000, which means "all jobs")
--   naics2d_code a NAICS sector as published (11 ... 92, 99) -> dim_industry.industry_key = code
--                a Revelio combined sector (52-53, 54-56, 61-62, 71-72) -> ref.industry_code_alias (code_system
--                'revelio') -> the CES supersector row (CES-55, CES-60, CES-65, CES-70)
--                00 Unknown/Other -> industry_key null (alias weight 0; never industry 00, which means "all industries")
--   area         New York State only -> 'ny_state'
--
-- Unknown rows are kept so month totals tie to the source; the mart decides whether to show them.
-- tagging_break marks months from Aug 2025, when Revelio's job tagging changed (healthcare -33%, office/admin +21%
-- in one month; card issue 2). The window rule is a mart decision. Measures are as published (unrounded).

with src as (
    select * from {{ source('staging', 'stg_revelio__postings') }}
),

jobs as (
    select soc_code from {{ ref('dim_job') }} where soc_level = 'major'
),

industries as (
    select industry_key from {{ ref('dim_industry') }} where is_naics and industry_key <> '00'
),

alias as (
    select source_code, industry_key
    from {{ ref('industry_code_alias') }}
    where code_system = 'revelio' and weight > 0 and industry_key is not null
),

resolved as (
    select
        s.month,
        'ny_state' as area_key,
        s.soc2d_code as soc_group_code,
        s.soc2d_name as soc_group_name,
        j.soc_code as soc_major_code,
        s.naics2d_code as industry_code_source,
        s.naics2d_name as industry_name,
        coalesce(i.industry_key, a.industry_key) as industry_key,
        s.active_postings_nsa::numeric as active_postings_nsa,
        s.active_postings_sa::numeric as active_postings_sa,
        s.month >= date '2025-08-01' as tagging_break,
        'revelio_rpls' as source_key,
        s.source_file
    from src as s
    left join jobs as j on s.soc2d_code <> '00' and j.soc_code = s.soc2d_code || '-0000'
    left join industries as i on i.industry_key = s.naics2d_code
    left join alias as a on a.source_code = s.naics2d_code
)

select
    month,
    area_key,
    soc_group_code,
    soc_group_name,
    soc_major_code,
    industry_code_source,
    industry_name,
    industry_key,
    active_postings_nsa,
    active_postings_sa,
    tagging_break,
    source_key,
    source_file
from resolved
