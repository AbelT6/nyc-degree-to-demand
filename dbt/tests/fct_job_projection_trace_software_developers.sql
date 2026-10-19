-- Trace guard (plan §6.6): Software Developers 15-1252 in 2022-32 is an imputed row with base between 60,000 and
-- 80,000 and annual openings between 3,000 and 6,000, so a silent change in a bridge weight or a rate fails loudly.
select edition, soc_code, base_employment, annual_openings_avg, quality_flag
from {{ ref('fct_job_projection') }}
where edition = '2022-2032' and soc_code = '15-1252'
  and not (quality_flag = 'imputed'
           and base_employment between 60000 and 80000
           and annual_openings_avg between 3000 and 6000)
union all
select '2022-2032', '15-1252', null, null, 'missing'
where not exists (select 1 from {{ ref('fct_job_projection') }} where edition = '2022-2032' and soc_code = '15-1252')
