-- Plan §4 item 6: bls_experience has 831 rows with value in 1-3; the two shares lie in [0, 1]; acs_young_share
-- carries moe_90 exactly where not suppressed and null value / band / moe_90 where suppressed; onet_newcomer has no
-- moe_90; ACS n is at least 30 where not suppressed; n_young is present on exactly the acs_young_share rows and
-- never exceeds n.
with f as (
    select * from {{ ref('fct_job_entry_signal') }}
)
select soc_code, measure, 'share outside [0, 1]' as reason
from f
where measure in ('acs_young_share', 'onet_newcomer') and (value < 0 or value > 1)
union all
select soc_code, measure, 'bls value not 1-3'
from f
where measure = 'bls_experience' and (value not in (1, 2, 3) or band is null)
union all
select soc_code, measure, 'acs unsuppressed without value / moe / band or n < 30'
from f
where measure = 'acs_young_share' and not suppressed
  and (value is null or moe_90 is null or band is null or n < 30)
union all
select soc_code, measure, 'acs suppressed row carries a value'
from f
where measure = 'acs_young_share' and suppressed
  and (value is not null or moe_90 is not null or band is not null or n >= 30)
union all
select soc_code, measure, 'moe_90 on a non-ACS measure'
from f
where measure <> 'acs_young_share' and moe_90 is not null
union all
select soc_code, measure, 'n_young missing, negative or above n on an ACS row'
from f
where measure = 'acs_young_share' and (n_young is null or n_young < 0 or n_young > n)
union all
select soc_code, measure, 'n_young on a non-ACS measure'
from f
where measure <> 'acs_young_share' and n_young is not null
union all
select soc_code, measure, 'onet row without value or band'
from f
where measure = 'onet_newcomer' and (value is null or band is null)
union all
select 'all', 'bls_experience', 'row count not 831'
from f
where measure = 'bls_experience'
having count(*) <> 831
