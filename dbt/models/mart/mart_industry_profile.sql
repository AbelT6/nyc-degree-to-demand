-- mart.industry_profile: one row per NAICS sector (20), the descriptive industry page
-- (docs/mart-plan.md §4e; nb 41 page decision: descriptive, one degree-reachable line; §3g QWI placement;
-- D3 industry -> job bridge; D18 NYC jobs; 48-49 footnote).
--   - private jobs 2019 and 2025 and the change, NYC and the five boroughs (QCEW private, NYS DOL);
--   - GDP share of the latest BEA year = sum of the five boroughs' current-dollar GDP for the sector / the five
--     boroughs' all-industry total (BEA publishes counties only; withheld borough cells are counted);
--   - degree-reachable jobs estimate = NYC private jobs 2025 x the NY May 2025 staffing-pattern share of the sector
--     summed over degree-reachable jobs (dim_job.is_degree_entry), shares renormalized over the readable
--     (non-null) shares of the sector; coverage = the readable share sum (nb 41: Prof. and Technical ~277 k, 64%);
--   - QWI 2024 and 2019 separation and new-hire rates and the bachelor's-or-higher share of hires 25+ (2024),
--     from industry_hiring_trend;
--   - CES latest month vs the same month a year earlier, through an explicit sector -> CES series map
--     (null where no NYC CES series matches: 11, 21, 92);
--   - break_note from dim_industry (48-49).
{{ config(alias='industry_profile') }}

{% call mart_numeric_as_double() %}
with sectors as (
    select industry_key, industry_title, naics_sector, sort_order, break_note
    from {{ ref('mart_dim_industry') }}
    where is_sector
),

qcew as (
    select area_key, industry_key, year, employment
    from {{ ref('fct_industry_employment_annual') }}
    where ownership = 'Private' and year in (2019, 2025)
),

jobs as (
    select
        industry_key,
        max(employment) filter (where area_key = 'nyc' and year = 2019)           as private_jobs_2019,
        max(employment) filter (where area_key = 'nyc' and year = 2025)           as private_jobs_2025,
        max(employment) filter (where area_key = 'manhattan' and year = 2025)     as jobs_2025_manhattan,
        max(employment) filter (where area_key = 'brooklyn' and year = 2025)      as jobs_2025_brooklyn,
        max(employment) filter (where area_key = 'queens' and year = 2025)        as jobs_2025_queens,
        max(employment) filter (where area_key = 'bronx' and year = 2025)         as jobs_2025_bronx,
        max(employment) filter (where area_key = 'staten_island' and year = 2025) as jobs_2025_staten_island,
        max(employment) filter (where area_key = 'manhattan' and year = 2025)
            - max(employment) filter (where area_key = 'manhattan' and year = 2019)         as change_manhattan,
        max(employment) filter (where area_key = 'brooklyn' and year = 2025)
            - max(employment) filter (where area_key = 'brooklyn' and year = 2019)          as change_brooklyn,
        max(employment) filter (where area_key = 'queens' and year = 2025)
            - max(employment) filter (where area_key = 'queens' and year = 2019)            as change_queens,
        max(employment) filter (where area_key = 'bronx' and year = 2025)
            - max(employment) filter (where area_key = 'bronx' and year = 2019)             as change_bronx,
        max(employment) filter (where area_key = 'staten_island' and year = 2025)
            - max(employment) filter (where area_key = 'staten_island' and year = 2019)     as change_staten_island
    from qcew
    group by 1
),

nyc_private_total as (
    select employment as nyc_private_jobs_2025
    from qcew
    where area_key = 'nyc' and industry_key = '00' and year = 2025
),

gdp_year as (
    select max(year) as gdp_year from {{ ref('fct_industry_gdp') }}
),

gdp as (
    select
        g.industry_key,
        g.year                                   as gdp_year,
        sum(g.gdp_current_thousands)             as gdp_current_thousands,
        count(*) filter (where g.is_withheld)    as gdp_boroughs_withheld
    from {{ ref('fct_industry_gdp') }} g
    join gdp_year y on y.gdp_year = g.year
    group by 1, 2
),

gdp_total as (
    select gdp_current_thousands as gdp_total_thousands
    from gdp
    where industry_key = '00'
),

pattern as (
    select
        b.industry_key,
        sum(b.share_of_industry)                                        as pattern_share_readable,
        sum(b.share_of_industry) filter (where j.is_degree_entry)       as pattern_share_degree_raw,
        count(*) filter (where b.share_of_industry is not null)         as n_jobs_readable,
        count(*) filter (where b.share_of_industry is not null and j.is_degree_entry) as n_degree_jobs_readable
    from {{ ref('bridge_industry_job') }} b
    join {{ ref('dim_job') }} j on j.soc_code = b.soc_code
    group by 1
),

hiring as (
    select
        industry_key,
        max(separation_rate) filter (where year = 2024)             as separation_rate_2024,
        max(separation_rate) filter (where year = 2019)             as separation_rate_2019,
        max(new_hire_rate) filter (where year = 2024)               as new_hire_rate_2024,
        max(new_hire_rate) filter (where year = 2019)               as new_hire_rate_2019,
        max(bachelor_share_hires_25plus) filter (where year = 2024) as bachelor_share_hires_25plus_2024,
        max(hires_new) filter (where year = 2024)                   as hires_new_2024,
        max(separations) filter (where year = 2024)                 as separations_2024
    from {{ ref('mart_industry_hiring_trend') }}
    group by 1
),

