-- Each field-of-degree → CIP link appears once in ref.ref_fod_cip (D4).
select fod1p, cip2020, count(*) as n
from {{ ref('ref_fod_cip') }}
group by fod1p, cip2020
having count(*) > 1
