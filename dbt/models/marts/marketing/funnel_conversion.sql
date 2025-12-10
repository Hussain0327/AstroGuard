with marketing_events as (
    select * from {{ ref('stg_marketing_events') }}
),

monthly_funnel as (
    select
        date_trunc('month', event_date)::date as month,
        channel,
        sum(leads) as leads,
        sum(conversions) as conversions,
        sum(spend) as spend,
        sum(revenue) as revenue
    from marketing_events
    group by 1, 2
),

with_rates as (
    select
        month,
        channel,
        leads,
        conversions,
        spend,
        revenue,

        round(
            conversions::decimal / nullif(leads, 0) * 100,
            2
        ) as conversion_rate,

        round(
            spend / nullif(leads, 0),
            2
        ) as cpl,

        round(
            spend / nullif(conversions, 0),
            2
        ) as cpa,

        lag(leads) over (partition by channel order by month) as prev_leads,
        lag(conversions) over (partition by channel order by month) as prev_conversions

    from monthly_funnel
),

with_growth as (
    select
        *,
        round(
            (leads - prev_leads)::decimal / nullif(prev_leads, 0) * 100,
            2
        ) as leads_growth_pct,
        round(
            (conversions - prev_conversions)::decimal / nullif(prev_conversions, 0) * 100,
            2
        ) as conversions_growth_pct
    from with_rates
)

select
    month,
    channel,
    leads,
    conversions,
    conversion_rate,
    spend,
    revenue,
    cpl,
    cpa,
    leads_growth_pct,
    conversions_growth_pct,
    current_timestamp as _calculated_at
from with_growth
order by month desc, revenue desc
