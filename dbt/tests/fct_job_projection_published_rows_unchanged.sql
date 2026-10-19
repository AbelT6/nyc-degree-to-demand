-- Every row flagged published carries its source row's staging values exactly (all seven measures), in every
-- edition; the source row is the code in source_codes (the same code, or a 1:1 SOC 2010 rename such as
-- 15-1111 -> 15-1211). The 00-0000 total row is one of them in all four editions (plan §6.7).
select f.edition, f.soc_code
from {{ ref('fct_job_projection') }} as f
left join {{ source('staging', 'stg_nysdol__occupation_projections') }} as s
    on s.edition = f.edition and s.soc_code = f.source_codes
where f.quality_flag = 'published'
  and (s.soc_code is null
       or f.base_employment <> s.base_employment
       or f.projected_employment <> s.projected_employment
       or f.employment_change <> s.employment_change
       or f.pct_change is distinct from s.pct_change::numeric
       or f.annual_openings_avg <> s.annual_openings_avg
       or f.growth_openings_avg <> s.growth_openings_avg
       or f.separation_openings_avg <> s.separation_openings_avg
       or f.is_leaf <> s.is_leaf)
union all
select e.edition, '00-0000 missing or not published'
from (values ('2016-2026'), ('2018-2028'), ('2020-2030'), ('2022-2032')) as e (edition)
where not exists (select 1 from {{ ref('fct_job_projection') }} f
                  where f.edition = e.edition and f.soc_code = '00-0000' and f.quality_flag = 'published')
