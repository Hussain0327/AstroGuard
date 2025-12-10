-- =============================================================================
-- Revenue Analysis Query
-- =============================================================================
-- Demonstrates: CTEs, window functions (LAG, SUM OVER), date manipulation,
--               aggregations, growth calculations
--
-- Purpose: Analyze monthly revenue trends, growth rates, and cumulative metrics
-- =============================================================================

-- Monthly Revenue with Growth Rates
WITH monthly_revenue AS (
    -- Aggregate transactions by month
    SELECT
        DATE_TRUNC('month', transaction_date)::DATE AS month,
        SUM(amount) AS revenue,
        COUNT(*) AS transaction_count,
        COUNT(DISTINCT customer_id) AS unique_customers,
        AVG(amount) AS avg_order_value
    FROM transactions
    WHERE transaction_date >= CURRENT_DATE - INTERVAL '12 months'
      AND amount > 0  -- Exclude refunds
    GROUP BY DATE_TRUNC('month', transaction_date)
),

revenue_with_growth AS (
    -- Calculate month-over-month growth using LAG
    SELECT
        month,
        revenue,
        transaction_count,
        unique_customers,
        avg_order_value,
        LAG(revenue) OVER (ORDER BY month) AS prev_month_revenue,
        LAG(unique_customers) OVER (ORDER BY month) AS prev_month_customers
    FROM monthly_revenue
),

final_metrics AS (
    -- Compute growth percentages and cumulative totals
    SELECT
        month,
        revenue,
        transaction_count,
        unique_customers,
        ROUND(avg_order_value, 2) AS avg_order_value,
        prev_month_revenue,
        -- Month-over-month revenue growth
        CASE
            WHEN prev_month_revenue IS NULL OR prev_month_revenue = 0 THEN NULL
            ELSE ROUND(
                ((revenue - prev_month_revenue) / prev_month_revenue) * 100,
                2
            )
        END AS revenue_growth_pct,
        -- Month-over-month customer growth
        CASE
            WHEN prev_month_customers IS NULL OR prev_month_customers = 0 THEN NULL
            ELSE ROUND(
                ((unique_customers - prev_month_customers)::NUMERIC / prev_month_customers) * 100,
                2
            )
        END AS customer_growth_pct,
        -- Cumulative revenue (running total)
        SUM(revenue) OVER (ORDER BY month) AS cumulative_revenue,
        -- Revenue per customer
        ROUND(revenue / NULLIF(unique_customers, 0), 2) AS revenue_per_customer
    FROM revenue_with_growth
)

SELECT
    month,
    revenue,
    transaction_count,
    unique_customers,
    avg_order_value,
    revenue_growth_pct AS mom_growth_pct,
    customer_growth_pct,
    cumulative_revenue,
    revenue_per_customer
FROM final_metrics
ORDER BY month;


-- =============================================================================
-- Additional Revenue Breakdowns
-- =============================================================================

-- Revenue by Product Category
WITH category_revenue AS (
    SELECT
        p.category,
        DATE_TRUNC('month', t.transaction_date)::DATE AS month,
        SUM(t.amount) AS revenue,
        COUNT(*) AS transactions
    FROM transactions t
    JOIN products p ON t.product_id = p.product_id
    WHERE t.transaction_date >= CURRENT_DATE - INTERVAL '6 months'
    GROUP BY p.category, DATE_TRUNC('month', t.transaction_date)
)
SELECT
    category,
    month,
    revenue,
    transactions,
    -- Category's share of total monthly revenue
    ROUND(
        revenue / SUM(revenue) OVER (PARTITION BY month) * 100,
        2
    ) AS pct_of_monthly_revenue,
    -- Category rank by revenue each month
    RANK() OVER (PARTITION BY month ORDER BY revenue DESC) AS category_rank
FROM category_revenue
ORDER BY month, revenue DESC;


-- Revenue by Channel (Attribution)
SELECT
    COALESCE(channel, 'Direct') AS channel,
    DATE_TRUNC('month', transaction_date)::DATE AS month,
    SUM(amount) AS revenue,
    COUNT(DISTINCT customer_id) AS customers,
    ROUND(AVG(amount), 2) AS avg_order_value,
    -- Channel's contribution to total
    ROUND(
        SUM(amount) / SUM(SUM(amount)) OVER (PARTITION BY DATE_TRUNC('month', transaction_date)) * 100,
        2
    ) AS channel_contribution_pct
FROM transactions
WHERE transaction_date >= CURRENT_DATE - INTERVAL '6 months'
GROUP BY channel, DATE_TRUNC('month', transaction_date)
ORDER BY month, revenue DESC;


-- =============================================================================
-- MRR/ARR Calculation (for subscription businesses)
-- =============================================================================

WITH subscription_revenue AS (
    SELECT
        customer_id,
        DATE_TRUNC('month', transaction_date)::DATE AS month,
        SUM(amount) AS monthly_spend,
        -- Detect if customer is recurring (purchased previous month too)
        LAG(DATE_TRUNC('month', transaction_date)) OVER (
            PARTITION BY customer_id
            ORDER BY DATE_TRUNC('month', transaction_date)
        ) AS prev_purchase_month
    FROM transactions
    WHERE transaction_date >= CURRENT_DATE - INTERVAL '12 months'
    GROUP BY customer_id, DATE_TRUNC('month', transaction_date)
),

mrr_components AS (
    SELECT
        month,
        -- New MRR: First-time customers this month
        SUM(CASE WHEN prev_purchase_month IS NULL THEN monthly_spend ELSE 0 END) AS new_mrr,
        -- Expansion MRR: Existing customers who spent more
        -- (simplified - would need previous month's spend for accurate calc)
        SUM(CASE WHEN prev_purchase_month IS NOT NULL THEN monthly_spend ELSE 0 END) AS recurring_mrr,
        COUNT(DISTINCT customer_id) AS active_customers
    FROM subscription_revenue
    GROUP BY month
)

SELECT
    month,
    new_mrr,
    recurring_mrr,
    new_mrr + recurring_mrr AS total_mrr,
    (new_mrr + recurring_mrr) * 12 AS arr,
    active_customers,
    ROUND((new_mrr + recurring_mrr) / NULLIF(active_customers, 0), 2) AS arpu
FROM mrr_components
ORDER BY month;
