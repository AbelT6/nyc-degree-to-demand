-- mart.job_skill_demand (page 3 build plan §4 item 5, §6; D32): grain (soc_code, rank), ranks 1..n with no gaps and at
-- most 6, shares never rising with rank, the .00 rule's counts (162 jobs, 731 rows), the job count recomputed from
-- O*NET 31.0's .00 flags, the 13-2011 tie-out (mockup v4.1), and the acronym display rule (plan §13, approved with the
-- step-4 recommendations) with the four short forms. Returns one row per failed check.
with s as (
    select * from {{ ref('mart_job_skill_demand') }}
),

flagged_jobs as (
    -- jobs whose .00 O*NET profile flags at least one in-demand product in 31.0, among the job page's jobs
    select count(distinct w.soc_code) as n
    from {{ source('staging', 'stg_onet__software') }} as w
    join {{ ref('mart_job_profile') }} as p on p.soc_code = w.soc_code
    where w.onet_soc_code = w.soc_code || '.00' and w.is_in_demand
),

expected_13_2011 as (
    select * from (values
        (1, 'Microsoft Excel', 28), (2, 'Microsoft Office', 17), (3, 'Intuit QuickBooks', 8),
        (4, 'SAP', 6), (5, 'Microsoft PowerPoint', 6), (6, 'Microsoft Outlook', 6)
    ) as v (rank, product_display, pct)
),

checks as (
    select 'grain (soc_code, rank) unique' as check_name, 0 as expected, (count(*) - count(distinct (soc_code, rank)))::int as got from s
    union all
    select 'ranks run 1..n with no gap', 0, count(*)::int
    from (select soc_code, max(rank) as mx, count(*) as n from s group by 1) as g where g.mx <> g.n
    union all
    select 'at most 6 per job', 0, count(*) filter (where rank > 6)::int from s
    union all
    select 'share never rises with rank', 0, count(*)::int
    from s as a join s as b on b.soc_code = a.soc_code and b.rank = a.rank + 1 where b.share_of_job_ads > a.share_of_job_ads
    union all
    select 'rows = 731 (.00 rule, D32)', 731, count(*)::int from s
    union all
    select 'jobs = 162 (D32)', 162, count(distinct soc_code)::int from s
    union all
    select 'jobs = jobs with a 31.0 .00 in-demand flag', (select n from flagged_jobs)::int, count(distinct soc_code)::int from s
    union all
    select 'no specialty profile rows', 0, count(*) filter (where onet_soc_code <> soc_code || '.00')::int from s
    union all
    select 'no display name ends in " software"', 0, count(*) filter (where product_display ~ ' software$')::int from s
    union all
    select 'Registered Nurses and 17-3024 show the empty state (D32)', 0,
           count(*) filter (where soc_code in ('29-1141', '17-3024'))::int from s
    union all
    select 'acronym in brackets: Structured query language (SQL) on 15 rows', 15,
           count(*) filter (where product_display = 'Structured query language (SQL)')::int from s
    union all
    select 'acronym in brackets: Amazon Web Services (AWS) on 9 rows', 9,
           count(*) filter (where product_display = 'Amazon Web Services (AWS)')::int from s
    union all
    select 'Geographic information system (GIS) on 7 rows', 7,
           count(*) filter (where product_display = 'Geographic information system (GIS)')::int from s
    union all
    select 'GIS: "(GIS) systems" only beside the plain name (19-3092, shortened to "GIS systems")', 1,
           count(*) filter (where product_display = 'GIS systems' and soc_code = '19-3092')::int from s
    union all
    select 'four short forms (wider than the job page skill cell), each keeps the full name in product', 4,
           count(*) filter (where product_display in ('VHDL simulation', 'Visual Basic for Applications (VBA)',
                                                      'GIS systems', 'Property tax management')
                              and length(product) > length(product_display))::int from s
    union all
    select 'one name once per job', 0, (count(*) - count(distinct (soc_code, product_display)))::int from s
    union all
    select 'no spelled-out acronym left without brackets', 0,
           count(*) filter (where product_display ~ '\m(SQL|AWS|HTML|CSS|LMS|EAI|VBA|BGP|GIS|VHSIC|VHDL)\M'
                              and product_display !~ '\((SQL|AWS|HTML|CSS|LMS|EAI|VBA|BGP|GIS|VHSIC|VHDL)\)'
                              and product_display not in ('VHDL simulation', 'GIS systems'))::int from s
    union all
    select 'names that only contain capitals stay as O*NET writes them', 0,
           count(*) filter (where product_display ~ '\((PowerPoint|ArcGIS|MATLAB|HRIS|ESRI|JIRA|IDE|CI|API)\)')::int from s
    union all
    select '13-2011 top 6 = mockup v4.1, product and percent', 6, count(*)::int
    from s join expected_13_2011 as e on e.rank = s.rank and e.product_display = s.product_display and e.pct = s.pct_of_job_ads
    where s.soc_code = '13-2011'
)

select * from checks where got is distinct from expected
