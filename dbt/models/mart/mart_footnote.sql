-- mart.footnote: one row per footnote x page it belongs on (docs/mart-plan.md §4g; brief S13). Power BI
-- filters on page_key and shows footnote_text in order; no caveat is typed into a text box. Source is the
-- hand-written seed ref_footnote (page_keys is comma-separated there; 'all' fans out to every page). page_name /
-- page_order / note_order: the Notes page shows the page's name and sorts by story order, then the note's order.
{{ config(alias='footnote') }}

with pages as (
    select unnest(array['overview', 'jobs', 'industries', 'job', 'majors', 'major', 'entry', 'graduates', 'ai', 'findings', 'find_major']) as page_key
),

-- page names and the App's story order (design brief §2, D26): the Notes page lists notes by page in this order.
-- 'findings' = What we found, the end of the guided path (clarity revision C3, D45), after the side door in this list;
-- 'find_major' = Find your major (D52), listed with the majors pages (story order 5)
page_names as (
    select * from (values
        ('overview', 'Overview', 1), ('jobs', 'Jobs', 2), ('job', 'Job page', 3), ('entry', 'Getting in', 4),
        ('majors', 'Majors', 5), ('major', 'Major page', 6), ('graduates', 'What graduates do', 7), ('ai', 'AI', 8),
        ('industries', 'Industries', 9), ('findings', 'What we found', 10),
        ('find_major', 'Find your major', 5)
    ) as v (page_key, page_name, page_order)
),

expanded as (
    select
        f.footnote_key,
        case when k = 'all' then p.page_key else k end as page_key,
        f.subject,
        f.footnote_text,
        f.short_text,
        f.decision_ref,
        f.sort_order
    from {{ ref('ref_footnote') }} f
    cross join lateral unnest(string_to_array(f.page_keys, ',')) as u(k)
    left join pages p on trim(k) = 'all'
)

select
    e.footnote_key,
    trim(e.page_key) as page_key,
    n.page_name,
    n.page_order,
    n.page_order * 1000 + e.sort_order as note_order,
    e.subject,
    e.footnote_text,
    e.short_text,
    e.decision_ref,
    e.sort_order
from expanded as e
left join page_names as n on n.page_key = trim(e.page_key)
