-- Ephemeral (no table): the D2 degree-level filter, evaluated once for every NCES CIP-SOC link at each of the two
-- in-scope award levels (5,694 links after D57 x 2 = 11,388 rows). Read by audit_major_job_filter (every row, the evidence)
-- and bridge_major_job (the rows passing at 15%), so the two cannot drift. Plan: docs/step2b-major-bridges-plan.md
-- §3 and §6; decisions D2, D14, D16.
--
-- A link passes at award level L when the job's BLS typical entry education equals L's label (dim_award_level.
-- bls_entry_education) OR the share of the job's workers whose highest attainment is L (BLS Table 5.3, ACS 2023-24,
-- workers 25+) is at or above the threshold: 15% is the headline, 10% and 20% the D2 sensitivity columns.
-- attainment_inexact = BLS acs_inexact: the profile is borrowed from a broader Census occupation (kept, flagged; D16).
{{ config(materialized='ephemeral') }}

with levels as (
    select award_level, bls_entry_education, bls_attainment_level
    from {{ ref('dim_award_level') }}
    where in_v1_scope
),

-- D57: NCES links majors to SOC 2018 detailed codes, but for 28 civilian codes BLS rates entry education and
-- attainment only on one of 12 group codes (29-2011 and 29-2012 -> 29-2010 Clinical Laboratory Technologists and
-- Technicians; 25-2055 and 25-2056 -> 25-2052; 13-1021..23 -> 13-1020; ...; each part has exactly one rated group). Unmapped, those links could never pass, so 4 of the
-- study's 225 jobs had no major at all and majors like Clinical/Medical Laboratory Technician read "Transfer pathway".
-- A detailed code with no BLS rating is replaced by its rated group (bridge_job_code group_parts, a broad or
-- BLS-aggregate dim_job row with an entry education); two parts of one group collapse to one link.
-- D58 (fact-check): a major the crosswalk links to only some parts of a group (Special Education -> 25-9043 Special
-- Ed teaching assistants, one of 25-9045's three parts; Art History -> 13-2022, one of 13-2020's two) counts toward the
-- group by the share of its parts it names (link_part_share, equal parts as bridge_job_code: no NYC or metro split of
-- these groups is published). bridge_major_job scales its openings weight by it; mart_dim_major's kind vote too.
rated_group as (
    select p.soc_code as part_code, g.soc_code as group_code, p.n_parts
    from {{ ref('bridge_job_code') }} as p
    join {{ ref('dim_job') }} as g on g.soc_code = p.source_code
    join {{ ref('dim_job') }} as d on d.soc_code = p.soc_code
    where p.code_system = 'group_parts'
      and g.soc_level in ('broad', 'bls_aggregate')
      and g.entry_education is not null
      and d.entry_education is null
),

links as (
    select
        l.cip_code,
        coalesce(r.group_code, l.soc_code) as soc_code,
        case when bool_or(r.group_code is not null)
             then count(distinct l.soc_code)::numeric / max(r.n_parts) else 1.0 end as link_part_share
    from {{ source('staging', 'stg_nces__cip_soc') }} as l
    left join rated_group as r on r.part_code = l.soc_code
    where l.link_type = 'link'
    group by 1, 2
),

jobs as (
    select soc_code, entry_education
    from {{ ref('dim_job') }}
),

attainment as (
    select soc_code, attainment_level, pct_of_workers::numeric as pct_of_workers, acs_inexact
    from {{ source('staging', 'stg_bls__ep_attainment') }}
),

scored as (
    select
        l.cip_code,
        v.award_level,
        l.soc_code,
        l.link_part_share,
        j.entry_education,
        coalesce(j.entry_education = v.bls_entry_education, false) as entry_match,
        a.pct_of_workers as attainment_pct,
        a.acs_inexact as attainment_inexact,
        coalesce(a.pct_of_workers >= 10, false) as attainment_10,
        coalesce(a.pct_of_workers >= 15, false) as attainment_15,
        coalesce(a.pct_of_workers >= 20, false) as attainment_20
    from links as l
    cross join levels as v
    join jobs as j on j.soc_code = l.soc_code
    left join attainment as a
        on a.soc_code = l.soc_code
       and a.attainment_level = v.bls_attainment_level
)

select
    cip_code,
    award_level,
    soc_code,
    entry_education,
    entry_match,
    attainment_pct,
    attainment_inexact,
    entry_match or attainment_10 as passes_filter_10,
    entry_match or attainment_15 as passes_filter_15,
    entry_match or attainment_20 as passes_filter_20,
    case
        when entry_match and attainment_15 then 'both'
        when entry_match then 'entry'
        when attainment_15 then 'attainment'
    end as pass_basis,
    link_part_share
from scored
