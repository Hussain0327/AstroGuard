with transactions as (
    select * from {{ ref('stg_transactions') }}
),

customer_stats as (
    select
        customer_id,
        count(*) as total_orders,
        sum(amount) as lifetime_value,
        avg(amount) as avg_order_value,
        min(transaction_date) as first_order_date,
        max(transaction_date) as last_order_date,
        count(case when status = 'completed' then 1 end) as completed_orders,
        sum(case when status = 'completed' then amount else 0 end) as completed_revenue
    from transactions
    group by customer_id
)

select
    customer_id,
    total_orders,
    lifetime_value,
    avg_order_value,
    first_order_date,
    last_order_date,
    completed_orders,
    completed_revenue,
    current_date - last_order_date as days_since_last_order
from customer_stats
