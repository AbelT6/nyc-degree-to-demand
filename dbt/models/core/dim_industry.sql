-- core.dim_industry: NAICS 2022 sectors (+ 00 all, 99 unclassified) and the CES supersector rows,
-- straight from the hand-built seed ref/naics_sector.csv. Alias columns carry each source's own code
-- so facts join without string fixes. Combined codes (Revelio 52-53, BLS matrix 491 / 90 / 91) are
-- bridged in step 2, never rows here.

select
    industry_key,
    level,
    industry_title,
    naics_sector,
    qcew_ny_code,
    qcew_bls_code,
    ces_supersector_code,
    ces_supersector_title,
    ces_nysdol_code,
    ces_nysdol_title,
    level in ('sector', 'all', 'unclassified') as is_naics,
    sort_order,
    note
from {{ ref('naics_sector') }}
