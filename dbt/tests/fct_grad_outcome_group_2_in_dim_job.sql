-- group_2 is a dim_job code on the two SOC cuts (plan §4 generic relationships; singular because the column also
-- carries the literals 'all', linked, not_linked, job_not_detailed on the other cuts). field_x_soc_major codes must be
-- major groups; field_x_linked and field_total carry only their literals.
select f.cut, f.group_2, count(*) as n
from {{ ref('fct_grad_outcome') }} as f
left join {{ ref('dim_job') }} as j on j.soc_code = f.group_2
where (f.cut in ('field_x_soc_major', 'degree_x_soc') and j.soc_code is null)
   or (f.cut = 'field_x_soc_major' and j.soc_level <> 'major')
   or (f.cut = 'field_total' and f.group_2 <> 'all')
   or (f.cut = 'field_x_linked' and f.group_2 not in ('linked', 'not_linked', 'job_not_detailed'))
group by 1, 2
