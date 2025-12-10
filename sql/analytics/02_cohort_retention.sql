-- =============================================================================
-- Cohort Retention Analysis
-- =============================================================================
-- Demonstrates: Window functions, self-joins, date math, pivot-style aggregation,
--               cohort assignment, retention curve calculation
--
-- Purpose: Track customer retention by signup cohort over time
-- =============================================================================

-- Step 1: Assign customers to cohorts based on first purchase
WITH customer_cohorts AS (
    SELECT
        customer_id,
        DATE_TRUNC('month', MIN(transaction_date))::DATE AS cohort_month,
        MIN(transaction_date) AS first_purchase_date
    FROM transactions
    GROUP BY customer_id
),

-- Step 2: Get all customer activity months
customer_activities AS (
    SELECT DISTINCT
        t.customer_id,
        c.cohort_month,
        DATE_TRUNC('month', t.transaction_date)::DATE AS activity_month
    FROM transactions t
    INNER JOIN customer_cohorts c ON t.customer_id = c.customer_id
),

-- Step 3: Calculate months since cohort start
cohort_activity AS (
    SELECT
        customer_id,
        cohort_month,
        activity_month,
        -- Calculate period number (months since signup)
        (EXTRACT(YEAR FROM activity_month) - EXTRACT(YEAR FROM cohort_month)) * 12 +
        (EXTRACT(MONTH FROM activity_month) - EXTRACT(MONTH FROM cohort_month)) AS period_number
    FROM customer_activities
),

-- Step 4: Count cohort sizes
cohort_sizes AS (
    SELECT
        cohort_month,
        COUNT(DISTINCT customer_id) AS cohort_size
    FROM customer_cohorts
    GROUP BY cohort_month
),

-- Step 5: Count active customers per cohort per period
retention_counts AS (
    SELECT
        ca.cohort_month,
        ca.period_number,
        COUNT(DISTINCT ca.customer_id) AS active_customers
    FROM cohort_activity ca
    WHERE ca.period_number >= 0
      AND ca.period_number <= 12  -- Track up to 12 months
    GROUP BY ca.cohort_month, ca.period_number
)

-- Final: Calculate retention percentages
SELECT
    rc.cohort_month,
    cs.cohort_size,
    rc.period_number,
    rc.active_customers,
    ROUND(
        rc.active_customers::NUMERIC / cs.cohort_size * 100,
        2
    ) AS retention_pct
FROM retention_counts rc
JOIN cohort_sizes cs ON rc.cohort_month = cs.cohort_month
ORDER BY rc.cohort_month, rc.period_number;


-- =============================================================================
-- Cohort Retention Matrix (Pivot Format)
-- =============================================================================
-- Creates a heatmap-ready format with cohorts as rows, periods as columns

WITH customer_cohorts AS (
    SELECT
        customer_id,
        DATE_TRUNC('month', MIN(transaction_date))::DATE AS cohort_month
    FROM transactions
    GROUP BY customer_id
),

cohort_activity AS (
    SELECT DISTINCT
        c.cohort_month,
        c.customer_id,
        (EXTRACT(YEAR FROM DATE_TRUNC('month', t.transaction_date)) - EXTRACT(YEAR FROM c.cohort_month)) * 12 +
        (EXTRACT(MONTH FROM DATE_TRUNC('month', t.transaction_date)) - EXTRACT(MONTH FROM c.cohort_month)) AS period_number
    FROM customer_cohorts c
    JOIN transactions t ON c.customer_id = t.customer_id
),

cohort_sizes AS (
    SELECT cohort_month, COUNT(DISTINCT customer_id) AS size
    FROM customer_cohorts
    GROUP BY cohort_month
)

SELECT
    ca.cohort_month,
    cs.size AS cohort_size,
    -- Pivot periods into columns (Month 0 through Month 6)
    ROUND(COUNT(DISTINCT CASE WHEN period_number = 0 THEN ca.customer_id END)::NUMERIC / cs.size * 100, 1) AS month_0,
    ROUND(COUNT(DISTINCT CASE WHEN period_number = 1 THEN ca.customer_id END)::NUMERIC / cs.size * 100, 1) AS month_1,
    ROUND(COUNT(DISTINCT CASE WHEN period_number = 2 THEN ca.customer_id END)::NUMERIC / cs.size * 100, 1) AS month_2,
    ROUND(COUNT(DISTINCT CASE WHEN period_number = 3 THEN ca.customer_id END)::NUMERIC / cs.size * 100, 1) AS month_3,
    ROUND(COUNT(DISTINCT CASE WHEN period_number = 4 THEN ca.customer_id END)::NUMERIC / cs.size * 100, 1) AS month_4,
    ROUND(COUNT(DISTINCT CASE WHEN period_number = 5 THEN ca.customer_id END)::NUMERIC / cs.size * 100, 1) AS month_5,
    ROUND(COUNT(DISTINCT CASE WHEN period_number = 6 THEN ca.customer_id END)::NUMERIC / cs.size * 100, 1) AS month_6
