with source as (
    select * from {{ source('raw', 'stg_revenue') }}
),

cleaned as (
    select
        {{ dbt_utils.generate_surrogate_key(['date', 'amount', 'row_number() over ()']) }} as transaction_id,
        cast(date as date) as transaction_date,
        cast(amount as decimal(12, 2)) as amount,
        lower(trim(coalesce(status, 'completed'))) as status,
        coalesce(customer_id, 'unknown') as customer_id,
        coalesce(product_id, 'unknown') as product_id,
        current_timestamp as _loaded_at
    from source
    where amount is not null
      and amount > 0
)

select * from cleaned
