-- mart.dim_degree_level: the two degree levels in v1 scope, one field for the synced degree-level slicer
-- (design brief §10.5 item 3). Jobs carry it as their BLS entry education (dim_job.degree_level_key),
-- majors as their award level (dim_major.award_level); Power BI relates this table 1:* to both, so one
-- slicer filters jobs and majors alike.
{{ config(alias='dim_degree_level') }}

select
    award_level                         as degree_level_key,
    replace(award_label, ' degree', '') as degree_level,
    award_label                         as degree_level_long,
    row_number() over (order by sort_order)::int as sort_order
from {{ ref('dim_award_level') }}
where in_v1_scope
