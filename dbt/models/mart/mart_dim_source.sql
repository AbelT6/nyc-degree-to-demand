-- mart.dim_source: the S13 label behind every number (publisher, dataset, edition, retrieved date,
-- government or research estimate). Facts carry source_key; a visual's footer reads label.
{{ config(alias='dim_source') }}

select
    source_key,
    publisher,
    dataset,
    edition,
    retrieved_date,
    is_government,
    label,
    case when is_government then label else label || ' (research estimate, not government data)' end as label_long,
    landing_url
from {{ ref('dim_source') }}
