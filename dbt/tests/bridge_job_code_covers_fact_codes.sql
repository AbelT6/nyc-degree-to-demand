-- Every job code in a staging fact resolves through bridge_job_code in the system its edition implies.
-- The only codes allowed to stay unmapped are the two Census-only ACS codes (military, never worked).
with fact_codes as (
    select 'soc_2018' as code_system, soc_code from {{ source('staging', 'stg_anthropic__job_exposure') }}
    union select 'soc_2018', soc_code from {{ source('staging', 'stg_bls__ep_attainment') }}
    union select 'soc_2018', soc_code from {{ source('staging', 'stg_bls__ep_entry_requirements') }}
    union select 'soc_2018', soc_code from {{ source('staging', 'stg_bls__ep_occupation_projections') }}
    union select 'soc_2018', occ_code from {{ source('staging', 'stg_bls__ind_occ_matrix') }}
    union select 'soc_2018', soc_code from {{ source('staging', 'stg_cte__soc_subcluster') }}
    union select 'soc_2018', soc_code from {{ source('staging', 'stg_eloundou__job_exposure') }}
    union select 'soc_2018', soc_code from {{ source('staging', 'stg_nces__cip_soc') }} where soc_code <> '99-9999'
    union select 'soc_2018', soc_code from {{ source('staging', 'stg_nysdol__occupation_wages') }}
    union select 'onet_soc', onet_soc_code from {{ source('staging', 'stg_onet__occupation') }}
    union select 'acs_socp', socp from {{ source('staging', 'stg_census__acs_pums_person') }} where socp is not null
    -- editions: 2010-coded series resolve through soc_2010 (then the two seed groups); hybrid-coded through soc_2018 then oews_hybrid
    union select case when soc_edition = '2010' then 'soc_2010' else 'soc_2018' end, soc_code from {{ source('staging', 'stg_nysdol__occupation_projections') }}
    union select case when soc_edition = '2010' then 'soc_2010' else 'soc_2018' end, occ_code from {{ source('staging', 'stg_bls__oews_metro_occupations') }}
    union select case when soc_vintage = '2010' then 'soc_2010' else 'soc_2018' end, occ_code from {{ source('staging', 'stg_bls__oews_research_ny') }}
),

resolved as (
    select f.code_system, f.soc_code,
        exists (select 1 from {{ ref('bridge_job_code') }} b where b.code_system = f.code_system and b.source_code = f.soc_code)
        or (f.code_system = 'soc_2010' and exists (select 1 from {{ ref('bridge_job_code') }} b where b.code_system = 'soc_2010_group' and b.source_code = f.soc_code))
        -- OEWS 2018 (2010-coded) and the hybrid years both publish a few OEWS-only codes (25-3097, 51-2098 ...)
        or (f.code_system in ('soc_2010', 'soc_2018') and exists (select 1 from {{ ref('bridge_job_code') }} b where b.code_system = 'oews_hybrid' and b.source_code = f.soc_code))
        as ok
    from fact_codes as f
)

select code_system, soc_code
from resolved
where not ok
  and not (code_system = 'acs_socp' and soc_code in ('559830', '999920'))
order by 1, 2
