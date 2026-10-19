-- The band cut-offs in D7 were set from NY metro OEWS May 2025 employment shares among scored jobs:
-- Not seen yet 36.5%, Low 21.1%, Medium 21.4%, High 21.0%. Fail if any band drifts by more than 0.3 pp.
with emp as (
    select o.occ_code as soc_code, o.employment
    from {{ source('staging', 'stg_bls__oews_metro_occupations') }} as o
    where o.year = 2025 and o.occ_level = 'detailed'
),

shares as (
    select
        d.ai_band,
        round(100.0 * sum(e.employment) / sum(sum(e.employment)) over (), 1) as share_pct
    from emp as e
    join {{ ref('dim_job') }} as d on d.soc_code = e.soc_code
    where d.ai_band <> 'Not rated'
    group by d.ai_band
),

expected as (
    select * from (values
        ('Not seen yet', 36.5), ('Low', 21.1), ('Medium', 21.4), ('High', 21.0)
    ) as t (ai_band, expected_pct)
)

select x.ai_band, x.expected_pct, s.share_pct
from expected as x
left join shares as s on s.ai_band = x.ai_band
where s.share_pct is null or abs(s.share_pct - x.expected_pct) > 0.3
