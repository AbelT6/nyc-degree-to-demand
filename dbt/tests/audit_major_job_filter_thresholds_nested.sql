-- The pass flags nest (10% ⊇ 15% ⊇ 20%), pass_basis is set exactly on the 15% rows, and the bridge holds exactly the
-- 15% rows of the audit table (the two read one ephemeral rule; this guards the join).
select 'not_nested' as problem, cip_code || ' ' || award_level::text || ' ' || soc_code as detail
from {{ ref('audit_major_job_filter') }}
where (passes_filter_20 and not passes_filter_15) or (passes_filter_15 and not passes_filter_10)
union all
select 'pass_basis', cip_code || ' ' || award_level::text || ' ' || soc_code
from {{ ref('audit_major_job_filter') }}
where passes_filter_15 <> (pass_basis is not null)
   or (pass_basis = 'entry' and not entry_match)
   or (pass_basis = 'attainment' and (entry_match or attainment_pct < 15))
   or (pass_basis = 'both' and not (entry_match and attainment_pct >= 15))
union all
select 'bridge_without_audit_pass', b.cip_code || ' ' || b.award_level::text || ' ' || b.soc_code
from {{ ref('bridge_major_job') }} as b
left join {{ ref('audit_major_job_filter') }} as a
    on a.cip_code = b.cip_code and a.award_level = b.award_level and a.soc_code = b.soc_code
where a.soc_code is null or not a.passes_filter_15
union all
select 'audit_pass_without_bridge', a.cip_code || ' ' || a.award_level::text || ' ' || a.soc_code
from {{ ref('audit_major_job_filter') }} as a
left join {{ ref('bridge_major_job') }} as b
    on b.cip_code = a.cip_code and b.award_level = a.award_level and b.soc_code = a.soc_code
where a.passes_filter_15 and b.soc_code is null
