-- The 2025 lapse in appropriations (plan §4 item 18, cards bls_laus issue 1 and bls_jolts issue 1): every LAUS
-- monthly value for Oct 2025 is null, the JOLTS unemployed-per-opening ratio (UO_R) is null for Oct 2025 in both
-- areas, and on BLS rows value is null exactly when the footnote says not collected (JOLTS 9, LAUS X).
-- The other JOLTS series were collected for Oct 2025 (46 of 48 monthly values present in staging), so only UO_R is
-- expected null; UI rows are never null.
select 'laus_oct_2025_present' as problem, count(*)::text as detail
from {{ ref('fct_labor_market_monthly') }}
where source_key = 'bls_la' and year = 2025 and month = 10 and value is not null
having count(*) > 0
union all
select 'laus_oct_2025_rows', count(*)::text
from {{ ref('fct_labor_market_monthly') }}
where source_key = 'bls_la' and year = 2025 and month = 10
having count(*) <> 58
union all
select 'jolts_uo_oct_2025_present', area_key
from {{ ref('fct_labor_market_monthly') }}
where source_key = 'bls_jt' and measure_code = 'UO_R' and year = 2025 and month = 10 and value is not null
union all
select 'bls_null_footnote_mismatch', source_key || ' ' || coalesce(series_id, '') || ' ' || year::text || ' ' || period
from {{ ref('fct_labor_market_monthly') }}
where source_key in ('bls_jt', 'bls_la')
  and (value is null) <> coalesce(footnote_code in ('9', 'X'), false)
union all
select 'ui_null_value', area_key || ' ' || year::text || ' ' || period
from {{ ref('fct_labor_market_monthly') }}
where source_key = 'nysdol_ui_beneficiaries' and value is null
