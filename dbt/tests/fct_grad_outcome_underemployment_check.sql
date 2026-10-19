-- Plausibility (plan §4 item 15; card acs_pums.md §5): among employed, not-enrolled NYC bachelor's holders aged 22-27,
-- the weighted share working in jobs whose BLS typical entry education is below a bachelor's (dim_job
-- entry_education_rank < 6, over jobs with a known entry education) is between 36% and 42%. The card measured 38.8%
-- including enrolled students; not enrolled it is 36.2%. Recomputed from the person rows so suppressed cells count.
with workers as (
    select p.soc_code, sum(p.weight * p.part_weight) as w
    from {{ ref('int_grad_outcome_person_cut') }} as p
    where p.cut = 'degree_x_soc' and p.age_band = '22-27' and p.degree_level = 'bachelor'
    group by p.soc_code
),

share as (
    select
        sum(w.w) filter (where j.entry_education_rank < 6)
            / sum(w.w) filter (where j.entry_education_rank is not null) as below_bachelors_share,
        sum(w.w) filter (where j.entry_education_rank is not null) / sum(w.w) as known_share
    from workers as w
    join {{ ref('dim_job') }} as j on j.soc_code = w.soc_code
)

select *
from share
where below_bachelors_share not between 0.36 and 0.42
   or known_share < 0.80
