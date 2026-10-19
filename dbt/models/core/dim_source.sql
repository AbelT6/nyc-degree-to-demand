-- core.dim_source: one row per raw-data manifest key that feeds a staging table (brief S13).
-- From the hand-built seed ref/source_registry.csv. Every fact row will carry source_key.

select
    source_key,
    publisher,
    dataset,
    edition,
    download_url,
    landing_url,
    retrieved_date,
    license,
    is_government,
    label,
    source_card
from {{ ref('source_registry') }}
