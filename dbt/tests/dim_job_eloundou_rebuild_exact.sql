-- The task-label rule used for ai_beta_gpt4 (E1 = 1, E2 = 0.5; core task weight 1, else 0.5)
-- must reproduce every published Eloundou O*NET-level β before it is pooled to SOC level (nb 14).
with rebuilt as (
    select
        onet_soc_code,
        sum(case gpt4_label when 'E1' then 1.0 when 'E2' then 0.5 else 0.0 end
            * case when task_type = 'Core' then 1.0 else 0.5 end)
        / sum(case when task_type = 'Core' then 1.0 else 0.5 end) as beta
    from {{ source('staging', 'stg_eloundou__task_exposure') }}
    group by onet_soc_code
)

select p.onet_soc_code, p.beta_gpt4 as published, r.beta as rebuilt
from {{ source('staging', 'stg_eloundou__job_exposure') }} as p
left join rebuilt as r on r.onet_soc_code = p.onet_soc_code
where r.beta is null or abs(r.beta - p.beta_gpt4) > 1e-9
