-- CIP 2010 -> 2020 is 1:1 (1,713 live pairs, 7 deleted with null target); every live target is a dim_major row;
-- every CIP 2010 code IPEDS uses for NYC colleges resolves.
select 'not_one_to_one' as problem, cip_2010 as detail from {{ ref('bridge_cip_2010_2020') }} group by cip_2010 having count(*) > 1
union all
select 'target_not_in_dim_major', cip_2010 from {{ ref('bridge_cip_2010_2020') }} b
where cip_2020 is not null and not exists (select 1 from {{ ref('dim_major') }} m where m.cip_code = b.cip_2020)
union all
select 'ipeds_cip2010_unresolved', c.cip_code
from (select distinct cip_code from {{ source('staging', 'stg_ipeds__completions') }} where cip_edition = '2010') c
where not exists (select 1 from {{ ref('bridge_cip_2010_2020') }} b where b.cip_2010 = c.cip_code and b.cip_2020 is not null)