ces_map (industry_key, ces_series_code, ces_match_note) as (
    values
        ('22',    '43220000', null),
        ('23',    '15000000', 'CES publishes Mining, Logging and Construction as one NYC series; mining and logging are under 1,000 of its jobs'),
        ('31-33', '30000000', null),
        ('42',    '41000000', null),
        ('44-45', '42000000', null),
        ('48-49', '43400089', null),
        ('51',    '50000000', null),
        ('52',    '55520000', null),
        ('53',    '55530000', null),
        ('54',    '60540000', null),
        ('55',    '60550000', null),
        ('56',    '60560000', null),
        ('61',    '65610000', 'CES covers private schools only; public schools and CUNY sit in CES Government'),
        ('62',    '65620000', 'CES covers private providers only; public hospitals sit in CES Government'),
        ('71',    '70710000', null),
        ('72',    '70720000', null),
        ('81',    '80000000', null)
),

ces as (
    select
        m.series_code,
        m.series_title,
        m.industry_key          as ces_industry_key,
        m.month_start           as ces_latest_month,
        m.employment            as ces_employment_latest,
        m.change_12m            as ces_change_12m,
        m.pct_change_12m        as ces_pct_change_12m,
        m.pct_change_vs_2019    as ces_pct_change_vs_2019
    from {{ ref('mart_industry_employment_monthly') }} m
    where m.is_latest_month
)

select
    s.industry_key,
    s.industry_title,
    s.naics_sector,
    s.sort_order,
    -- jobs (QCEW private, NYS DOL)
    j.private_jobs_2019,
    j.private_jobs_2025,
    j.private_jobs_2025 - j.private_jobs_2019                                   as change_2019_2025,
    case when j.private_jobs_2019 > 0
         then j.private_jobs_2025 / j.private_jobs_2019 - 1 end                 as pct_change_2019_2025,
    case when t.nyc_private_jobs_2025 > 0
         then j.private_jobs_2025 / t.nyc_private_jobs_2025 end                 as share_of_nyc_private_2025,
    j.jobs_2025_manhattan,
    j.jobs_2025_brooklyn,
    j.jobs_2025_queens,
    j.jobs_2025_bronx,
    j.jobs_2025_staten_island,
    j.change_manhattan,
    j.change_brooklyn,
    j.change_queens,
    j.change_bronx,
    j.change_staten_island,
    -- output (BEA county GDP, five boroughs summed)
    g.gdp_year,
    g.gdp_current_thousands,
    case when gt.gdp_total_thousands > 0
         then g.gdp_current_thousands / gt.gdp_total_thousands end              as gdp_share,
    g.gdp_boroughs_withheld,
    -- the one degree-reachable line (D3 pattern x D18 jobs)
    p.pattern_share_readable,
    case when p.pattern_share_readable > 0
         then p.pattern_share_degree_raw / p.pattern_share_readable end          as degree_reachable_share,
    case when p.pattern_share_readable > 0
         then j.private_jobs_2025 * p.pattern_share_degree_raw / p.pattern_share_readable end as degree_reachable_jobs_est,
    p.n_jobs_readable,
    p.n_degree_jobs_readable,
    p.pattern_share_readable < 0.7                                              as pattern_coverage_low,
    -- churn (QWI)
    h.separation_rate_2024,
    h.separation_rate_2019,
    h.new_hire_rate_2024,
    h.new_hire_rate_2019,
    h.bachelor_share_hires_25plus_2024,
    h.hires_new_2024,
    h.separations_2024,
    -- now (CES)
    cm.ces_series_code,
    c.series_title                                                              as ces_series_title,
    c.ces_industry_key,
    c.ces_latest_month,
    c.ces_employment_latest,
    c.ces_change_12m,
    c.ces_pct_change_12m,
    c.ces_pct_change_vs_2019,
    cm.ces_match_note,
    s.break_note,
    -- sources
    'nysdol_qcew_annual'                                                        as source_key_jobs,
    'bea_county_gdp'                                                            as source_key_gdp,
    'bls_oews_research'                                                         as source_key_pattern,
    'census_qwi'                                                                as source_key_hiring,
    'nysdol_ces'                                                                as source_key_ces,
    'nysdol_qcew_annual, bea_county_gdp, bls_oews_research, census_qwi, nysdol_ces' as source_keys,
    'QCEW 2019 and 2025 (NYS DOL); BEA county GDP ' || gy.gdp_year
        || '; OEWS research estimates NY May 2025 (D3); Census QWI 2024 and 2019; NYS DOL CES '
        || coalesce(to_char(c.ces_latest_month, 'Mon YYYY'), 'n/a')             as as_of
from sectors s
cross join nyc_private_total t
cross join gdp_total gt
cross join gdp_year gy
left join jobs j on j.industry_key = s.industry_key
left join gdp g on g.industry_key = s.industry_key
left join pattern p on p.industry_key = s.industry_key
left join hiring h on h.industry_key = s.industry_key
left join ces_map cm on cm.industry_key = s.industry_key
left join ces c on c.series_code = cm.ces_series_code
{% endcall %}
