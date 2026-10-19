-- Rule checks for mart.job_escape_route (docs/explore-plan.md §3i, D22 as amended): every listed route
-- has r >= 0.75, a destination with observed exposure < 0.10 and >= 100 projected openings, a wage ratio >= 0.90,
-- 68 elements behind the correlation, closeness consistent with r (close >= 0.82, possible 0.75 to 0.82), at most
-- three routes per origin, ranks contiguous from 1; every origin is a degree-reachable High-band detailed job;
-- n_routes_listed matches the rows; r is within [-1, 1].
with v as (
    select * from {{ ref('mart_job_escape_route') }}
),

per_origin as (
    select origin_soc_code, count(*) filter (where route_rank >= 1) as n_listed, max(route_rank) as max_rank,
        max(n_routes_listed) as n_routes_listed_col
    from v
    group by origin_soc_code
)

select origin_soc_code, route_rank, 'r below 0.75 listed' as problem from v where route_rank >= 1 and r < 0.75
union all
select origin_soc_code, route_rank, 'destination exposure not below 0.10' from v where route_rank >= 1 and not (destination_exposure < 0.10)
union all
select origin_soc_code, route_rank, 'destination openings below 100' from v where route_rank >= 1 and not (destination_openings >= 100)
union all
select origin_soc_code, route_rank, 'wage ratio below 0.90' from v where route_rank >= 1 and not (wage_ratio >= 0.90)
union all
select origin_soc_code, route_rank, 'wage ratio not destination / origin' from v
where route_rank >= 1 and abs(wage_ratio - destination_median_wage / origin_median_wage) > 1e-9
union all
select origin_soc_code, route_rank, 'not 68 elements' from v where route_rank >= 1 and n_elements <> 68
union all
select origin_soc_code, route_rank, 'closeness inconsistent with r' from v
where (route_rank >= 1 and closeness <> case when r >= 0.82 then 'close' when r >= 0.75 then 'possible' else 'none' end)
    or (route_rank = 0 and (closeness <> 'none' or destination_soc_code is not null or r is not null))
union all
select origin_soc_code, route_rank, 'r out of range' from v where route_rank >= 1 and (r < -1 or r > 1 or r_knowledge < -1 or r_knowledge > 1 or r_skills < -1 or r_skills > 1)
union all
select origin_soc_code, null, 'more than three routes or ranks not contiguous' from per_origin where n_listed > 3 or (n_listed > 0 and max_rank <> n_listed)
union all
select origin_soc_code, null, 'n_routes_listed column disagrees with rows' from per_origin where n_routes_listed_col <> n_listed
union all
select v.origin_soc_code, null, 'origin not a degree-reachable High-band detailed job' from (select distinct origin_soc_code from v) as v
join {{ ref('mart_dim_job') }} as j on j.soc_code = v.origin_soc_code
where not (j.soc_level = 'detailed' and j.is_degree_entry and j.ai_band = 'High')
union all
select v.origin_soc_code, v.route_rank, 'destination is All Other or not degree-reachable' from v
join {{ ref('mart_dim_job') }} as j on j.soc_code = v.destination_soc_code
where v.route_rank >= 1 and (j.is_all_other or not j.is_degree_entry or j.soc_level <> 'detailed')
