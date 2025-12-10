-- =============================================================================
-- Daily Metrics View
-- =============================================================================
-- Demonstrates: Materialized view, daily aggregations, KPI calculations
--
-- Purpose: Pre-computed daily metrics for dashboard and reporting
-- =============================================================================

-- Drop existing view if needed
-- DROP MATERIALIZED VIEW IF EXISTS vw_daily_metrics;

CREATE MATERIALIZED VIEW vw_daily_metrics AS

WITH daily_transactions AS (
    SELECT
        DATE_TRUNC('day', transaction_date)::DATE AS date,
        SUM(amount) AS revenue,
        COUNT(*) AS transaction_count,
        COUNT(DISTINCT customer_id) AS unique_customers,
        AVG(amount) AS avg_order_value,
        SUM(quantity) AS total_units_sold
    FROM transactions
    GROUP BY DATE_TRUNC('day', transaction_date)
),

daily_new_customers AS (
    SELECT
        DATE_TRUNC('day', first_purchase)::DATE AS date,
        COUNT(*) AS new_customers
    FROM (
        SELECT customer_id, MIN(transaction_date) AS first_purchase
        FROM transactions
        GROUP BY customer_id
    ) AS first_purchases
    GROUP BY DATE_TRUNC('day', first_purchase)
),

daily_marketing AS (
    SELECT
        DATE_TRUNC('day', event_date)::DATE AS date,
        COUNT(CASE WHEN stage = 'lead' THEN 1 END) AS new_leads,
        COUNT(CASE WHEN stage = 'customer' THEN 1 END) AS conversions,
        SUM(COALESCE(cost, 0)) AS marketing_spend
    FROM marketing_events
    GROUP BY DATE_TRUNC('day', event_date)
)

SELECT
    dt.date,
    -- Revenue Metrics
    COALESCE(dt.revenue, 0) AS revenue,
    COALESCE(dt.transaction_count, 0) AS transactions,
    COALESCE(dt.unique_customers, 0) AS active_customers,
    ROUND(COALESCE(dt.avg_order_value, 0), 2) AS avg_order_value,
    COALESCE(dt.total_units_sold, 0) AS units_sold,

    -- Customer Metrics
    COALESCE(dnc.new_customers, 0) AS new_customers,

    -- Marketing Metrics
    COALESCE(dm.new_leads, 0) AS new_leads,
    COALESCE(dm.conversions, 0) AS conversions,
    COALESCE(dm.marketing_spend, 0) AS marketing_spend,

    -- Calculated Metrics
    CASE
        WHEN COALESCE(dm.new_leads, 0) > 0
        THEN ROUND(COALESCE(dm.conversions, 0)::NUMERIC / dm.new_leads * 100, 2)
        ELSE 0
    END AS conversion_rate,

    CASE
        WHEN COALESCE(dm.conversions, 0) > 0
        THEN ROUND(COALESCE(dm.marketing_spend, 0) / dm.conversions, 2)
        ELSE 0
    END AS cost_per_acquisition,

    CASE
        WHEN COALESCE(dm.marketing_spend, 0) > 0
        THEN ROUND(COALESCE(dt.revenue, 0) / dm.marketing_spend, 2)
        ELSE 0
    END AS roas,

    -- Time dimensions for filtering
    EXTRACT(DOW FROM dt.date) AS day_of_week,
    EXTRACT(MONTH FROM dt.date) AS month,
    EXTRACT(QUARTER FROM dt.date) AS quarter,
    EXTRACT(YEAR FROM dt.date) AS year,
    DATE_TRUNC('week', dt.date)::DATE AS week_start,
    DATE_TRUNC('month', dt.date)::DATE AS month_start

FROM daily_transactions dt
LEFT JOIN daily_new_customers dnc ON dt.date = dnc.date
LEFT JOIN daily_marketing dm ON dt.date = dm.date
ORDER BY dt.date;

-- Create index for faster queries
CREATE UNIQUE INDEX idx_daily_metrics_date ON vw_daily_metrics (date);
CREATE INDEX idx_daily_metrics_month ON vw_daily_metrics (month_start);

-- Refresh command (run daily via scheduler)
-- REFRESH MATERIALIZED VIEW CONCURRENTLY vw_daily_metrics;


-- =============================================================================
-- Sample Queries Using the View
-- =============================================================================

-- Last 7 days summary
/*
SELECT
    date,
    revenue,
    transactions,
    active_customers,
    new_customers,
    conversion_rate
FROM vw_daily_metrics
WHERE date >= CURRENT_DATE - INTERVAL '7 days'
ORDER BY date;
*/

-- Monthly aggregation
/*
SELECT
    month_start,
    SUM(revenue) AS monthly_revenue,
    SUM(transactions) AS monthly_transactions,
    SUM(new_customers) AS monthly_new_customers,
    ROUND(AVG(conversion_rate), 2) AS avg_conversion_rate
FROM vw_daily_metrics
WHERE year = 2024
GROUP BY month_start
ORDER BY month_start;
*/

-- Week-over-week comparison
/*
WITH weekly AS (
    SELECT
        week_start,
        SUM(revenue) AS revenue
    FROM vw_daily_metrics
    GROUP BY week_start
)
SELECT
    week_start,
    revenue,
    LAG(revenue) OVER (ORDER BY week_start) AS prev_week,
    ROUND((revenue - LAG(revenue) OVER (ORDER BY week_start)) /
          NULLIF(LAG(revenue) OVER (ORDER BY week_start), 0) * 100, 2) AS wow_growth
FROM weekly
ORDER BY week_start DESC
LIMIT 12;
*/
