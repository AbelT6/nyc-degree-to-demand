-- core.bridge_cip_2010_2020: CIP 2010 code -> CIP 2020 code, strictly 1:1 (NCES crosswalk).
-- IPEDS award years through 2019 (C2015-C2019) report CIP 2010; join them through this bridge to dim_major.
-- Deleted codes keep a row with cip_2020 null so the loss is visible (7 codes; none used by NYC colleges).

select
    cip_2010,
    cip_2010_title,
    cip_2020,
    cip_2020_title,
    action,
    cip_2010 = cip_2020 as is_unchanged
from {{ source('staging', 'stg_nces__cip_2010_2020') }}
