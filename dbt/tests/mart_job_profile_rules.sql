-- Rule checks for mart.job_profile (explore-plan §3a, §3b, §3g): openings = growth + separations on every leaf (±1);
-- the band follows the growth share and the all-leaves cutoff; growth share and projected pct_change agree in sign
-- on every leaf (same source; nb 40: 186 of 186); list ranks only where eligible (List 1 and the Other list need a
-- leaf row, List 1 excludes All Other, List 2 needs the 1,000 floor and excludes All Other); graduates_per_opening
-- only where openings exist; churn coverage within [0, 1.0005]; every row is degree-reachable in dim_job.
with p as (
    select * from {{ ref('mart_job_profile') }}
)

select soc_code, 'openings identity off by more than 1' as problem from p
where has_projection and abs(annual_openings_avg - growth_openings_avg - separation_openings_avg) > 1
union all
select soc_code, 'band inconsistent with growth share' from p
where has_projection and growth_share_band is distinct from (
    case when growth_share < 0 then 'shrinking'
         when growth_share < all_leaves_growth_share then 'mostly replacement'
         when growth_share < 0.25 then 'mixed'
         else 'growth-led' end)
union all
select soc_code, 'growth share and pct_change disagree in sign' from p
where has_projection and sign(growth_share) <> sign(pct_change_2022_2032)
union all
select soc_code, 'list1_rank on an ineligible row' from p
where list1_rank is not null and (not has_projection or is_all_other)
union all
select soc_code, 'other_list_rank on an ineligible row' from p
where other_list_rank is not null and (not has_projection or not is_all_other)
union all
select soc_code, 'list2_rank on an ineligible row' from p
where list2_rank is not null and (not coalesce(clears_floor_1000, false) or is_all_other)
union all
select soc_code, 'eligible leaf without a list1 rank' from p
where list1_rank is null and has_projection and not is_all_other
union all
select soc_code, 'eligible floor job without a list2 rank' from p
where list2_rank is null and coalesce(clears_floor_1000, false) and not is_all_other
union all
select soc_code, 'graduates_per_opening without openings' from p
where graduates_per_opening is not null and not coalesce(annual_openings_avg > 0, false)
union all
select soc_code, 'churn coverage out of range' from p
where industry_churn_coverage is not null and (industry_churn_coverage < 0 or industry_churn_coverage > 1.0005)
union all
select p.soc_code, 'not a degree-reachable job in dim_job' from p
left join {{ ref('dim_job') }} as j on j.soc_code = p.soc_code
where j.soc_code is null or not j.is_degree_entry
