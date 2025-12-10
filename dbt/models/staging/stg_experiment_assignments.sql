with source as (
    select * from {{ source('raw', 'stg_experiments') }}
),

cleaned as (
    select
        {{ dbt_utils.generate_surrogate_key(['user_id', 'experiment_name']) }} as assignment_id,
        user_id,
        lower(trim(coalesce(experiment_name, 'default'))) as experiment_name,
        lower(trim(variant)) as variant,
        case
            when lower(trim(variant)) = 'control' then true
            else false
        end as is_control,
        case
            when converted in (1, '1', 'true', 'True', true) then 1
            else 0
        end as converted,
        cast(coalesce(revenue, 0) as decimal(12, 2)) as revenue,
        cast(assigned_at as timestamp) as assigned_at,
        cast(converted_at as timestamp) as converted_at,
        current_timestamp as _loaded_at
    from source
    where user_id is not null
      and variant is not null
)

select * from cleaned
