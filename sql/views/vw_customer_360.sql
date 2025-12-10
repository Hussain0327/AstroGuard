-- =============================================================================
-- Customer 360 View
-- =============================================================================
-- Demonstrates: Customer dimension, aggregations across tables, RFM metrics,
--               lifetime value calculation, customer health scoring
--
-- Purpose: Single comprehensive view of each customer for analytics
-- =============================================================================

-- DROP VIEW IF EXISTS vw_customer_360;

CREATE OR REPLACE VIEW vw_customer_360 AS

WITH customer_transactions AS (
    SELECT
        customer_id,
        COUNT(*) AS total_orders,
        SUM(amount) AS total_revenue,
        AVG(amount) AS avg_order_value,
        MIN(transaction_date) AS first_order_date,
        MAX(transaction_date) AS last_order_date,
        COUNT(DISTINCT DATE_TRUNC('month', transaction_date)) AS active_months,
        SUM(quantity) AS total_units_purchased
    FROM transactions
    GROUP BY customer_id
),

customer_rfm AS (
    SELECT
        customer_id,
        -- Recency: days since last purchase
        CURRENT_DATE - MAX(transaction_date)::DATE AS recency_days,
        -- Frequency: number of orders
        COUNT(*) AS frequency,
        -- Monetary: total spend
        SUM(amount) AS monetary
    FROM transactions
    WHERE transaction_date >= CURRENT_DATE - INTERVAL '24 months'
    GROUP BY customer_id
),

rfm_scores AS (
    SELECT
        customer_id,
        recency_days,
        frequency,
        monetary,
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency) AS f_score,
        NTILE(5) OVER (ORDER BY monetary) AS m_score
    FROM customer_rfm
),

customer_marketing AS (
    SELECT
        customer_id,
        MIN(CASE WHEN stage = 'lead' THEN event_date END) AS first_touch_date,
        MIN(CASE WHEN stage = 'customer' THEN event_date END) AS conversion_date,
        MODE() WITHIN GROUP (ORDER BY channel) AS primary_channel,
        COUNT(DISTINCT campaign) AS campaigns_touched
    FROM marketing_events
    WHERE customer_id IS NOT NULL
    GROUP BY customer_id
),

customer_experiments AS (
    SELECT
        customer_id,
        COUNT(DISTINCT experiment_id) AS experiments_participated
    FROM variant_results vr
    JOIN experiments e ON vr.experiment_id = e.experiment_id
    -- Assuming there's a way to link customers to experiments
    -- This is a simplified version
    GROUP BY customer_id
)

