-- mart.dim_date: Power BI's date table at month grain, Jan 2015 - Dec 2026 (the span of every mart time
-- series: IPEDS 2015-2024, QCEW/OEWS 2019-2025, Revelio 2022-01 - 2026-09, CES/LAUS to 2026).
-- Annual facts carry year_start (Jan 1) as their date key; quarterly facts the first day of the quarter
-- (Microsoft "relate higher grain facts": store the first date of the period).
-- is_latest_complete_year = 2025, the last year of the 2019-2025 history span (QCEW, OEWS, NYS DOL wages, CES, LAUS).
-- Sources that end earlier (IPEDS, QWI, BEA, ACS: 2024) are not flagged here; their views carry their own as_of.
{{ config(alias='dim_date') }}

with months as (
    select d::date as month_start
    from generate_series(date '2015-01-01', date '2026-12-01', interval '1 month') as s(d)
)

select
    month_start as date_key,
    extract(year from month_start)::int as year,
    extract(quarter from month_start)::int as quarter,
    extract(month from month_start)::int as month,
    to_char(month_start, 'Mon YYYY') as month_label,
    to_char(month_start, 'YYYY-MM') as year_month,
    make_date(extract(year from month_start)::int, 1, 1) as year_start,
    make_date(extract(year from month_start)::int, (extract(quarter from month_start)::int - 1) * 3 + 1, 1) as quarter_start,
    extract(year from month_start)::int || ' Q' || extract(quarter from month_start)::int as quarter_label,
    extract(year from month_start)::int between 2019 and 2025 as is_history_year,
    extract(year from month_start)::int = 2019 as is_baseline_year,
    extract(year from month_start)::int = 2025 as is_latest_complete_year
from months
