-- Plan §4 item 7: Importance ratings lie in [1, 5], Level ratings in [0, 7].
select soc_code, domain, element_id, scale, value
from {{ ref('fct_job_skill') }}
where (scale = 'IM' and (value < 1 or value > 5))
   or (scale = 'LV' and (value < 0 or value > 7))
