-- mart.postings_monthly: one row per month x series, two kinds of series side by side (docs/mart-plan.md §4f,
-- docs/explore-plan.md §3f, D10, D21):
--   * Revelio (source_key revelio_rpls, area ny_state): month x SOC major group, active postings summed over
--     the 16 sectors, seasonally adjusted and not; group_code is Revelio's two-digit code ('00' Unknown and '55'
--     Military included), soc_code the matching major-group code (null for '00'); tagging_break is the fact's
--     flag (true for every month from Aug 2025, the re-tagging), tagging_break_group marks the five groups it
--     moved (29, 00, 33, 25, 43);
--   * Indeed Hiring Lab (source_key indeed_hiring_lab, areas ny_state, ny_metro, us): the total postings index
--     (Feb 1 2020 = 100), monthly mean of the daily values, complete months only (>= 28 days), group_code 'total'.
-- Grain (source_key, area_key, group_code, month_start) is tested in tests/mart_postings_monthly_grain.sql.
{{ config(alias='postings_monthly') }}

{% call mart_numeric_as_double() %}
with latest as (
    select max(month) as latest_month
    from {{ ref('fct_postings_revelio_monthly') }}
    where area_key = 'ny_state'
),

revelio as (
    select
        p.month as month_start,
        p.source_key,
        p.area_key,
        'Revelio active postings' as series_kind,
        p.soc_group_code as group_code,
        p.soc_major_code as soc_code,
        max(p.soc_group_name) as group_name,
        sum(p.active_postings_sa) as active_postings_sa,
        sum(p.active_postings_nsa) as active_postings_nsa,
        null::numeric as index_sa,
        null::numeric as index_nsa,
        null::integer as n_days,
        count(*)::integer as n_sectors,
        bool_or(p.tagging_break) as tagging_break,
        p.soc_group_code in ('29', '00', '33', '25', '43') as tagging_break_group
    from {{ ref('fct_postings_revelio_monthly') }} as p
    where p.area_key = 'ny_state'
    group by p.month, p.source_key, p.area_key, p.soc_group_code, p.soc_major_code
),

indeed as (
    select
        date_trunc('month', i.date)::date as month_start,
        i.source_key,
        i.area_key,
        'Indeed postings index (Feb 1 2020 = 100)' as series_kind,
        'total' as group_code,
        null::text as soc_code,
        'All postings' as group_name,
        null::numeric as active_postings_sa,
        null::numeric as active_postings_nsa,
        avg(i.index_sa) as index_sa,
        avg(i.index_nsa) as index_nsa,
        count(*)::integer as n_days,
        null::integer as n_sectors,
        false as tagging_break,
        false as tagging_break_group
    from {{ ref('fct_postings_indeed_index') }} as i
    where i.measure = 'total' and not i.is_category_series and i.area_key in ('ny_state', 'ny_metro', 'us')
    group by date_trunc('month', i.date), i.source_key, i.area_key
    having count(*) >= 28
),

unioned as (
    select * from revelio
    union all
    select * from indeed
)

select
    u.*,
    u.month_start = l.latest_month as is_latest_revelio_month,
    case
        when u.source_key = 'revelio_rpls'
            then 'Revelio RPLS New York State, Jan 2022 to ' || to_char(l.latest_month, 'Mon YYYY') || ' (private estimate, not government data)'
        else 'Indeed Hiring Lab postings index, daily to ' || to_char(l.latest_month, 'Mon YYYY') || ', monthly mean (not government data)'
    end as as_of
from unioned as u
cross join latest as l
{% endcall %}
