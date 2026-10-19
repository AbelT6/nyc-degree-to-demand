-- core.bridge_industry_job: NAICS sector x SOC 2018 detailed job (decision D3).
-- Headline shares from BLS OEWS research estimates, New York State, May 2025, sector level.
-- share_of_industry: the job's share of the sector's jobs ("pick an industry -> which jobs").
-- share_of_job: the sector's share of the job's workers ("where people in this job work"; D8 uses it).
-- Suppressed cells keep their row with null shares, so shares sum to the sector's disclosed coverage, not 1.
-- share_us_2035 from the national matrix is for projections only (D3) and is labeled as such.

with ny as (
    select
        r.naics as naics_sector,
        r.occ_code as source_occ_code,
        -- 12 research codes are OEWS hybrids/aggregates; land them on dim_job through bridge_job_code
        coalesce(b.soc_code, r.occ_code) as soc_code,
        coalesce(b.weight, 1.0) as code_weight,
        r.tot_emp,
        r.emp_suppressed,
        r.emp_prse,
        r.year
    from {{ source('staging', 'stg_bls__oews_research_ny') }} as r
    left join {{ ref('bridge_job_code') }} as b
        on b.code_system = 'oews_hybrid' and b.source_code = r.occ_code
    where r.year = 2025 and r.i_group = 'sector' and r.o_group = 'detailed'
),

ny_rolled as (
    select
        naics_sector,
        soc_code,
        sum(tot_emp * code_weight) as emp_ny_2025,
        bool_or(emp_suppressed) as any_suppressed,
        max(emp_prse) as emp_prse,
        count(*) as n_source_rows
    from ny
    group by naics_sector, soc_code
),

sector_total as (
    select naics as naics_sector, sum(tot_emp) as sector_emp
    from {{ source('staging', 'stg_bls__oews_research_ny') }}
    where year = 2025 and i_group = 'sector' and o_group = 'total'
    group by naics
),

job_total as (
    select soc_code, sum(emp_ny_2025) as job_emp
    from ny_rolled
    group by soc_code
),

us as (
    select
        m.naics_sector,
        m.occ_code as soc_code,
        m.emp_2025_k as emp_us_2025_k,
        m.emp_2035_k as emp_us_2035_k,
        m.pct_of_industry_2035 / 100.0 as share_us_2035
    from {{ source('staging', 'stg_bls__ind_occ_matrix') }} as m
    where m.naics_sector is not null and m.occ_type = 'Line item'
      and m.naics_sector not in ('491', '90', '91')  -- bridged in industry_code_alias; not sectors
)

select
    coalesce(n.naics_sector, u.naics_sector) as naics_sector,
    -- the alias wins: OEWS research sector 99 is government (GOV-OEWS), not NAICS 99 Unclassified
    coalesce(a.industry_key, i.industry_key) as industry_key,
    coalesce(n.soc_code, u.soc_code) as soc_code,
    n.emp_ny_2025,
    case when n.emp_ny_2025 is not null and st.sector_emp > 0 then n.emp_ny_2025 / st.sector_emp end as share_of_industry,
    case when n.emp_ny_2025 is not null and jt.job_emp > 0 then n.emp_ny_2025 / jt.job_emp end as share_of_job,
    n.any_suppressed as ny_suppressed,
    n.emp_prse as ny_emp_prse,
    u.emp_us_2025_k,
    u.emp_us_2035_k,
    u.share_us_2035,
    n.naics_sector is not null as in_ny_research,
    u.naics_sector is not null as in_us_matrix,
    'bls_oews_research' as source_key_ny,
    'bls_ind_occ_matrix' as source_key_us
from ny_rolled as n
full outer join us as u on u.naics_sector = n.naics_sector and u.soc_code = n.soc_code
left join sector_total as st on st.naics_sector = n.naics_sector
left join job_total as jt on jt.soc_code = n.soc_code
left join {{ ref('dim_industry') }} as i on i.naics_sector = coalesce(n.naics_sector, u.naics_sector)
left join {{ ref('industry_code_alias') }} as a
    on a.code_system = 'oews_research' and a.source_code = coalesce(n.naics_sector, u.naics_sector)
