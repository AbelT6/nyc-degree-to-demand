-- fct_grad_outcome is unique at period x cut x group_1 x group_2 x age_band x degree_level (plan §3e).
select period, cut, group_1, group_2, age_band, degree_level, count(*) as n
from {{ ref('fct_grad_outcome') }}
group by 1, 2, 3, 4, 5, 6
having count(*) > 1
