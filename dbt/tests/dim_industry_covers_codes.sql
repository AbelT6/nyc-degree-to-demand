-- Every industry code a core fact will carry resolves to one dim_industry row through the key or an alias
-- column (CES codes resolve to their own CES-NN row, not to the sectors that carry the same supersector alias), except the combined codes bridge_industry (step 2) handles: Revelio 52-53 / 54-56 / 61-62 / 71-72 / 00
-- unknown, BLS matrix 491 postal / 90 / 91 government, BEA's "..." totals and its 92 government line.
with fact_codes as (
    select 'qwi' as src, naics_sector as code, 'naics_sector' as via from {{ source('staging', 'stg_census__qwi') }}
    union select 'bls_matrix', naics_sector, 'naics_sector' from {{ source('staging', 'stg_bls__ind_occ_matrix') }} where naics_sector is not null
    union select 'career_clusters', naics_sector, 'naics_sector' from {{ source('staging', 'stg_cte__naics_subcluster') }}
    union select 'bls_qcew_county', industry_code, 'qcew_bls_code' from {{ source('staging', 'stg_bls__qcew_county') }}
    union select 'nysdol_qcew', naics_code, 'qcew_ny_code' from {{ source('staging', 'stg_nysdol__qcew_annual') }} where naics_level <= 2
    union select 'nysdol_ces', supersector_code, 'ces_nysdol_code' from {{ source('staging', 'stg_nysdol__ces_monthly') }}
    union select 'revelio', naics2d_code, 'naics_sector' from {{ source('staging', 'stg_revelio__postings') }}
    union select 'bea', naics_label, 'naics_sector' from {{ source('staging', 'stg_bea__county_gdp') }}
),

bridgeable as (
    select 'revelio' as src, code from (values ('52-53'), ('54-56'), ('61-62'), ('71-72'), ('00')) as v(code)
    union all select 'bls_matrix', code from (values ('491'), ('90'), ('91')) as v(code)
    union all select 'bea', code from (values ('...'), ('92')) as v(code)
),

resolved as (
    select f.src, f.code, f.via,
        (
            select count(*) from {{ ref('dim_industry') }} as d
            where (f.via = 'naics_sector' and d.naics_sector = f.code)
               or (f.via = 'qcew_bls_code' and d.qcew_bls_code = f.code)
               or (f.via = 'qcew_ny_code' and d.qcew_ny_code = f.code)
               or (f.via = 'ces_nysdol_code' and d.industry_key = 'CES-' || f.code)
        ) as n_rows
    from fact_codes as f
    where not exists (select 1 from bridgeable as b where b.src = f.src and b.code = f.code)
)

select src, code, via, n_rows
from resolved
where n_rows <> 1
order by 1, 2
