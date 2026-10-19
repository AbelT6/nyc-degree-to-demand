-- core.bridge_major_cluster: detailed CIP 2020 major x award level x Career Clusters sub-cluster, reached through the
-- major's passing jobs (D6: majors get clusters through their jobs). Grain: cip_code x award_level x subcluster_id
-- (966 associate's + 6,835 bachelor's = 7,801 rows).
--
-- share_openings / share_equal = the sum of the major's job weights that fall in the sub-cluster. NON-ADDITIVE: a
-- job sits in up to several sub-clusters, so a major's shares can exceed 1 by design; never sum them across
-- sub-clusters or clusters (D6). share_openings is null when the major has no openings weight.
-- Plan: docs/step2b-major-bridges-plan.md §6; decisions D2, D6, D16.

select
    b.major_award_key,
    b.cip_code,
    b.award_level,
    c.subcluster_id,
    c.cluster_id,
    c.cluster_name,
    c.subcluster_name,
    c.featured_area,
    count(*) as n_jobs,
    sum(b.weight_openings) as share_openings,
    sum(b.weight_equal) as share_equal
from {{ ref('bridge_major_job') }} as b
join {{ ref('bridge_job_cluster') }} as c on c.soc_code = b.soc_code
group by
    b.major_award_key, b.cip_code, b.award_level,
    c.subcluster_id, c.cluster_id, c.cluster_name, c.subcluster_name, c.featured_area
