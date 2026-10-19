-- mart.footnote: one row per footnote_key x page_key, and every seed row reaches at least one page.
select footnote_key, page_key, count(*) as n
from {{ ref('mart_footnote') }}
group by 1, 2
having count(*) > 1
union all
select f.footnote_key, 'missing' as page_key, 0
from {{ ref('ref_footnote') }} f
left join {{ ref('mart_footnote') }} m on m.footnote_key = f.footnote_key
where m.footnote_key is null
