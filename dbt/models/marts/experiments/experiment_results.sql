with assignments as (
    select * from {{ ref('stg_experiment_assignments') }}
),

variant_stats as (
    select
        experiment_name,
        variant,
        is_control,
        count(*) as users,
        sum(converted) as conversions,
        sum(revenue) as total_revenue,
        min(assigned_at) as first_assignment,
        max(assigned_at) as last_assignment
    from assignments
    group by 1, 2, 3
),

with_rates as (
    select
        experiment_name,
        variant,
        is_control,
        users,
        conversions,
        total_revenue,
        first_assignment,
        last_assignment,

        round(
            conversions::decimal / nullif(users, 0) * 100,
            4
        ) as conversion_rate,

        round(
            total_revenue / nullif(users, 0),
            2
        ) as revenue_per_user,

        round(
            total_revenue / nullif(conversions, 0),
            2
        ) as avg_revenue_per_conversion

    from variant_stats
),

control_rates as (
    select
        experiment_name,
        conversion_rate as control_conversion_rate,
        revenue_per_user as control_rpu
    from with_rates
    where is_control = true
),

with_lift as (
    select
        w.*,
        c.control_conversion_rate,
        c.control_rpu,

        case
            when w.is_control then 0
            else round(w.conversion_rate - c.control_conversion_rate, 4)
        end as absolute_lift,

        case
            when w.is_control or c.control_conversion_rate = 0 then 0
            else round(
                (w.conversion_rate - c.control_conversion_rate)
                / c.control_conversion_rate * 100,
                2
            )
        end as relative_lift_pct

    from with_rates w
    left join control_rates c on w.experiment_name = c.experiment_name
)

select
    experiment_name,
    variant,
    is_control,
    users,
    conversions,
    conversion_rate,
    control_conversion_rate,
    absolute_lift,
    relative_lift_pct,
    total_revenue,
    revenue_per_user,
    avg_revenue_per_conversion,
    first_assignment,
    last_assignment,
    last_assignment::date - first_assignment::date as experiment_days,
    current_timestamp as _calculated_at
from with_lift
order by experiment_name, is_control desc, variant
