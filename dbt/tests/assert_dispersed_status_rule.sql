-- D20: 'dispersed' may appear only at the bachelor's level, only where a job passes at 15%, and only when the mapped
-- field's verdict is 'convention'; and every bachelor's major with a convention verdict and a passing job is dispersed.
-- Returns the rows that break the rule (the test passes when none do).

select major_award_key, award_level, n_pass_15, link_status, field_verdict
from {{ ref('dim_major_award') }}
where (link_status = 'dispersed' and not (award_level = 5 and n_pass_15 > 0 and field_verdict = 'convention'))
   or (link_status <> 'dispersed' and award_level = 5 and n_pass_15 > 0 and field_verdict = 'convention')
