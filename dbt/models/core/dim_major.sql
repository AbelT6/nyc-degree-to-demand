-- core.dim_major: one row per CIP 2020 code at every level (family / series / detailed).
-- Plan: docs/step1-dimensions-plan.md §6. CIP 2010 codes (IPEDS before C2020) reach these rows
-- through bridge_cip_2010_2020 in step 2; they are never rows here.

with cip as (
    select
        cip_code,
        cip_family,
        level as cip_level,
        cip_title,
        action as cip_2020_action
    from {{ source('staging', 'stg_nces__cip_2020') }}
),

family as (
    select cip_code as cip_family, cip_title as cip_family_title
    from cip
    where cip_level = 'family'
),

series as (
    select cip_code as cip_series, cip_title as cip_series_title
    from cip
    where cip_level = 'series'
),

-- NCES CIP-SOC crosswalk: 'link' rows carry a SOC; 'major_no_job' rows say NCES found no job for the major.
job_link as (
    select
        cip_code,
        bool_or(link_type = 'link') as has_job_link,
        bool_or(link_type = 'major_no_job') as nces_no_job
    from {{ source('staging', 'stg_nces__cip_soc') }}
    group by cip_code
)

select
    c.cip_code,
    c.cip_level,
    c.cip_title,
    -- NCES ends 2,847 of 2,848 titles with a period; the clean title is for labels
    regexp_replace(c.cip_title, '\.$', '') as cip_title_clean,
    c.cip_family,
    f.cip_family_title,
    regexp_replace(f.cip_family_title, '\.$', '') as cip_family_title_clean,
    case when c.cip_level in ('series', 'detailed') then left(c.cip_code, 5) end as cip_series,
    s.cip_series_title,
    regexp_replace(s.cip_series_title, '\.$', '') as cip_series_title_clean,
    c.cip_2020_action,
    case
        when c.cip_level <> 'detailed' then null
        when j.has_job_link then 'linked'
        when j.nces_no_job then 'no_job_link'
        else 'not_in_crosswalk'
    end as cip_soc_status,
    coalesce(j.has_job_link, false) as has_job_link
from cip as c
left join family as f on f.cip_family = c.cip_family
left join series as s on s.cip_series = left(c.cip_code, 5) and c.cip_level in ('series', 'detailed')
left join job_link as j on j.cip_code = c.cip_code
