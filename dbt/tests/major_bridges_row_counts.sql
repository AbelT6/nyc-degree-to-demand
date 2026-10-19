-- Step 2b row counts must match the prototype in docs/step2b-major-bridges-plan.md §3a and §6: bridge 449 + 3,353,
-- audit 5,723 x 2, dim_major_award 2,325 x 2, cluster bridge 966 + 6,835.
-- D57, unrated detailed codes linked through their rated BLS group: the 5,723 crosswalk links become 5,694 (29
-- links to two parts of one group collapse), so the audit is 5,694 x 2; 71 links now pass (bridge 460 + 3,413), and
-- the cluster bridge follows (977 + 6,883).
select 'bridge_major_job ' || award_level::text as problem, count(*)::text as detail
from {{ ref('bridge_major_job') }}
group by award_level
having (award_level = 3 and count(*) <> 460) or (award_level = 5 and count(*) <> 3413) or award_level not in (3, 5)
union all
select 'audit_major_job_filter', count(*)::text from {{ ref('audit_major_job_filter') }} having count(*) <> 11388
union all
select 'dim_major_award', count(*)::text from {{ ref('dim_major_award') }} having count(*) <> 4650
union all
select 'bridge_major_cluster ' || award_level::text, count(*)::text
from {{ ref('bridge_major_cluster') }}
group by award_level
having (award_level = 3 and count(*) <> 977) or (award_level = 5 and count(*) <> 6883) or award_level not in (3, 5)
