-- core.dim_cuny_program: one row per registered CUNY program in the CUNY Programs open-data file.
-- Grain: program_key = irp_code | college | award_name (irp_code alone is not unique: 365 programs share 167 codes,
-- source card cuny_programs.md §6 issue 1).
-- Plan: docs/step4-facts-plan.md §3c (small dimension instead of repeating 10 program attributes 18 times on
-- fct_cuny_program, §6 defaults).
--
-- Attributes come from stg_cuny__program_graduates; the enrollment table lists the same 2,991 programs with
-- identical attributes (asserted by the singular test). unitid was mapped in staging (6 units hand-mapped to a
-- parent college, unitid_is_parent_assumption). award_level is the CUNY grouping as staged; ipeds_award_level is
-- the IPEDS AWLEVEL code from seed cuny_award_level (3 associate's, 5 bachelor's; null for certificate and
-- graduate names, which the seed leaves unmapped). cip_code is CIP 2020 in every year.

with programs as (
    select distinct
        irp_code,
        college,
        unitid,
        unitid_is_parent_assumption,
        program_name,
        award_name,
        award_number,
        award_level,
        cip_code,
        date_registered,
        date_closed,
        tap_eligible,
        apts_eligible,
        vvta_eligible
    from {{ source('staging', 'stg_cuny__program_graduates') }}
),

award_map as (
    select award_name, ipeds_awlevel
    from {{ ref('cuny_award_level') }}
)

select
    p.irp_code || '|' || p.college || '|' || p.award_name as program_key,
    p.irp_code,
    p.college,
    p.unitid,
    p.unitid_is_parent_assumption,
    p.program_name,
    p.award_name,
    p.award_number,
    p.award_level,
    a.ipeds_awlevel as ipeds_award_level,
    p.cip_code,
    p.date_registered,
    p.date_closed,
    p.date_closed is not null as is_closed,
    p.tap_eligible,
    p.apts_eligible,
    p.vvta_eligible,
    'cuny_programs' as source_key
from programs as p
left join award_map as a on a.award_name = p.award_name
