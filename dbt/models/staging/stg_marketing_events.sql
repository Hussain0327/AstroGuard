with source as (
    select * from {{ source('raw', 'stg_marketing') }}
),

cleaned as (
    select
        {{ dbt_utils.generate_surrogate_key(['date', 'source', 'campaign']) }} as event_id,
        cast(date as date) as event_date,
        lower(trim(source)) as channel,
        lower(trim(coalesce(campaign, 'unknown'))) as campaign,
        cast(coalesce(leads, 0) as integer) as leads,
        cast(coalesce(conversions, 0) as integer) as conversions,
        cast(coalesce(spend, 0) as decimal(12, 2)) as spend,
        cast(coalesce(revenue, 0) as decimal(12, 2)) as revenue,
        current_timestamp as _loaded_at
    from source
    where leads >= 0
)

select * from cleaned
