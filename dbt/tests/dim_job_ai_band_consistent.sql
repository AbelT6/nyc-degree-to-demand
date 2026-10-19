-- ai_band is 'Not rated' exactly when there is no Anthropic score, and every band matches its cut-off.
select soc_code, ai_observed_exposure, ai_band
from {{ ref('dim_job') }}
where (ai_band = 'Not rated') <> (ai_observed_exposure is null)
   or (ai_band = 'Not seen yet' and ai_observed_exposure <> 0)
   or (ai_band = 'Low' and not (ai_observed_exposure > 0 and ai_observed_exposure < 0.10))
   or (ai_band = 'Medium' and not (ai_observed_exposure >= 0.10 and ai_observed_exposure < 0.30))
   or (ai_band = 'High' and not ai_observed_exposure >= 0.30)
