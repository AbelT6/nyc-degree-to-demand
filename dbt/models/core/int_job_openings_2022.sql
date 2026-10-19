-- Ephemeral (no table): one NYC annual-openings figure per detailed SOC 2018 job, for the openings weight in
-- bridge_major_job (D2 rule 3). Plan: docs/step2b-major-bridges-plan.md §4; decision D13.
--
-- openings_basis, in this order:
--   published / split / imputed  the job's fct_job_projection leaf row for NYS DOL 2022-32 (quality_flag carried);
--   estimated                    D13: BLS national 2025-35 annual openings x (OEWS NY metro May 2025 employment
--                                / BLS national 2025 employment), for jobs NYS DOL does not publish for NYC;
--   none                         neither input exists (no NY metro employment row): openings 0.
{{ config(materialized='ephemeral') }}

-- D57: plus the 12 broad / BLS-aggregate codes BLS rates (entry education set), which int_major_job_filter now
-- links majors to in place of their unrated parts; all but 47-4090 have a published NYS DOL leaf row.
with jobs as (
    select soc_code
    from {{ ref('dim_job') }}
    where soc_level = 'detailed'
       or (soc_level in ('broad', 'bls_aggregate') and entry_education is not null)
),

nyc as (
    select soc_code, annual_openings_avg, quality_flag
    from {{ ref('fct_job_projection') }}
    where edition = '2022-2032' and is_leaf
),

national as (
    select
        soc_code,
        annual_openings_k::numeric * 1000  as openings_national,
        employment_2025_k::numeric * 1000  as employment_national
    from {{ source('staging', 'stg_bls__ep_occupation_projections') }}
    where occupation_type = 'Line item'
),

metro as (
    select occ_code as soc_code, employment::numeric as employment_metro
    from {{ source('staging', 'stg_bls__oews_metro_occupations') }}
    where year = 2025 and soc_edition = '2018' and occ_level = 'detailed' and employment is not null
)

select
    j.soc_code,
    case
        when p.soc_code is not null then p.annual_openings_avg
        when n.soc_code is not null and m.soc_code is not null and n.employment_national > 0
            then n.openings_national * m.employment_metro / n.employment_national
        else 0
    end as openings_nyc,
    case
        when p.soc_code is not null then p.quality_flag
        when n.soc_code is not null and m.soc_code is not null and n.employment_national > 0 then 'estimated'
        else 'none'
    end as openings_basis,
    n.openings_national,
    n.employment_national,
    m.employment_metro
from jobs as j
left join nyc as p on p.soc_code = j.soc_code
left join national as n on n.soc_code = j.soc_code
left join metro as m on m.soc_code = j.soc_code
