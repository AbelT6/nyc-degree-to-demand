-- dim_major_award.link_status agrees with dim_major.cip_soc_status and with the bridge: linked or dispersed iff the
-- major x level has bridge rows (dispersed = bachelor's rows the ACS test rejects, D20; the split is tested in
-- assert_dispersed_status_rule); transfer_pathway iff it has crosswalk links and none passes; not_in_crosswalk iff it
-- has no links, which is exactly the majors NCES lists with no job (no_job_link) or does not list (not_in_crosswalk).
-- n_links is the same at both levels (the crosswalk has no level) and equals the major's link count in staging, after
-- D57 replaces an unrated detailed code by its rated BLS group (two parts of one group count once); recomputed here
-- from staging and the code bridge, not from the model.
with rated_group as (
    select p.soc_code as part_code, g.soc_code as group_code
    from {{ ref('bridge_job_code') }} as p
    join {{ ref('dim_job') }} as g on g.soc_code = p.source_code and g.soc_level in ('broad', 'bls_aggregate')
    join {{ ref('dim_job') }} as j on j.soc_code = p.soc_code
    where p.code_system = 'group_parts' and g.entry_education is not null and j.entry_education is null
),

staging_links as (
    select s.cip_code, count(distinct coalesce(r.group_code, s.soc_code)) as n
    from {{ source('staging', 'stg_nces__cip_soc') }} as s
    left join rated_group as r on r.part_code = s.soc_code
    where s.link_type = 'link'
    group by s.cip_code
),

d as (
    select
        d.*,
        exists (select 1 from {{ ref('bridge_major_job') }} b
                where b.cip_code = d.cip_code and b.award_level = d.award_level) as in_bridge,
        coalesce(s.n, 0) as staging_links
    from {{ ref('dim_major_award') }} as d
    left join staging_links as s on s.cip_code = d.cip_code
)
select cip_code, award_level, link_status, cip_soc_status, n_links, n_pass_15, in_bridge
from d
where (link_status in ('linked', 'dispersed')) <> in_bridge
   or (link_status in ('linked', 'dispersed')) <> (n_pass_15 > 0)
   or (link_status = 'transfer_pathway') <> (n_links > 0 and n_pass_15 = 0)
   or (link_status = 'not_in_crosswalk') <> (n_links = 0)
   or (n_links = 0) <> (cip_soc_status in ('no_job_link', 'not_in_crosswalk'))
   or n_links <> staging_links
   or n_pass_10 < n_pass_15 or n_pass_15 < n_pass_20
