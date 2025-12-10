{{
    config(
        materialized='incremental',
        unique_key='month'
    )
}}

with transactions as (
    select * from {{ ref('stg_transactions') }}
    where status in ('completed', 'paid')
),

monthly_revenue as (
    select
        date_trunc('month', transaction_date)::date as month,
        sum(amount) as total_revenue,
        count(distinct customer_id) as unique_customers,
        count(*) as transaction_count,
        avg(amount) as avg_transaction_value
    from transactions
    {% if is_incremental() %}
    where transaction_date > (select max(month) from {{ this }})
    {% endif %}
    group by 1
),

with_growth as (
    select
        month,
        total_revenue,
        unique_customers,
        transaction_count,
        avg_transaction_value,
        lag(total_revenue) over (order by month) as previous_month_revenue,
        total_revenue - lag(total_revenue) over (order by month) as revenue_change,
        case
            when lag(total_revenue) over (order by month) > 0
            then round(
                ((total_revenue - lag(total_revenue) over (order by month))
                / lag(total_revenue) over (order by month)) * 100,
                2
            )
            else null
        end as growth_rate_pct
    from monthly_revenue
)

select
    month,
    total_revenue as mrr,
    unique_customers,
    transaction_count,
    round(avg_transaction_value, 2) as avg_transaction_value,
    round(total_revenue / nullif(unique_customers, 0), 2) as arpu,
    previous_month_revenue,
    revenue_change,
    growth_rate_pct,
    current_timestamp as _calculated_at
from with_growth
