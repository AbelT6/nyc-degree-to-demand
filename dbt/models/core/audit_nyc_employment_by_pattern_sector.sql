-- core.audit_nyc_employment_by_pattern_sector: NYC QCEW jobs filed into the 20 "pattern sectors" the OEWS research
-- file publishes for New York (19 NAICS sectors + 99 = government excluding state and local schools and hospitals
-- and the U.S. Postal Service), so the NY staffing patterns can be applied to NYC with government filed the same
-- way on both sides (nb 09 Part C; the first input of decision D8).
-- Grain: year (2019-2025) x pattern_sector; 20 rows a year. Kept as a table for auditing.
-- Plan: docs/step4-facts-plan.md §1 (second bullet), §2d "D8 inputs", §3a, §5 risk 3, §6.2 (decision A); D8, D3.
--
-- component                          source                                         rule
-- private_employment                 fct_industry_employment_annual, NYC, Private,  a sector's own private jobs (NYS DOL QCEW,
--                                    sector rows (source_key nysdol_qcew_annual)    source_key nysdol_qcew_annual)
-- private_unclassified_allocated     same, private sectors with no research         private 99 "unclassified" (10-24 k a year) and
--                                    pattern (99; 92 in 2025, 16 jobs)              private 92 spread over the 19 patterned sectors in
--                                                                                   proportion to their private jobs (totals conserved)
-- government_disclosed               stg_bls__qcew_county, own_code 1/2/3,          summed over the five boroughs, filed by ownership x
--                                    agglvl 74, disclosed cells                     sector: state and local 61 -> 61, 62 -> 62; FEDERAL
--                                    (source_key bls_qcew_county)                   48-49 (the Postal Service) -> 48-49; everything
--                                                                                   else (92, state/local 48-49 transit, 22, 23, 53,
--                                                                                   56, 71 ...) -> 99, the OEWS "government" pattern
-- government_from_nysdol             stg_nysdol__qcew_annual, area NYC, government  a NYC-level government x sector cell NYS DOL
--                                    ownerships, naics_level 2 (nysdol_qcew_annual) publishes replaces the BLS cell when the BLS
--                                                                                   disclosed sum is null or lower (state 61 in 2019,
--                                                                                   2024, 2025 and state 62 every year, where every BLS
--                                                                                   borough cell is suppressed; state 92 in 2025; state
--                                                                                   52 2019-21 and local 48 -> 99). Local 61 / 62 keep
--                                                                                   BLS because BLS discloses boroughs there (NYS DOL
--                                                                                   publishes local 61 at NYC level in 2019 and 2025
--                                                                                   only, 59-61 k above the BLS disclosed sum; using it
--                                                                                   would break the 61 series between years)
-- government_undisclosed_allocated   stg_bls__qcew_county, agglvl 71 totals         sum over boroughs and the three ownerships of the
--                                                                                   ownership totals minus every cell filed above (BLS
--                                                                                   disclosed or NYS DOL); lands on 99 (nb 09: +/-
--                                                                                   0.2-0.4 points of dissimilarity wherever they go)
-- employment = the five components added. BLS county government totals tie to NYS DOL within +/- 2 a year (+68 in
-- 2020 local), and the NYS DOL private sector rows add to the private total within +/- 3, so the yearly sum ties to
-- NYC "Total, All Ownerships" within +/- 5 (+/- 100 in 2020); tested. Government does not come from the fact's NYC
-- government x sector rows because 20 of those are partial sums over disclosed boroughs.
-- pattern_sector is the research file's NAICS spelling (ranges like 31-33); industry_key lands it on dim_industry
-- (99 -> GOV-OEWS through the industry_code_alias seed, oews_research system; the others are identity). NYS DOL's
-- naics_code (31, 44, 48) reaches the same spelling through dim_industry.qcew_ny_code.
-- Components are 0 where a sector has none of that kind of job (they are sums, not suppressed values).

with pattern_sector as (
    select * from (values
        ('11'), ('21'), ('22'), ('23'), ('31-33'), ('42'), ('44-45'), ('48-49'), ('51'), ('52'),
        ('53'), ('54'), ('55'), ('56'), ('61'), ('62'), ('71'), ('72'), ('81'), ('99')
    ) as v (pattern_sector)
),

years as (
    select distinct year
    from {{ ref('fct_industry_employment_annual') }}
    where area_key = 'nyc'
),

grid as (
    select y.year, p.pattern_sector
    from years as y
    cross join pattern_sector as p
),

-- Private: NYS DOL NYC sector rows (the fact keeps NAICS level 2 only; 00 is the total).
private as (
    select year, industry_key as sector, employment
    from {{ ref('fct_industry_employment_annual') }}
    where area_key = 'nyc'
      and ownership = 'Private'
      and industry_key <> '00'
      and source_key = 'nysdol_qcew_annual'
),

private_patterned as (
    select year, sector, employment
    from private
    where sector in (select pattern_sector from pattern_sector where pattern_sector <> '99')
),

-- Private jobs in sectors the research file has no private pattern for: 99 unclassified, and 92 (2025, 16 jobs).
private_pool as (
    select year, sum(employment) as pool_employment
    from private
    where sector not in (select pattern_sector from pattern_sector where pattern_sector <> '99')
    group by year
),

