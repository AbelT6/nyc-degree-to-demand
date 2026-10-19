-- mart.dim_area: the areas facts are published for. NYC and the NY metro are separate rows and never
-- mixed (schema-design §2; the metro is about twice NYC).
{{ config(alias='dim_area') }}

select area_key, area_name, area_type, is_nyc, sort_order
from {{ ref('dim_area') }}
