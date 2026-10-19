-- Both weights in bridge_major_job sum to 1 per cip_code x award_level (tolerance 1e-9); weight_openings may instead
-- be null for the whole group (majors whose passing jobs have no openings at all: 10 associate's, 18 bachelor's),
-- never null for part of a group. n_jobs_in_major equals the row count of the group.
select
    cip_code,
    award_level,
    sum(weight_equal) as equal_total,
    sum(weight_openings) as openings_total,
    count(*) filter (where weight_openings is null) as null_openings_weights,
    count(*) as n_rows,
    max(n_jobs_in_major) as n_jobs_in_major
from {{ ref('bridge_major_job') }}
group by cip_code, award_level
having abs(sum(weight_equal) - 1) > 1e-9
    or (count(*) filter (where weight_openings is null) = 0 and abs(sum(weight_openings) - 1) > 1e-9)
    or (count(*) filter (where weight_openings is null) not in (0, count(*)))
    or max(n_jobs_in_major) <> count(*)
    or min(n_jobs_in_major) <> count(*)
