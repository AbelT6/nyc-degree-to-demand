-- Trace guard (plan §4 item 7): Software Developers 15-1252 rate the transferable skill Programming (O*NET element
-- 2.B.3.e; the plan wrote 2.B.3.b, which is Technology Design) at Importance >= 4 on the published .00 record.
select soc_code, element_id, element_name, scale, value, rollup_rule
from {{ ref('fct_job_skill') }}
where soc_code = '15-1252' and element_id = '2.B.3.e' and scale = 'IM'
  and not (element_name = 'Programming' and value >= 4 and rollup_rule = 'onet_base')
union all
select '15-1252', '2.B.3.e', 'missing', 'IM', null, null
where not exists (
    select 1 from {{ ref('fct_job_skill') }}
    where soc_code = '15-1252' and element_id = '2.B.3.e' and scale = 'IM'
)