private_allocated as (
    select
        p.year,
        p.sector as pattern_sector,
        p.employment as private_employment,
        coalesce(l.pool_employment, 0) * p.employment / sum(p.employment) over (partition by p.year)
            as private_unclassified_allocated
    from private_patterned as p
    left join private_pool as l on l.year = p.year
),

-- Government, BLS county files: the five boroughs added per ownership x sector.
bls_cells as (
    select
        year,
        own_code,
        industry_code as sector,
        sum(emp::numeric) filter (where disclosed)    as bls_disclosed,
        count(*) filter (where not disclosed)::integer as n_undisclosed
    from {{ source('staging', 'stg_bls__qcew_county') }}
    where own_code in ('1', '2', '3')
      and agglvl_code = '74'
    group by year, own_code, industry_code
),

-- Government, NYS DOL NYC-level sector rows for the three ownerships (naics_code -> sector spelling via dim_industry).
nysdol_cells as (
    select
        s.year,
        case s.ownership
            when 'Federal Government' then '1'
            when 'State Government'   then '2'
            when 'Local Government'   then '3'
        end as own_code,
        i.industry_key as sector,
        s.employment::numeric as nysdol_employment
    from {{ source('staging', 'stg_nysdol__qcew_annual') }} as s
    join {{ ref('dim_industry') }} as i on i.qcew_ny_code = s.naics_code
    where s.area_code = 'NYC'
      and s.ownership in ('Federal Government', 'State Government', 'Local Government')
      and s.naics_level = 2
),

-- One row per ownership x sector cell either source has; decide which value files the cell.
government_cells as (
    select
        coalesce(b.year, n.year)         as year,
        coalesce(b.own_code, n.own_code) as own_code,
        coalesce(b.sector, n.sector)     as sector,
        b.bls_disclosed,
        n.nysdol_employment,
        case
            when n.nysdol_employment is null then false
            -- local 61 / 62: BLS discloses boroughs, so BLS stays (see header)
            when coalesce(b.own_code, n.own_code) = '3' and coalesce(b.sector, n.sector) in ('61', '62')
                 and b.bls_disclosed is not null then false
            when b.bls_disclosed is null then true
            when n.nysdol_employment > b.bls_disclosed then true
            else false
        end as use_nysdol
    from bls_cells as b
    full join nysdol_cells as n
        on n.year = b.year and n.own_code = b.own_code and n.sector = b.sector
),

government_filed as (
    select
        year,
        case
            when sector = '61' and own_code in ('2', '3') then '61'
            when sector = '62' and own_code in ('2', '3') then '62'
            when sector = '48-49' and own_code = '1'      then '48-49'
            else '99'
        end as pattern_sector,
        case when not use_nysdol then coalesce(bls_disclosed, 0) else 0 end as government_disclosed,
        case when use_nysdol then nysdol_employment else 0 end              as government_from_nysdol
    from government_cells
),

government_by_sector as (
    select year, pattern_sector, sum(government_disclosed) as government_disclosed, sum(government_from_nysdol) as government_from_nysdol
    from government_filed
    group by year, pattern_sector
),

government_totals as (
    select year, sum(emp::numeric) as government_total
    from {{ source('staging', 'stg_bls__qcew_county') }}
    where own_code in ('1', '2', '3')
      and agglvl_code = '71'
    group by year
),

government_undisclosed as (
    select
        t.year,
        t.government_total - coalesce(f.filed, 0) as government_undisclosed,
        c.n_undisclosed_cells
    from government_totals as t
    left join (
        select year, sum(government_disclosed + government_from_nysdol) as filed
        from government_filed
        group by year
    ) as f on f.year = t.year
    left join (
        select year, sum(n_undisclosed)::integer as n_undisclosed_cells
        from bls_cells
        group by year
    ) as c on c.year = t.year
)

select
    g.year,
    g.pattern_sector,
    coalesce(a.industry_key, g.pattern_sector)                                      as industry_key,
    coalesce(p.private_employment, 0)                                               as private_employment,
    coalesce(p.private_unclassified_allocated, 0)                                   as private_unclassified_allocated,
    coalesce(d.government_disclosed, 0)                                             as government_disclosed,
    coalesce(d.government_from_nysdol, 0)                                           as government_from_nysdol,
    case when g.pattern_sector = '99' then u.government_undisclosed else 0 end      as government_undisclosed_allocated,
    coalesce(p.private_employment, 0)
        + coalesce(p.private_unclassified_allocated, 0)
        + coalesce(d.government_disclosed, 0)
        + coalesce(d.government_from_nysdol, 0)
        + case when g.pattern_sector = '99' then u.government_undisclosed else 0 end as employment,
    case when g.pattern_sector = '99' then u.n_undisclosed_cells end                as n_government_undisclosed_cells
from grid as g
left join private_allocated as p
    on p.year = g.year and p.pattern_sector = g.pattern_sector
left join government_by_sector as d
    on d.year = g.year and d.pattern_sector = g.pattern_sector
left join government_undisclosed as u
    on u.year = g.year
left join {{ ref('industry_code_alias') }} as a
    on a.code_system = 'oews_research' and a.source_code = g.pattern_sector