FROM cohort_activity ca
JOIN cohort_sizes cs ON ca.cohort_month = cs.cohort_month
WHERE ca.cohort_month >= CURRENT_DATE - INTERVAL '12 months'
GROUP BY ca.cohort_month, cs.size
ORDER BY ca.cohort_month;


-- =============================================================================
-- Retention by Customer Segment
-- =============================================================================

WITH customer_cohorts AS (
    SELECT
        t.customer_id,
        c.segment,
        DATE_TRUNC('month', MIN(t.transaction_date))::DATE AS cohort_month
    FROM transactions t
    JOIN customers c ON t.customer_id = c.customer_id
    GROUP BY t.customer_id, c.segment
),

segment_retention AS (
    SELECT
        cc.segment,
        cc.cohort_month,
        (EXTRACT(YEAR FROM DATE_TRUNC('month', t.transaction_date)) - EXTRACT(YEAR FROM cc.cohort_month)) * 12 +
        (EXTRACT(MONTH FROM DATE_TRUNC('month', t.transaction_date)) - EXTRACT(MONTH FROM cc.cohort_month)) AS period_number,
        COUNT(DISTINCT t.customer_id) AS active_customers
    FROM customer_cohorts cc
    JOIN transactions t ON cc.customer_id = t.customer_id
    GROUP BY cc.segment, cc.cohort_month,
        (EXTRACT(YEAR FROM DATE_TRUNC('month', t.transaction_date)) - EXTRACT(YEAR FROM cc.cohort_month)) * 12 +
        (EXTRACT(MONTH FROM DATE_TRUNC('month', t.transaction_date)) - EXTRACT(MONTH FROM cc.cohort_month))
),

segment_cohort_sizes AS (
    SELECT segment, cohort_month, COUNT(DISTINCT customer_id) AS cohort_size
    FROM customer_cohorts
    GROUP BY segment, cohort_month
)

SELECT
    sr.segment,
    sr.period_number,
    AVG(sr.active_customers::NUMERIC / scs.cohort_size * 100) AS avg_retention_pct,
    COUNT(DISTINCT sr.cohort_month) AS num_cohorts
FROM segment_retention sr
JOIN segment_cohort_sizes scs
    ON sr.segment = scs.segment AND sr.cohort_month = scs.cohort_month
WHERE sr.period_number BETWEEN 0 AND 6
GROUP BY sr.segment, sr.period_number
ORDER BY sr.segment, sr.period_number;


-- =============================================================================
-- Churn Analysis
-- =============================================================================
-- Identify churned customers (no activity in last 90 days)

WITH customer_last_activity AS (
    SELECT
        customer_id,
        MAX(transaction_date) AS last_transaction_date,
        COUNT(*) AS total_transactions,
        SUM(amount) AS lifetime_value
    FROM transactions
    GROUP BY customer_id
),

churn_status AS (
    SELECT
        customer_id,
        last_transaction_date,
        total_transactions,
        lifetime_value,
        CASE
            WHEN last_transaction_date < CURRENT_DATE - INTERVAL '90 days' THEN 'Churned'
            WHEN last_transaction_date < CURRENT_DATE - INTERVAL '60 days' THEN 'At Risk'
            WHEN last_transaction_date < CURRENT_DATE - INTERVAL '30 days' THEN 'Cooling'
            ELSE 'Active'
        END AS status,
        CURRENT_DATE - last_transaction_date::DATE AS days_since_last_purchase
    FROM customer_last_activity
)

SELECT
    status,
    COUNT(*) AS customer_count,
    ROUND(COUNT(*)::NUMERIC / SUM(COUNT(*)) OVER () * 100, 2) AS pct_of_total,
    ROUND(AVG(lifetime_value), 2) AS avg_ltv,
    ROUND(AVG(total_transactions), 1) AS avg_transactions,
    ROUND(AVG(days_since_last_purchase), 0) AS avg_days_inactive
FROM churn_status
GROUP BY status
ORDER BY
    CASE status
        WHEN 'Active' THEN 1
        WHEN 'Cooling' THEN 2
        WHEN 'At Risk' THEN 3
        WHEN 'Churned' THEN 4
    END;
