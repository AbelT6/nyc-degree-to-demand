-- mart.overview_kpi reproduces the notebook headlines (plan §5): degree-reachable NYC jobs +16.8% vs other −1.6% on
-- the jobs with a count in both years (D37; nb 40's +18.9% / −2.1% mixed in the 10 codes split in 2021); 136,787 openings, 87% replacement (nb 40 §7); median entry wage $69,556, real p50 −1.2% vs all jobs
-- +2.5% (nb 43); NY postings −30% Jun 2022 → latest (nb 45); Health Care +206,694 (nb 41); awards 73,225 / 34,839 in 2024 vs
-- 85,375 / 46,153 in 2019 (nb 42); 18% of linked bachelor's awards in High-exposure majors (nb 46). Tolerances stated per row.
with k as (
    select * from {{ ref('mart_overview_kpi') }}
),

revelio as (
    -- independent recompute from core (not the mart view): NY State SA postings, Aug 2025 -> latest month (D21)
    select month, sum(active_postings_sa) as sa
    from {{ ref('fct_postings_revelio_monthly') }}
    where area_key = 'ny_state'
    group by month
),

checks as (
    select 'degree-reachable change 2019 -> 2025 (D37: 1,420,495 / 1,216,185)' as check_name, 0.168::numeric as expected, value::numeric as got, 0.0005::numeric as tolerance from k where kpi_key = 'nyc_degree_jobs_change'
    union all
    select 'other entry levels change (comparison; D37: 3,181,010 / 3,234,319)', -0.0165, comparison_value, 0.0005 from k where kpi_key = 'nyc_degree_jobs_change'
    union all
    select 'openings a year', 136787, value, 1 from k where kpi_key = 'openings_per_year'
    union all
    select 'replacement share', 0.869, value, 0.001 from k where kpi_key = 'replacement_share'
    union all
    select 'median entry wage (D58: all 208 study jobs with a wage; was 69,556 over the 204 detailed)', 69491, value, 1 from k where kpi_key = 'entry_wage_median'
    union all
    select 'real p50 change, degree-reachable', -0.012, value, 0.0005 from k where kpi_key = 'real_pay_change_degree'
    union all
    select 'real p50 change, all jobs (comparison)', 0.025, comparison_value, 0.005 from k where kpi_key = 'real_pay_change_degree'
    union all
    -- (the two Revelio postings checks left with the postings row: removed for the public release, data-terms.md)
    select 'no Revelio row ships', 0, (select count(*) from k where source_key = 'revelio_rpls'), 0
    union all
    select 'Health Care jobs added', 206694, value, 1 from k where kpi_key = 'health_care_jobs_change'
    union all
    select 'NYC awards 2024', 73225, value, 0 from k where kpi_key = 'awards_2024'
    union all
    select 'CUNY awards 2024 (comparison)', 34839, comparison_value, 0 from k where kpi_key = 'awards_2024'
    union all
    select 'NYC awards change 2019 -> 2024 (85,375 -> 73,225)', 73225 / 85375.0 - 1, value, 0.00005 from k where kpi_key = 'awards_change_since_2019'
    union all
    select 'CUNY awards change 2019 -> 2024 (46,153 -> 34,839)', 34839 / 46153.0 - 1, comparison_value, 0.00005 from k where kpi_key = 'awards_change_since_2019'
    union all
    select 'share of linked bachelor''s awards in High majors', 0.18, value, 0.005 from k where kpi_key = 'high_exposure_awards_share'
    union all
    select 'D24 E: notes built from the values read as the notebooks did (count of mismatches)', 0,
        (select count(*) from k join (values
            ('nyc_degree_jobs_change',   'Degree-reachable +16.8% vs other −1.6% (D37: jobs counted in 2019 and 2025)'),
            ('replacement_share',        '87% replacement: most openings in these jobs replace people leaving (nb 40 §7)'),
            ('health_care_jobs_change',  '+206,694 jobs against +157,740 for all NYC private jobs; 24.5% of private jobs in 2025 (nb 41)'),
            ('awards_2024',              'IPEDS completions, first majors, associate''s and bachelor''s; 85,375 in 2019 (nb 42)'),
            ('awards_change_since_2019', 'All NYC colleges vs CUNY; CUNY associate''s awards fell 40% (nb 42)')
        ) as e (kpi_key, note) on e.kpi_key = k.kpi_key
        where k.note is distinct from e.note), 0
    union all
    -- D50 (release): BLS AI tiers and the living-wage line, as the research pass computed them (a working script (not published), queries.sql item 2)
    select 'BLS High or Very high, degree-level openings (research: 56% + 38%)', 0.944, value, 0.001 from k where kpi_key = 'bls_ai_high_share'
    union all
    select 'BLS High or Very high, need-less openings (comparison; D58: every leaf, was 0.41 over detailed codes only)', 0.344, comparison_value, 0.001 from k where kpi_key = 'bls_ai_high_share'
    union all
    select 'MIT living wage, one adult, NY metro, 2026', 65510, value, 0 from k where kpi_key = 'living_wage_line'
    union all
    select 'NYC True Cost of Living, single adult (comparison)', 70334, comparison_value, 0 from k where kpi_key = 'living_wage_line'
    union all
    select 'openings below MIT, all 225 (about 26%)', 0.259, value, 0.001 from k where kpi_key = 'below_living_wage_share'
    union all
    select 'openings below MIT, associate''s-entry (comparison; about 80%)', 0.80, comparison_value, 0.001 from k where kpi_key = 'below_living_wage_share'
    union all
    select 'fourteen kpis (D58: grad_premium_pooled)', 14, (select count(*) from k), 0
    union all
    select 'graduate premium, pooled median, 35-64 (D58)', 0.2275, value, 0.0005 from k where kpi_key = 'grad_premium_pooled'
    union all
    select 'graduate premium, pooled median, 22-34 (D58)', 0.1062, comparison_value, 0.0005 from k where kpi_key = 'grad_premium_pooled'
    union all
    select 'one row per kpi', (select count(distinct kpi_key) from k), (select count(*) from k), 0
)

select * from checks where got is null or abs(got - expected) > tolerance