SELECT
    -- Customer Identity
    c.customer_id,
    c.email,
    c.name,
    c.segment,
    c.created_at AS account_created,

    -- Transaction Summary
    COALESCE(ct.total_orders, 0) AS total_orders,
    ROUND(COALESCE(ct.total_revenue, 0), 2) AS lifetime_value,
    ROUND(COALESCE(ct.avg_order_value, 0), 2) AS avg_order_value,
    ct.first_order_date,
    ct.last_order_date,
    COALESCE(ct.active_months, 0) AS active_months,
    COALESCE(ct.total_units_purchased, 0) AS total_units,

    -- Customer Tenure
    CURRENT_DATE - c.created_at::DATE AS account_age_days,
    CURRENT_DATE - COALESCE(ct.first_order_date, c.created_at)::DATE AS customer_age_days,
    COALESCE(CURRENT_DATE - ct.last_order_date::DATE, 999) AS days_since_last_order,

    -- RFM Scores
    COALESCE(rs.r_score, 1) AS recency_score,
    COALESCE(rs.f_score, 1) AS frequency_score,
    COALESCE(rs.m_score, 1) AS monetary_score,
    COALESCE(rs.r_score, 1) + COALESCE(rs.f_score, 1) + COALESCE(rs.m_score, 1) AS rfm_total,

    -- Customer Segment (derived from RFM)
    CASE
        WHEN rs.r_score >= 4 AND rs.f_score >= 4 AND rs.m_score >= 4 THEN 'Champion'
        WHEN rs.f_score >= 4 AND rs.m_score >= 3 THEN 'Loyal'
        WHEN rs.r_score >= 4 AND rs.f_score <= 2 THEN 'New Customer'
        WHEN rs.r_score <= 2 AND rs.f_score >= 4 THEN 'At Risk'
        WHEN rs.r_score <= 2 AND rs.f_score <= 2 THEN 'Hibernating'
        WHEN rs.r_score >= 3 THEN 'Potential Loyalist'
        ELSE 'Need Attention'
    END AS rfm_segment,

    -- Customer Health Score (0-100)
    LEAST(100, GREATEST(0,
        -- Recency component (40 points max)
        CASE
            WHEN CURRENT_DATE - ct.last_order_date::DATE <= 30 THEN 40
            WHEN CURRENT_DATE - ct.last_order_date::DATE <= 60 THEN 30
            WHEN CURRENT_DATE - ct.last_order_date::DATE <= 90 THEN 20
            WHEN CURRENT_DATE - ct.last_order_date::DATE <= 180 THEN 10
            ELSE 0
        END +
        -- Frequency component (30 points max)
        LEAST(30, COALESCE(ct.total_orders, 0) * 3) +
        -- Value component (30 points max)
        CASE
            WHEN ct.total_revenue >= 10000 THEN 30
            WHEN ct.total_revenue >= 5000 THEN 25
            WHEN ct.total_revenue >= 1000 THEN 20
            WHEN ct.total_revenue >= 500 THEN 15
            WHEN ct.total_revenue >= 100 THEN 10
            ELSE 5
        END
    )) AS health_score,

    -- Marketing Attribution
    cm.first_touch_date,
    cm.conversion_date,
    cm.primary_channel AS acquisition_channel,
    COALESCE(cm.campaigns_touched, 0) AS marketing_touches,

    -- Predicted Churn Risk
    CASE
        WHEN CURRENT_DATE - ct.last_order_date::DATE > 180 THEN 'High'
        WHEN CURRENT_DATE - ct.last_order_date::DATE > 90 THEN 'Medium'
        WHEN CURRENT_DATE - ct.last_order_date::DATE > 60 THEN 'Low'
        ELSE 'Very Low'
    END AS churn_risk,

    -- Value Tier
    CASE
        WHEN ct.total_revenue >= (SELECT PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY total_revenue) FROM customer_transactions) THEN 'Platinum'
        WHEN ct.total_revenue >= (SELECT PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY total_revenue) FROM customer_transactions) THEN 'Gold'
        WHEN ct.total_revenue >= (SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY total_revenue) FROM customer_transactions) THEN 'Silver'
        ELSE 'Bronze'
    END AS value_tier,

    -- Metadata
    CURRENT_TIMESTAMP AS snapshot_timestamp

FROM customers c
LEFT JOIN customer_transactions ct ON c.customer_id = ct.customer_id
LEFT JOIN rfm_scores rs ON c.customer_id = rs.customer_id
LEFT JOIN customer_marketing cm ON c.customer_id = cm.customer_id;


-- =============================================================================
-- Sample Queries Using the View
-- =============================================================================

-- High-value customers at risk
/*
SELECT
    customer_id,
    email,
    lifetime_value,
    days_since_last_order,
    rfm_segment,
    churn_risk,
    health_score
FROM vw_customer_360
WHERE value_tier IN ('Platinum', 'Gold')
  AND churn_risk IN ('High', 'Medium')
ORDER BY lifetime_value DESC;
*/

-- Segment distribution
/*
SELECT
    rfm_segment,
    COUNT(*) AS customer_count,
    ROUND(AVG(lifetime_value), 2) AS avg_ltv,
    ROUND(AVG(health_score), 1) AS avg_health_score
FROM vw_customer_360
GROUP BY rfm_segment
ORDER BY avg_ltv DESC;
*/

-- Acquisition channel performance
/*
SELECT
    acquisition_channel,
    COUNT(*) AS customers,
    ROUND(AVG(lifetime_value), 2) AS avg_ltv,
    ROUND(AVG(total_orders), 1) AS avg_orders,
    ROUND(AVG(health_score), 1) AS avg_health
FROM vw_customer_360
WHERE acquisition_channel IS NOT NULL
GROUP BY acquisition_channel
ORDER BY avg_ltv DESC;
*/
