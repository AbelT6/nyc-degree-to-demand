-- staging.stg_bls__ooh_description (nb 36; card bls_ooh.md §7): one row per SOC code, 606 rows, a description on each.
-- The length rule is the job page's (D32: 260 characters on its rows, tests/mart_dim_job_page_additions.sql), not staging's.
-- Returns one row per failed check.
with checks as (
    select 'rows = 606' as check_name, 606 as expected, count(*)::int as got
    from {{ source('staging', 'stg_bls__ooh_description') }}
    union all
    select 'soc_code unique', 0, (count(*) - count(distinct soc_code))::int
    from {{ source('staging', 'stg_bls__ooh_description') }}
    union all
    select 'soc_code and description not null or blank', 0,
           count(*) filter (where soc_code is null or coalesce(trim(description), '') = '')::int
    from {{ source('staging', 'stg_bls__ooh_description') }}
    union all
    select 'no HTML tag or entity left in a description', 0,
           count(*) filter (where description ~ '<[a-z/]|&[a-z]+;|&#[0-9]+;')::int
    from {{ source('staging', 'stg_bls__ooh_description') }}
)

select * from checks where got is distinct from expected
