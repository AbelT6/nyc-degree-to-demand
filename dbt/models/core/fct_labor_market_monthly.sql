-- core.fct_labor_market_monthly: labor-market context series in one long table: BLS JOLTS (U.S. and New York State
-- openings, hires, separations, unemployed per opening, response rates), BLS LAUS (NYC, the five boroughs, the NY
-- metro, the state and the balance of state: labor force, employment, unemployment, rates) and NYS DOL regular UI
-- beneficiaries and benefits paid (the five boroughs and their NYC sum). 2015+ for BLS, 2001+ for UI.
-- Grain: source_key x area_key x measure_code x seasonal x year x period_type x month (19,071 rows).
-- Plan: docs/step4-facts-plan.md §3f, §4 item 18; seed ref.labor_measure gives label, unit and scale per
-- source_key x measure_code.
--
-- how a source code reaches the dimensions
--   JOLTS  state_code 00 -> 'us', 36 -> 'ny_state' via dim_area.jolts_state_code;
--          measure_code = dataelement_code || '_' || ratelevel_code (JO_L, JO_R, HI_L ...); seasonal S / U as staged
--   LAUS   area_code -> dim_area.laus_area_code (9 areas); measure_code 03-09 as published; seasonal S / U as staged
--   UI     county -> borough via dim_area.ui_county; plus 'nyc' rows = the sum of the five counties per month
--          (note says so; the source rounds counties to 100 persons / $10,000, so the sum is approximate);
--          measure_code 'beneficiaries' / 'benefit_amount_usd'; seasonal 'U' (not adjusted); period_type 'month'
--
-- Month convention: month = 1-12 for monthly rows and 0 for annual rows (BLS period M13; period_type says whether
-- the annual figure is an average or a 12-month total), so every key column is not null and the key is unique.
-- period keeps the BLS period code (M01-M13; synthesized for UI), period_date is the first of the month (null for
-- annual rows). value is as published (JOLTS levels in thousands, see the seed's scale) and null where BLS did not
-- collect it (Oct 2025 lapse in appropriations: every LAUS series, footnote X; the JOLTS unemployed-per-opening
-- ratio, footnote 9, because CPS unemployment was not collected; two U.S. response rates Aug-Sep 2025).

with areas as (
    select area_key, jolts_state_code, laus_area_code, ui_county
    from {{ ref('dim_area') }}
),

jolts as (
    select
        'bls_jt' as source_key,
        a.area_key,
        s.dataelement_code || '_' || s.ratelevel_code as measure_code,
        s.seasonal,
        s.year,
        s.period_type,
        coalesce(s.month, 0) as month,
        s.period,
        s.series_id,
        s.value::numeric as value,
        s.footnote_code,
        null::text as note,
        s.source_file
    from {{ source('staging', 'stg_bls__jolts') }} as s
    join areas as a on a.jolts_state_code = s.state_code
),

laus as (
    select
        'bls_la' as source_key,
        a.area_key,
        s.measure_code,
        s.seasonal,
        s.year,
        s.period_type,
        coalesce(s.month, 0) as month,
        s.period,
        s.series_id,
        s.value::numeric as value,
        s.footnote_code,
        null::text as note,
        s.source_file
    from {{ source('staging', 'stg_bls__laus') }} as s
    join areas as a on a.laus_area_code = s.area_code
),

ui_src as (
    select s.year, s.month, a.area_key, s.beneficiaries, s.benefit_amount_usd, s.source_file
    from {{ source('staging', 'stg_nysdol__ui_beneficiaries') }} as s
    join areas as a on a.ui_county = s.county
    where s.is_nyc
),

-- The five boroughs plus their sum, one row per measure.
ui_long as (
    select year, month, area_key, 'beneficiaries' as measure_code, beneficiaries::numeric as value, null::text as note, source_file
    from ui_src
    union all
    select year, month, area_key, 'benefit_amount_usd', benefit_amount_usd::numeric, null::text, source_file
    from ui_src
    union all
    select year, month, 'nyc', 'beneficiaries', sum(beneficiaries)::numeric,
        'sum of five counties, rounded source values', max(source_file)
    from ui_src
    group by year, month
    union all
    select year, month, 'nyc', 'benefit_amount_usd', sum(benefit_amount_usd)::numeric,
        'sum of five counties, rounded source values', max(source_file)
    from ui_src
    group by year, month
),

ui as (
    select
        'nysdol_ui_beneficiaries' as source_key,
        area_key,
        measure_code,
        'U' as seasonal,
        year,
        'month' as period_type,
        month,
        'M' || lpad(month::text, 2, '0') as period,
        null::text as series_id,
        value,
        null::text as footnote_code,
        note,
        source_file
    from ui_long
),

unioned as (
    select * from jolts
    union all
    select * from laus
    union all
    select * from ui
)

select
    source_key,
    area_key,
    measure_code,
    seasonal,
    year,
    period_type,
    month,
    period,
    case when month between 1 and 12 then make_date(year, month, 1) end as period_date,
    series_id,
    value,
    footnote_code,
    note,
    source_file
from unioned
