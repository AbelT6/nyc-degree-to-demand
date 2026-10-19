-- Tie-outs for the Power BI build additions (design brief §7.5 and §10.5, approved): the projected change
-- as a fraction, the growth-band sort rank, short display titles, the degree-level key and the footer short texts.
-- Returns one row per failed check.
with p as (
    select * from {{ ref('mart_job_profile') }}
),

j as (
    select * from {{ ref('mart_dim_job') }}
),

numeric_checks as (
    -- NYS DOL publishes Software Developers 2022-32 at 11.254 percent (nb 40); job_profile now stores the fraction
    select 'Software Developers projected change as a fraction' as check_name, 0.11254::numeric as expected,
           pct_change_2022_2032::numeric as got, 0.00001::numeric as tolerance from p where soc_code = '15-1252'
    union all
    select 'no projected change beyond +-500% (fraction, not percent)', 0, count(*) filter (where abs(pct_change_2022_2032) > 5), 0 from p
    union all
    select 'hottest_jobs carries the same fraction', 0,
           count(*) filter (where h.pct_change_2022_2032 is distinct from p.pct_change_2022_2032), 0
    from {{ ref('mart_hottest_jobs') }} h join p on p.soc_code = h.soc_code
    union all
    select 'band rank 4 = growth-led (15 leaves)', 15, count(*) filter (where growth_share_band_rank = 4), 0 from p where has_projection
    union all
    select 'band rank 3 = mixed (110)', 110, count(*) filter (where growth_share_band_rank = 3), 0 from p where has_projection
    union all
    select 'band rank 2 = mostly replacement (47)', 47, count(*) filter (where growth_share_band_rank = 2), 0 from p where has_projection
    union all
    select 'band rank 1 = shrinking (14)', 14, count(*) filter (where growth_share_band_rank = 1), 0 from p where has_projection
    union all
    select 'band text and rank agree', 0, count(*) filter (where (growth_share_band, growth_share_band_rank) not in
           (('shrinking', 1), ('mostly replacement', 2), ('mixed', 3), ('growth-led', 4))), 0 from p where growth_share_band is not null
    union all
    select 'degree-reachable display titles: 31 characters or fewer', 0, count(*) filter (where length(soc_short_title) > 31), 0
    from j where is_degree_entry
    union all
    select 'degree-reachable display titles are unique', 0, count(*) - count(distinct soc_short_title), 0 from j where is_degree_entry
    union all
    select 'job_profile display title = dim_job display title', 0, count(*) filter (where p.soc_short_title is distinct from j.soc_short_title), 0
    from p join j using (soc_code)
    union all
    select 'seed official_title matches core.dim_job (no mistyped code)', 0, count(*) filter (where s.official_title is distinct from c.soc_title), 0
    from {{ ref('ref_job_short_title') }} s left join {{ ref('dim_job') }} c on c.soc_code = s.soc_code
    union all
    select 'associate''s-entry jobs carry degree_level_key 3 (48)', 48, count(*) filter (where degree_level_key = 3), 0 from j
    union all
    select 'bachelor''s-entry jobs carry degree_level_key 5 (177)', 177, count(*) filter (where degree_level_key = 5), 0 from j
    union all
    select 'only degree-reachable jobs carry a degree_level_key', 0, count(*) filter (where degree_level_key is not null and not is_degree_entry), 0 from j
    union all
    select 'dim_degree_level = Associate''s (3), Bachelor''s (5)', 2,
           count(*) filter (where (degree_level_key, degree_level) in ((3, 'Associate''s'), (5, 'Bachelor''s'))), 0
    from {{ ref('mart_dim_degree_level') }}
    union all
    select 'dim_degree_level has 2 rows', 2, count(*), 0 from {{ ref('mart_dim_degree_level') }}
    union all
    select 'every major award level is in dim_degree_level', 0, count(*), 0
    from {{ ref('mart_dim_major') }} m left join {{ ref('mart_dim_degree_level') }} d on d.degree_level_key = m.award_level
    where d.degree_level_key is null
    union all
    select 'the 20 sectors have a short title of 24 characters or fewer', 20,
           count(*) filter (where length(industry_short_title) <= 24), 0
    from {{ ref('mart_dim_industry') }} where is_sector
    union all
    select 'every sector short title comes from the seed', 20, count(s.industry_key), 0
    from {{ ref('mart_dim_industry') }} d left join {{ ref('ref_industry_short_title') }} s using (industry_key) where d.is_sector
    union all
    select 'footer short texts filled for the notes on the overview and jobs pages', 0, count(*), 0
    from {{ ref('mart_footnote') }}
    where page_key in ('overview', 'jobs') and footnote_key <> 'source_label'
      and footnote_key not in ('qcew_self_employed', 'ai_exposure_observed')  -- full note only, behind "All notes"
      and coalesce(short_text, '') = ''
)

select check_name, expected, got, tolerance
from numeric_checks
where got is null or abs(got - expected) > tolerance
