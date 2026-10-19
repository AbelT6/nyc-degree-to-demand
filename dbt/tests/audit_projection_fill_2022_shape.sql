-- audit_projection_fill_2022 shape (plan §2b, §3): 19 groups, 24 candidates, 60 parts; f in [0, 1]; filled between
-- the collapsed published value and the residual; every hybrid code the two hybrid editions publish is a candidate
-- (so every leaf has a minor group); the 11 collapsed codes are candidates.
with a as (select * from {{ ref('audit_projection_fill_2022') }}),

hybrid_codes as (
    select distinct s.edition, s.soc_code
    from {{ source('staging', 'stg_nysdol__occupation_projections') }} as s
    where s.edition in ('2020-2030', '2022-2032')
      and not exists (select 1 from {{ ref('dim_job') }} d where d.soc_code = s.soc_code)
),

candidate_list as (
    select distinct unnest(string_to_array(candidates, ' ')) as soc_code from a
)

select 'shape' as problem, count(*)::text || ' groups, ' || sum(n_candidates)::text || ' candidates, ' || sum(n_parts)::text || ' parts'
from a
having count(*) <> 19 or sum(n_candidates) <> 24 or sum(n_parts) <> 60
union all
select 'f_out_of_range', fill_group from a where f_retained < 0 or f_retained > 1
union all
select 'filled_out_of_range', fill_group from a
where base_filled < base_collapsed_published - 1e-6 or base_filled > base_residual + 1e-6
   or base_retained < -1e-6 or projected_retained < -1e-6 or openings_retained < -1e-6
union all
select 'hybrid_code_not_candidate', h.edition || ' ' || h.soc_code
from hybrid_codes as h
where not exists (select 1 from candidate_list c where c.soc_code = h.soc_code)
union all
select 'collapsed_not_candidate', s.soc_code
from {{ source('staging', 'stg_nysdol__occupation_projections') }} as s
where s.edition = '2022-2032' and s.quality_flag = 'publisher_defect'
  and not exists (select 1 from candidate_list c where c.soc_code = s.soc_code)
