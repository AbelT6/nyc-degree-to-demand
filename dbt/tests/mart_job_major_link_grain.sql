-- Grain of mart.job_major_link: one row per major_award_key x soc_code, every bridge row present (3,802), and the
-- openings weights of a major sum to 1 (or 0 where the major has no openings weight, the 31 null-weight rows).
with dup as (
    select 'duplicate key' as check_name, major_award_key || ' / ' || soc_code as detail
    from {{ ref('mart_job_major_link') }}
    group by major_award_key, soc_code
    having count(*) > 1
),

counts as (
    select 'row count differs from bridge_major_job' as check_name,
           (select count(*) from {{ ref('mart_job_major_link') }})::text || ' vs ' || (select count(*) from {{ ref('bridge_major_job') }})::text as detail
    where (select count(*) from {{ ref('mart_job_major_link') }}) <> (select count(*) from {{ ref('bridge_major_job') }})
),

weights as (
    select 'openings weights do not sum to 1 or 0' as check_name, major_award_key || ': ' || round(sum(weight_openings)::numeric, 4) as detail
    from {{ ref('mart_job_major_link') }}
    group by major_award_key
    having abs(sum(weight_openings) - 1) > 0.0005 and abs(sum(weight_openings)) > 0.0005
),

equal_weights as (
    select 'equal weights do not sum to 1' as check_name, major_award_key || ': ' || round(sum(weight_equal)::numeric, 4) as detail
    from {{ ref('mart_job_major_link') }}
    group by major_award_key
    having abs(sum(weight_equal) - 1) > 0.0005
)

select * from dup
union all select * from counts
union all select * from weights
union all select * from equal_weights
