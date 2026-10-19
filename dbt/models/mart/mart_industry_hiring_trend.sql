-- mart.industry_hiring_trend: one row per year x industry (the 20 NAICS sectors plus the QWI all-industries
-- row '00'), NYC = the five boroughs summed, private UI-covered jobs, all ages (A00), 2019-2025
-- (docs/mart-plan.md §4e; explore-plan §3g industry churn; nb 40 §7b, nb 41).
-- Annual separation rate = sum of the four quarters' separations / (sum of emp_begin over the same quarters / 4),
-- on borough-quarters where both the measure and emp_begin are released (status flag 1; suppressed cells drop
-- from both sides). New-hire rate the same with hires_new. A rate is computed only when all four quarters are
-- released; 2025 Q4 separations are unpublished, so 2025 has a new-hire rate but no separation rate.
-- Bachelor's-or-higher share of hires 25+ = E4 hires_new / (E1+E2+E3+E4) hires_new over borough-quarters where
-- all four education cells are released (the E groups cover workers 25 and older; E5 = under 25).
-- D24 A, totals and parts share the rows: base filter = is_total_row (the QWI all-industries row '00') for the NYC
-- figure, or is_leaf_row (the 20 sectors) for a by-sector visual; never both in one sum. Leaves sum to the total
-- within QWI noise (tests/mart_industry_leaf_sums.sql).
{{ config(alias='industry_hiring_trend') }}

{% call mart_numeric_as_double() %}
with q as (
    select *
    from {{ ref('fct_industry_hiring_quarterly') }}
    where breakdown = 'age' and group_code = 'A00'
),

sums as (
    select
        year,
        industry_key,
        count(*)                                                                  as n_cells,
        count(distinct quarter)                                                   as quarters_in_year,
        bool_and(quarter_complete)                                                as is_complete_year,
        max(release)                                                              as release,
        -- sums over released cells of each measure
        sum(emp_begin)   filter (where emp_begin_flag = 1)                        as emp_begin_sum,
        count(distinct quarter) filter (where emp_begin_flag = 1)                 as quarters_released_emp,
        sum(hires_new)   filter (where hires_new_flag = 1)                        as hires_new,
        sum(hires_all)   filter (where hires_all_flag = 1)                        as hires_all,
        sum(separations) filter (where separations_flag = 1)                      as separations,
        -- paired cells for the rates (measure and emp_begin both released)
        sum(separations) filter (where separations_flag = 1 and emp_begin_flag = 1) as sep_paired,
        sum(emp_begin)   filter (where separations_flag = 1 and emp_begin_flag = 1) as emp_sep_paired,
        count(*)         filter (where separations_flag = 1 and emp_begin_flag = 1) as n_cells_separations,
        count(distinct quarter) filter (where separations_flag = 1 and emp_begin_flag = 1) as quarters_released_separations,
        sum(hires_new)   filter (where hires_new_flag = 1 and emp_begin_flag = 1)   as hires_paired,
        sum(emp_begin)   filter (where hires_new_flag = 1 and emp_begin_flag = 1)   as emp_hires_paired,
        count(*)         filter (where hires_new_flag = 1 and emp_begin_flag = 1)   as n_cells_hires,
        count(distinct quarter) filter (where hires_new_flag = 1 and emp_begin_flag = 1) as quarters_released_hires
    from q
    group by 1, 2
),

edu_cells as (
    select
        year, quarter, area_key, industry_key,
        sum(hires_new) filter (where group_code = 'E4')                              as hires_e4,
        sum(hires_new) filter (where group_code in ('E1', 'E2', 'E3', 'E4'))          as hires_25plus,
        count(*) filter (where group_code in ('E1', 'E2', 'E3', 'E4') and hires_new_flag = 1) as n_released
    from {{ ref('fct_industry_hiring_quarterly') }}
    where breakdown = 'education'
    group by 1, 2, 3, 4
),

edu as (
    select
        year,
        industry_key,
        sum(hires_e4)     filter (where n_released = 4) as hires_new_bachelor_plus_25plus,
        sum(hires_25plus) filter (where n_released = 4) as hires_new_25plus,
        count(*)          filter (where n_released = 4) as n_cells_education
    from edu_cells
    group by 1, 2
)

select
    s.year,
    make_date(s.year, 1, 1)                                                     as year_start,
    'nyc'                                                                       as area_key,
    s.industry_key,
    s.industry_key = '00'                                                       as is_total_row,
    s.industry_key <> '00'                                                      as is_leaf_row,
    s.n_cells,
    s.quarters_in_year,
    s.is_complete_year,
    s.quarters_released_separations,
    s.quarters_released_hires,
    s.n_cells_separations,
    s.n_cells_hires,
    s.emp_begin_sum,
    case when s.quarters_released_emp > 0
         then s.emp_begin_sum / s.quarters_released_emp end                      as emp_begin_avg,
    s.hires_new,
    s.hires_all,
    s.separations,
    case when s.quarters_released_separations = 4 and s.emp_sep_paired > 0
         then s.sep_paired / (s.emp_sep_paired / 4) end                          as separation_rate,
    case when s.quarters_released_hires = 4 and s.emp_hires_paired > 0
         then s.hires_paired / (s.emp_hires_paired / 4) end                      as new_hire_rate,
    e.hires_new_bachelor_plus_25plus,
    e.hires_new_25plus,
    case when e.hires_new_25plus > 0
         then e.hires_new_bachelor_plus_25plus / e.hires_new_25plus end          as bachelor_share_hires_25plus,
    e.n_cells_education,
    s.industry_key = '48-49' and s.year >= 2024                                 as is_series_break,
    case
        when s.industry_key = '48-49' and s.year >= 2024
            then 'An employer reclassification in 2024 Q1 added about 128,000 QWI "new hires" to Transportation and Warehousing; 2024 rates are not comparable with 2019.'
        when not s.is_complete_year
            then 'Partial year: 2025 Q4 separations are unpublished, so no separation rate is computed; hires and beginning-of-quarter jobs are published for all four quarters.'
    end                                                                         as rate_note,
    'census_qwi'                                                                as source_key,
    'Census QWI release ' || s.release || '; private UI-covered jobs, five boroughs summed, all ages; 2019-2025 (2025 Q4 separations unpublished)' as as_of
from sums s
left join edu e on e.year = s.year and e.industry_key = s.industry_key
{% endcall %}
