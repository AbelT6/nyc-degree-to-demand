-- core.fct_job_employment_nyc_est: estimated NYC jobs by occupation and year, 2019-2025 (decision D8). No source
-- publishes NYC-only employment by job by year, so the estimate is NYC's QCEW jobs by pattern sector (NYS DOL for
-- private, BLS county files for government by sector) multiplied by New York State's staffing pattern for the same
-- sector and year (BLS OEWS research estimates), summed over sectors:
--   employment_est(j, y) = sum over sectors s of employment(s, y) x share_of_sector(s, j, y).
-- Grain: year x area_key ('nyc') x soc_code, at the levels the research file publishes as "detailed" (SOC 2018
-- detailed codes, 7 broad codes such as 13-1020, and the 5 BLS aggregates dim_job keeps).
-- Plan: docs/step4-facts-plan.md §1 (second bullet), §3a, §4 item 3, §5 risks 2-3, §6.2; decisions D8, D3.
--
-- input                                        model                                  source_key
-- NYC jobs by pattern sector                   audit_nyc_employment_by_pattern_sector nysdol_qcew_annual (private) + bls_qcew_county (government)
-- NY staffing pattern by sector x job x year   audit_industry_job_pattern_annual      bls_oews_research
-- Government is filed the way the research file defines sector 99: state and local schools and hospitals inside
-- 61 / 62 (state 61 / 62 from NYS DOL's NYC file, since every BLS borough cell is suppressed), the federal Postal
-- Service inside 48-49, everything else public (92, state and local transit, ...) on the 99 "government" pattern
-- (plan §6.2 decision A; nb 09 Part C, dissimilarity 13.9 vs 16.6 for all-government-on-99). Shares sum to 1 per sector-year and the pattern-sector
-- table ties to QCEW, so the yearly sum of employment_est equals NYC's QCEW all-ownership total (within +/- 5, +/- 100
-- in 2020). Because the pattern is a state pattern applied to the city, every row carries method, the share of the
-- row that came through the 99 government pattern, and the lowest pattern coverage among its sectors; the published
-- metro count (OEWS NY metro, same year) and the NYS DOL NYC wage-table count (2025 only) sit beside it as checks.
-- Wage and salary jobs only (QCEW and OEWS exclude the self-employed), so the 2022 total runs a few percent below
-- the NYS DOL 2022-32 projection base. Values are unrounded numerics; the mart rounds and labels "estimate".

with sector_employment as (
    select year, pattern_sector, employment
    from {{ ref('audit_nyc_employment_by_pattern_sector') }}
),

pattern as (
    select year, pattern_sector, soc_code, share_of_sector, pattern_coverage
    from {{ ref('audit_industry_job_pattern_annual') }}
),

estimate as (
    select
        p.year,
        p.soc_code,
        sum(e.employment * p.share_of_sector)                                           as employment_est,
        sum(e.employment * p.share_of_sector) filter (where p.pattern_sector = '99')     as government_pattern_part,
        count(*)::integer                                                               as n_sectors_contributing,
        min(p.pattern_coverage)                                                         as pattern_coverage_min
    from pattern as p
    join sector_employment as e
        on e.year = p.year and e.pattern_sector = p.pattern_sector
    group by p.year, p.soc_code
),

metro as (
    select year, soc_code, employment
    from {{ ref('fct_job_employment_wage_annual') }}
    where area_key = 'ny_metro'
),

-- NYS DOL NYC occupational wages: one vintage, survey reference May 2025 -> attached to 2025 only.
nyc_wage_table as (
    select soc_code, employment
    from {{ ref('fct_job_wage_nyc') }}
    where area_key = 'nyc'
)

select
    x.year,
    'nyc'                                                            as area_key,
    x.soc_code,
    x.employment_est,
    'qcew_x_oews_research'                                           as method,
    case when x.employment_est > 0
         then coalesce(x.government_pattern_part, 0) / x.employment_est
         else 0 end                                                  as share_from_government_pattern,
    x.n_sectors_contributing,
    x.pattern_coverage_min,
    m.employment                                                     as metro_employment,
    case when x.year = 2025 then w.employment end                    as nyc_wage_table_employment,
    'bls_oews_research'                                              as source_key,
    'nysdol_qcew_annual'                                             as source_key_industry
from estimate as x
left join metro as m
    on m.year = x.year and m.soc_code = x.soc_code
left join nyc_wage_table as w
    on x.year = 2025 and w.soc_code = x.soc_code
