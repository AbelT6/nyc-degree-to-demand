-- core.fct_cuny_program: graduates and fall enrollment per CUNY program per year, 2008-2025, from the CUNY
-- Programs open-data file (the one source that is a year ahead of IPEDS and carries enrollment).
-- Grain: year x program_key (dim_cuny_program).
-- Plan: docs/step4-facts-plan.md §3c (design), §4 item 10 (tests); source card cuny_programs.md §5-6.
--
-- graduates     stg_cuny__program_graduates, period AY_YYYY_YYYY; year = academic year end as staged (AY_2023_2024 -> 2024)
-- enrolled_fall stg_cuny__program_enrollment, period Fall_YYYY;  year = the fall term's calendar year (Fall_2024 -> 2024)
--
-- The two staging tables are joined with a full outer join on program_key x year so a period present on one side
-- only would still appear (none in the loaded data: both sides hold 2,991 programs x 18 years). Zeros are real
-- zeros (closed or not-yet-open programs keep a full grid of zeros, card §6 issue 2); dim_cuny_program.date_closed
-- tells them apart. Bachelor's graduates count double majors twice (card §6 issue 5): IPEDS (fct_degree_awards)
-- is the count source, this fact is the latest-year and enrollment source.

with graduates as (
    select
        irp_code || '|' || college || '|' || award_name as program_key,
        year,
        period,
        graduates
    from {{ source('staging', 'stg_cuny__program_graduates') }}
),

enrollment as (
    select
        irp_code || '|' || college || '|' || award_name as program_key,
        year,
        period,
        enrolled
    from {{ source('staging', 'stg_cuny__program_enrollment') }}
)

select
    coalesce(g.year, e.year)               as year,
    coalesce(g.program_key, e.program_key) as program_key,
    g.period                               as period_graduates,
    e.period                               as period_enrollment,
    g.graduates,
    e.enrolled                             as enrolled_fall,
    'cuny_programs'                        as source_key
from graduates as g
full outer join enrollment as e on e.program_key = g.program_key and e.year = g.year
