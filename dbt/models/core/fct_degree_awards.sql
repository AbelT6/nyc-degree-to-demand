-- core.fct_degree_awards: IPEDS completions for NYC colleges, 2015-2024, every award on a CIP 2020 code.
-- Grain: year x unitid x cip_code (CIP 2020) x major_number x award_level.
-- Plan: docs/step4-facts-plan.md §3c (design), §4 item 9 (tests); source card ipeds_completions.md §6 issues 6-9.
--
-- cip_edition   how a source row reaches dim_major
-- 2010 (2015-19)  bridge_cip_2010_2020 (cip_2010 -> cip_2020, strictly 1:1; 0 unbridged NYC codes); cip_bridged = true
-- 2020 (2020-24)  identity; cip_bridged = false
--
-- The bridge is 1:1 but several CIP 2010 codes may move onto one CIP 2020 code ("Moved to" rows), so two source rows
-- can land on one key. The model groups by the bridged key, sums the awards and records every source code in
-- cip_code_source (comma-separated when more than one; 0 such keys in the loaded data, kept as a safeguard).
-- Graduate counts are major_number = 1 (nb 05 rule); second majors stay for a "majors" view. Grand-total rows
-- (CIP 99) were dropped in staging. Measures are integers from an administrative census: no suppression, no nulls.

with src as (
    select
        year,
        release,
        unitid,
        cip_code,
        cip_edition,
        major_number,
        award_level,
        awards_total,
        awards_men,
        awards_women,
        imputation_flag
    from {{ source('staging', 'stg_ipeds__completions') }}
),

bridge as (
    select cip_2010, cip_2020
    from {{ ref('bridge_cip_2010_2020') }}
    where cip_2020 is not null
),

-- CIP 2010 rows take the bridge target; CIP 2020 rows keep their code. A 2010 row with no live target would keep
-- its 2010 code and fail the dim_major relationships test (none in the loaded data).
landed as (
    select
        s.year,
        s.release,
        s.unitid,
        case when s.cip_edition = '2010' then coalesce(b.cip_2020, s.cip_code) else s.cip_code end as cip_code,
        s.cip_code as cip_code_source,
        s.cip_edition as cip_edition_source,
        s.cip_edition = '2010' as cip_bridged,
        s.major_number,
        s.award_level,
        s.awards_total,
        s.awards_men,
        s.awards_women,
        s.imputation_flag
    from src as s
    left join bridge as b on s.cip_edition = '2010' and b.cip_2010 = s.cip_code
),

-- One row per landed key: sums conserved, every contributing source code kept in order.
grouped as (
    select
        year,
        string_agg(distinct release, ', ')                                   as release,
        unitid,
        cip_code,
        string_agg(cip_code_source, ', ' order by cip_code_source)           as cip_code_source,
        max(cip_edition_source)                                              as cip_edition_source,
        bool_or(cip_bridged)                                                 as cip_bridged,
        major_number,
        award_level,
        sum(awards_total)                                                    as awards_total,
        sum(awards_men)                                                      as awards_men,
        sum(awards_women)                                                    as awards_women,
        string_agg(distinct imputation_flag, ', ')                           as imputation_flag
    from landed
    group by year, unitid, cip_code, major_number, award_level
)

select
    year,
    release,
    unitid,
    cip_code,
    cip_code_source,
    cip_edition_source,
    cip_bridged,
    major_number,
    award_level,
    awards_total,
    awards_men,
    awards_women,
    imputation_flag,
    'ipeds_completions' as source_key
from grouped
