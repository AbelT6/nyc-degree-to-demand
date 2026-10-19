-- Targets are dim_job rows; the 22 NYC-used SOC 2010 splits are weighted by OEWS 2021 or national data, never equal;
-- the two seed group codes land on minor groups.
select 'target_not_in_dim' as problem, code_system || ' ' || source_code || ' -> ' || soc_code as detail
from {{ ref('bridge_job_code') }} b
where not exists (select 1 from {{ ref('dim_job') }} d where d.soc_code = b.soc_code)
union all
select 'software_dev_split_equal', source_code
from {{ ref('bridge_job_code') }}
where code_system = 'soc_2010' and source_code in ('15-1132', '15-1133', '15-1134', '29-1069', '25-9041') and weight_basis = 'equal'
union all
select 'group_map_not_minor', b.source_code
from {{ ref('bridge_job_code') }} b join {{ ref('dim_job') }} d on d.soc_code = b.soc_code
where b.code_system = 'soc_2010_group' and d.soc_level <> 'minor'
