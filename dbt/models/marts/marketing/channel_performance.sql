with marketing_events as (
    select * from {{ ref('stg_marketing_events') }}
),

channel_stats as (
    select
        channel,
        sum(leads) as total_leads,
        sum(conversions) as total_conversions,
        sum(spend) as total_spend,
        sum(revenue) as total_revenue,
        count(distinct event_date) as active_days,
        min(event_date) as first_activity,
        max(event_date) as last_activity
    from marketing_events
    group by channel
),

with_metrics as (
    select
        channel,
        total_leads,
        total_conversions,
        total_spend,
        total_revenue,
        active_days,
        first_activity,
        last_activity,

        round(
            total_conversions::decimal / nullif(total_leads, 0) * 100,
            2
        ) as conversion_rate,

        round(
            total_spend / nullif(total_leads, 0),
            2
        ) as cost_per_lead,

        round(
            total_spend / nullif(total_conversions, 0),
            2
        ) as cost_per_conversion,

        round(
            total_revenue / nullif(total_spend, 0),
            2
        ) as roas,

        total_revenue - total_spend as net_revenue

    from channel_stats
)

select
    channel,
    total_leads,
    total_conversions,
    conversion_rate,
    total_spend,
    total_revenue,
    cost_per_lead,
    cost_per_conversion,
    roas,
    net_revenue,
    active_days,
    first_activity,
    last_activity,
    current_timestamp as _calculated_at
from with_metrics
order by total_revenue desc
