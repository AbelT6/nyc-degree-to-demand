-- Plan §3d: every (breakdown, group_code) on fct_industry_hiring_quarterly has a label row in seed qwi_group.
select distinct f.breakdown, f.group_code
from {{ ref('fct_industry_hiring_quarterly') }} as f
left join {{ ref('qwi_group') }} as g
    on g.breakdown = f.breakdown and g.group_code = f.group_code
where g.group_code is null
