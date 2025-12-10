with transactions as (
    select * from {{ ref('stg_transactions') }}
    where status in ('completed', 'paid')
),

daily_revenue as (
    select
        transaction_date,
        sum(amount) as daily_revenue,
        count(*) as transactions,
        count(distinct customer_id) as customers
    from transactions
    group by 1
),

summary as (
    select
        sum(daily_revenue) as total_revenue,
        count(distinct transaction_date) as days_with_revenue,
        sum(transactions) as total_transactions,
        avg(daily_revenue) as avg_daily_revenue,
        min(transaction_date) as first_transaction_date,
        max(transaction_date) as last_transaction_date
    from daily_revenue
),

recent_30d as (
    select
        sum(daily_revenue) as revenue_30d,
        sum(transactions) as transactions_30d,
        avg(daily_revenue) as avg_daily_revenue_30d
    from daily_revenue
    where transaction_date >= current_date - interval '30 days'
),

recent_7d as (
    select
        sum(daily_revenue) as revenue_7d,
        sum(transactions) as transactions_7d,
        avg(daily_revenue) as avg_daily_revenue_7d
    from daily_revenue
    where transaction_date >= current_date - interval '7 days'
)

select
    s.total_revenue,
    s.total_transactions,
    round(s.total_revenue / nullif(s.total_transactions, 0), 2) as average_order_value,
    s.avg_daily_revenue,
    s.first_transaction_date,
    s.last_transaction_date,
    s.days_with_revenue,
    r30.revenue_30d,
    r30.transactions_30d,
    r7.revenue_7d,
    r7.transactions_7d,
    current_timestamp as _calculated_at
from summary s
cross join recent_30d r30
cross join recent_7d r7
