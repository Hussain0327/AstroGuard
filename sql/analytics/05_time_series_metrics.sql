-- =============================================================================
-- Time Series Metrics Analysis
-- =============================================================================
-- Demonstrates: LAG/LEAD, moving averages, cumulative sums, date series,
--               trend analysis, seasonality detection
--
-- Purpose: Analyze metrics over time with proper time series techniques
-- =============================================================================

-- Daily Revenue with Moving Averages
WITH daily_revenue AS (
    SELECT
        DATE_TRUNC('day', transaction_date)::DATE AS date,
        SUM(amount) AS revenue,
        COUNT(*) AS transactions,
        COUNT(DISTINCT customer_id) AS unique_customers
    FROM transactions
    WHERE transaction_date >= CURRENT_DATE - INTERVAL '90 days'
    GROUP BY DATE_TRUNC('day', transaction_date)
)

SELECT
    date,
    revenue,
    transactions,
    unique_customers,
    -- Previous day comparison
    LAG(revenue) OVER (ORDER BY date) AS prev_day_revenue,
    revenue - LAG(revenue) OVER (ORDER BY date) AS day_over_day_change,
    -- 7-day moving average (smooths daily volatility)
    ROUND(
        AVG(revenue) OVER (
            ORDER BY date
            ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ), 2
    ) AS revenue_7d_ma,
    -- 30-day moving average (trend)
    ROUND(
        AVG(revenue) OVER (
            ORDER BY date
            ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
        ), 2
    ) AS revenue_30d_ma,
    -- Cumulative revenue
    SUM(revenue) OVER (ORDER BY date) AS cumulative_revenue,
    -- Rolling 7-day sum
    SUM(revenue) OVER (
        ORDER BY date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS revenue_7d_rolling,
    -- Day of week (for seasonality)
    EXTRACT(DOW FROM date) AS day_of_week,
    TO_CHAR(date, 'Day') AS day_name
FROM daily_revenue
ORDER BY date;


-- =============================================================================
-- Week-over-Week and Month-over-Month Comparisons
-- =============================================================================

WITH weekly_metrics AS (
    SELECT
        DATE_TRUNC('week', transaction_date)::DATE AS week_start,
        SUM(amount) AS revenue,
        COUNT(DISTINCT customer_id) AS customers,
        COUNT(*) AS orders
    FROM transactions
    WHERE transaction_date >= CURRENT_DATE - INTERVAL '6 months'
    GROUP BY DATE_TRUNC('week', transaction_date)
)

SELECT
    week_start,
    revenue,
    customers,
    orders,
    -- Week-over-week
    LAG(revenue) OVER (ORDER BY week_start) AS prev_week_revenue,
    ROUND(
        (revenue - LAG(revenue) OVER (ORDER BY week_start)) /
        NULLIF(LAG(revenue) OVER (ORDER BY week_start), 0) * 100,
        2
    ) AS wow_growth_pct,
    -- 4-week ago comparison (same week previous month)
    LAG(revenue, 4) OVER (ORDER BY week_start) AS same_week_prev_month,
    ROUND(
        (revenue - LAG(revenue, 4) OVER (ORDER BY week_start)) /
        NULLIF(LAG(revenue, 4) OVER (ORDER BY week_start), 0) * 100,
        2
    ) AS vs_4_weeks_ago_pct,
    -- Rolling 4-week average
    ROUND(
        AVG(revenue) OVER (
            ORDER BY week_start
            ROWS BETWEEN 3 PRECEDING AND CURRENT ROW
        ), 2
    ) AS rolling_4_week_avg
FROM weekly_metrics
ORDER BY week_start;


-- =============================================================================
-- Seasonality Analysis
-- =============================================================================
-- Detect patterns by day of week and month

-- Day of Week Patterns
WITH daily_stats AS (
    SELECT
        EXTRACT(DOW FROM transaction_date) AS day_of_week,
        TO_CHAR(transaction_date, 'Day') AS day_name,
        SUM(amount) AS total_revenue,
        COUNT(*) AS total_transactions,
        COUNT(DISTINCT DATE_TRUNC('day', transaction_date)) AS num_days
    FROM transactions
    WHERE transaction_date >= CURRENT_DATE - INTERVAL '6 months'
    GROUP BY EXTRACT(DOW FROM transaction_date), TO_CHAR(transaction_date, 'Day')
)

SELECT
    day_of_week,
    TRIM(day_name) AS day_name,
    ROUND(total_revenue / num_days, 2) AS avg_daily_revenue,
    ROUND(total_transactions::NUMERIC / num_days, 1) AS avg_daily_transactions,
    -- Index vs average (100 = average)
    ROUND(
        (total_revenue / num_days) /
        (SUM(total_revenue) OVER () / SUM(num_days) OVER ()) * 100,
        1
    ) AS revenue_index
FROM daily_stats
ORDER BY day_of_week;


-- Monthly Patterns
WITH monthly_stats AS (
    SELECT
        EXTRACT(MONTH FROM transaction_date) AS month_num,
        TO_CHAR(transaction_date, 'Month') AS month_name,
        EXTRACT(YEAR FROM transaction_date) AS year,
        SUM(amount) AS revenue
    FROM transactions
    WHERE transaction_date >= CURRENT_DATE - INTERVAL '24 months'
    GROUP BY EXTRACT(MONTH FROM transaction_date),
             TO_CHAR(transaction_date, 'Month'),
             EXTRACT(YEAR FROM transaction_date)
)

SELECT
    month_num,
    TRIM(month_name) AS month_name,
    ROUND(AVG(revenue), 2) AS avg_monthly_revenue,
    COUNT(*) AS years_of_data,
    MIN(revenue) AS min_revenue,
    MAX(revenue) AS max_revenue,
    -- Seasonality index
    ROUND(
        AVG(revenue) / (SUM(AVG(revenue)) OVER () / 12) * 100,
        1
    ) AS seasonality_index
FROM monthly_stats
GROUP BY month_num, month_name
ORDER BY month_num;


-- =============================================================================
-- Growth Rate Analysis
-- =============================================================================

WITH monthly_growth AS (
    SELECT
        DATE_TRUNC('month', transaction_date)::DATE AS month,
        SUM(amount) AS revenue,
        COUNT(DISTINCT customer_id) AS customers
    FROM transactions
    WHERE transaction_date >= CURRENT_DATE - INTERVAL '24 months'
    GROUP BY DATE_TRUNC('month', transaction_date)
)

SELECT
    month,
    revenue,
    customers,
    -- Month-over-month growth
    LAG(revenue) OVER (ORDER BY month) AS prev_month,
    ROUND(
        (revenue - LAG(revenue) OVER (ORDER BY month)) /
        NULLIF(LAG(revenue) OVER (ORDER BY month), 0) * 100,
        2
    ) AS mom_growth,
    -- Year-over-year growth
    LAG(revenue, 12) OVER (ORDER BY month) AS same_month_last_year,
    ROUND(
        (revenue - LAG(revenue, 12) OVER (ORDER BY month)) /
        NULLIF(LAG(revenue, 12) OVER (ORDER BY month), 0) * 100,
        2
    ) AS yoy_growth,
    -- Compound monthly growth rate (CMGR)
    -- Using first month as base
    ROUND(
        (POWER(
            revenue / FIRST_VALUE(revenue) OVER (ORDER BY month),
            1.0 / (ROW_NUMBER() OVER (ORDER BY month) - 1)
        ) - 1) * 100,
        2
    ) AS cmgr
FROM monthly_growth
ORDER BY month;


-- =============================================================================
-- Forecasting Preparation (For Python/ML)
-- =============================================================================
-- Create a clean time series dataset for forecasting

WITH date_spine AS (
    -- Generate all dates in range
    SELECT generate_series(
        (SELECT MIN(DATE_TRUNC('day', transaction_date)) FROM transactions),
        CURRENT_DATE,
        '1 day'::INTERVAL
    )::DATE AS date
),

daily_actuals AS (
    SELECT
        DATE_TRUNC('day', transaction_date)::DATE AS date,
        SUM(amount) AS revenue,
        COUNT(*) AS transactions
    FROM transactions
    GROUP BY DATE_TRUNC('day', transaction_date)
)

SELECT
    ds.date,
    COALESCE(da.revenue, 0) AS revenue,
    COALESCE(da.transactions, 0) AS transactions,
    -- Time features for ML
    EXTRACT(DOW FROM ds.date) AS day_of_week,
    EXTRACT(DAY FROM ds.date) AS day_of_month,
    EXTRACT(MONTH FROM ds.date) AS month,
    EXTRACT(QUARTER FROM ds.date) AS quarter,
    EXTRACT(YEAR FROM ds.date) AS year,
    EXTRACT(WEEK FROM ds.date) AS week_of_year,
    -- Is weekend
    CASE WHEN EXTRACT(DOW FROM ds.date) IN (0, 6) THEN 1 ELSE 0 END AS is_weekend,
    -- Is month end
    CASE WHEN ds.date = (DATE_TRUNC('month', ds.date) + INTERVAL '1 month - 1 day')::DATE
         THEN 1 ELSE 0 END AS is_month_end
FROM date_spine ds
LEFT JOIN daily_actuals da ON ds.date = da.date
ORDER BY ds.date;


-- =============================================================================
-- Anomaly Detection (Statistical)
-- =============================================================================
-- Flag days that are statistical outliers

WITH daily_revenue AS (
    SELECT
        DATE_TRUNC('day', transaction_date)::DATE AS date,
        SUM(amount) AS revenue
    FROM transactions
    WHERE transaction_date >= CURRENT_DATE - INTERVAL '90 days'
    GROUP BY DATE_TRUNC('day', transaction_date)
),

stats AS (
    SELECT
        AVG(revenue) AS mean_revenue,
        STDDEV(revenue) AS stddev_revenue
    FROM daily_revenue
)

SELECT
    dr.date,
    dr.revenue,
    ROUND(s.mean_revenue, 2) AS mean,
    ROUND(s.stddev_revenue, 2) AS stddev,
    ROUND((dr.revenue - s.mean_revenue) / NULLIF(s.stddev_revenue, 0), 2) AS z_score,
    CASE
        WHEN ABS((dr.revenue - s.mean_revenue) / NULLIF(s.stddev_revenue, 0)) > 3 THEN 'Extreme Outlier'
        WHEN ABS((dr.revenue - s.mean_revenue) / NULLIF(s.stddev_revenue, 0)) > 2 THEN 'Outlier'
        WHEN ABS((dr.revenue - s.mean_revenue) / NULLIF(s.stddev_revenue, 0)) > 1.5 THEN 'Unusual'
        ELSE 'Normal'
    END AS status
FROM daily_revenue dr
CROSS JOIN stats s
ORDER BY ABS((dr.revenue - s.mean_revenue) / NULLIF(s.stddev_revenue, 0)) DESC;
