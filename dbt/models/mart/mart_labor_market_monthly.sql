-- mart.labor_market_monthly: one row per month x measure x seasonal flag, the context line on the overview,
-- jobs and AI pages (docs/mart-plan.md §4f): the NYC unemployment rate (BLS LAUS, measure 03), NYC people paid
-- regular UI benefits in the month (NYS DOL UI beneficiaries; the staged series is beneficiaries, not initial
-- claims), and the New York State job openings rate (BLS JOLTS, JO_R). Seasonally adjusted and unadjusted
-- series are separate rows; is_preferred_series marks the adjusted one where it exists (UI has none).
-- Monthly rows only, Jan 2015 onward (the span of dim_date).
{{ config(alias='labor_market_monthly') }}

{% call mart_numeric_as_double() %}
with picked (source_key, area_key, measure_code, measure_key, measure_label, unit) as (
    values
        ('bls_la',                  'nyc',      '03',            'nyc_unemployment_rate', 'NYC unemployment rate',                'percent'),
        ('nysdol_ui_beneficiaries', 'nyc',      'beneficiaries', 'nyc_ui_beneficiaries',  'NYC people paid UI benefits (month)',  'persons'),
        ('bls_jt',                  'ny_state', 'JO_R',          'ny_job_openings_rate',  'New York State job openings rate',     'percent')
),

rows_ as (
    select
        f.period_date                                   as month_start,
        f.year,
        f.month,
        p.measure_key,
        p.measure_label,
        p.unit,
        f.area_key,
        f.source_key,
        f.measure_code,
        f.seasonal,
        f.seasonal = 'S'                                as is_seasonally_adjusted,
        f.value,
        f.note,
        max(f.period_date) over (partition by p.measure_key, f.seasonal) as latest_month
    from {{ ref('fct_labor_market_monthly') }} f
    join picked p
      on p.source_key = f.source_key
     and p.area_key = f.area_key
     and p.measure_code = f.measure_code
    where f.period_type = 'month'
      and f.year >= 2015
),

flags as (
    select
        r.*,
        bool_or(is_seasonally_adjusted) over (partition by measure_key) as has_sa
    from rows_ r
)

select
    month_start,
    year,
    month,
    measure_key,
    measure_label,
    unit,
    area_key,
    measure_code,
    seasonal,
    is_seasonally_adjusted,
    (is_seasonally_adjusted or not has_sa)      as is_preferred_series,
    value,
    month_start = latest_month                  as is_latest_month,
    note,
    source_key,
    case source_key
        when 'bls_la' then 'BLS LAUS, NYC, monthly through ' || to_char(latest_month, 'Mon YYYY')
        when 'bls_jt' then 'BLS JOLTS, New York State, monthly through ' || to_char(latest_month, 'Mon YYYY')
        else 'NYS DOL UI beneficiaries, NYC, monthly through ' || to_char(latest_month, 'Mon YYYY')
    end                                         as as_of
from flags
{% endcall %}
