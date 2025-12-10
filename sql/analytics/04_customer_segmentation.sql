-- =============================================================================
-- Customer Segmentation (RFM Analysis)
-- =============================================================================
-- Demonstrates: Window functions (NTILE, ROW_NUMBER), CASE statements,
--               subqueries, customer scoring, segmentation logic
--
-- Purpose: Segment customers using RFM (Recency, Frequency, Monetary) analysis
-- =============================================================================

-- Step 1: Calculate RFM metrics for each customer
WITH customer_rfm_raw AS (
    SELECT
        customer_id,
        -- Recency: Days since last purchase (lower is better)
        CURRENT_DATE - MAX(transaction_date)::DATE AS recency_days,
        -- Frequency: Number of orders
        COUNT(DISTINCT DATE_TRUNC('day', transaction_date)) AS frequency,
        -- Monetary: Total spend
        SUM(amount) AS monetary,
        -- Additional metrics
        AVG(amount) AS avg_order_value,
        MIN(transaction_date) AS first_purchase,
        MAX(transaction_date) AS last_purchase
    FROM transactions
    WHERE transaction_date >= CURRENT_DATE - INTERVAL '24 months'
    GROUP BY customer_id
),

-- Step 2: Assign quintile scores (1-5) for each metric
customer_rfm_scores AS (
    SELECT
        customer_id,
        recency_days,
        frequency,
        monetary,
        avg_order_value,
        first_purchase,
        last_purchase,
        -- Recency score (5 = most recent, 1 = least recent)
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
        -- Frequency score (5 = most frequent, 1 = least frequent)
        NTILE(5) OVER (ORDER BY frequency) AS f_score,
        -- Monetary score (5 = highest spend, 1 = lowest spend)
        NTILE(5) OVER (ORDER BY monetary) AS m_score
    FROM customer_rfm_raw
),

-- Step 3: Create RFM segments
customer_segments AS (
    SELECT
        *,
        -- Combined RFM score
        r_score + f_score + m_score AS rfm_total,
        -- RFM string for segment identification
        r_score::TEXT || f_score::TEXT || m_score::TEXT AS rfm_string,
        -- Segment assignment based on RFM patterns
        CASE
            -- Champions: Recent, frequent, high spenders
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
            -- Loyal: Frequent buyers, may not be recent
            WHEN f_score >= 4 AND m_score >= 3 THEN 'Loyal Customers'
            -- Potential Loyalists: Recent, moderate frequency
            WHEN r_score >= 4 AND f_score >= 2 AND f_score <= 4 THEN 'Potential Loyalists'
            -- Recent Customers: New, only 1-2 purchases
            WHEN r_score >= 4 AND f_score <= 2 THEN 'Recent Customers'
            -- Promising: Recent, low frequency, low monetary
            WHEN r_score >= 3 AND f_score <= 2 AND m_score <= 2 THEN 'Promising'
            -- Need Attention: Above average but slipping
            WHEN r_score >= 2 AND r_score <= 3 AND f_score >= 2 AND f_score <= 3 THEN 'Need Attention'
            -- About to Sleep: Below average, at risk
            WHEN r_score <= 2 AND f_score >= 2 THEN 'About to Sleep'
            -- At Risk: High value customers going dormant
            WHEN r_score <= 2 AND f_score >= 4 AND m_score >= 4 THEN 'At Risk'
            -- Can't Lose: Were great customers, now inactive
            WHEN r_score <= 2 AND f_score >= 3 AND m_score >= 4 THEN 'Cant Lose Them'
            -- Hibernating: Low across all metrics
            WHEN r_score <= 2 AND f_score <= 2 THEN 'Hibernating'
            -- Lost: Very low engagement
            ELSE 'Lost'
        END AS segment
    FROM customer_rfm_scores
)

SELECT
    customer_id,
    recency_days,
    frequency,
    ROUND(monetary, 2) AS monetary,
    ROUND(avg_order_value, 2) AS avg_order_value,
    first_purchase,
    last_purchase,
    r_score,
    f_score,
    m_score,
    rfm_string,
    rfm_total,
    segment
FROM customer_segments
ORDER BY rfm_total DESC, monetary DESC;


-- =============================================================================
-- Segment Summary Statistics
-- =============================================================================

WITH customer_rfm AS (
    SELECT
        customer_id,
        CURRENT_DATE - MAX(transaction_date)::DATE AS recency_days,
        COUNT(DISTINCT DATE_TRUNC('day', transaction_date)) AS frequency,
        SUM(amount) AS monetary
    FROM transactions
    WHERE transaction_date >= CURRENT_DATE - INTERVAL '24 months'
    GROUP BY customer_id
),

scored AS (
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

segmented AS (
    SELECT
        *,
        CASE
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
            WHEN f_score >= 4 AND m_score >= 3 THEN 'Loyal Customers'
            WHEN r_score >= 4 AND f_score >= 2 AND f_score <= 4 THEN 'Potential Loyalists'
            WHEN r_score >= 4 AND f_score <= 2 THEN 'Recent Customers'
            WHEN r_score >= 3 AND f_score <= 2 AND m_score <= 2 THEN 'Promising'
            WHEN r_score >= 2 AND r_score <= 3 AND f_score >= 2 AND f_score <= 3 THEN 'Need Attention'
            WHEN r_score <= 2 AND f_score >= 2 THEN 'About to Sleep'
            WHEN r_score <= 2 AND f_score >= 4 AND m_score >= 4 THEN 'At Risk'
            WHEN r_score <= 2 AND f_score >= 3 AND m_score >= 4 THEN 'Cant Lose Them'
            WHEN r_score <= 2 AND f_score <= 2 THEN 'Hibernating'
            ELSE 'Lost'
        END AS segment
    FROM scored
)

SELECT
    segment,
    COUNT(*) AS customer_count,
    ROUND(COUNT(*)::NUMERIC / SUM(COUNT(*)) OVER () * 100, 2) AS pct_of_customers,
    ROUND(AVG(recency_days), 1) AS avg_recency_days,
    ROUND(AVG(frequency), 1) AS avg_frequency,
    ROUND(AVG(monetary), 2) AS avg_monetary,
    ROUND(SUM(monetary), 2) AS total_revenue,
    ROUND(SUM(monetary) / SUM(SUM(monetary)) OVER () * 100, 2) AS pct_of_revenue
FROM segmented
GROUP BY segment
ORDER BY total_revenue DESC;


-- =============================================================================
-- Customer Value Tiers
-- =============================================================================
-- Simpler segmentation based on value percentiles

WITH customer_value AS (
    SELECT
        customer_id,
        SUM(amount) AS total_spend,
        COUNT(*) AS order_count,
        AVG(amount) AS avg_order,
        MAX(transaction_date) AS last_order
    FROM transactions
    WHERE transaction_date >= CURRENT_DATE - INTERVAL '12 months'
    GROUP BY customer_id
),

value_percentiles AS (
    SELECT
        customer_id,
        total_spend,
        order_count,
        avg_order,
        last_order,
        PERCENT_RANK() OVER (ORDER BY total_spend) AS spend_percentile
    FROM customer_value
)

SELECT
    CASE
        WHEN spend_percentile >= 0.9 THEN 'Platinum (Top 10%)'
        WHEN spend_percentile >= 0.75 THEN 'Gold (Top 25%)'
        WHEN spend_percentile >= 0.5 THEN 'Silver (Top 50%)'
        ELSE 'Bronze (Bottom 50%)'
    END AS value_tier,
    COUNT(*) AS customer_count,
    ROUND(AVG(total_spend), 2) AS avg_spend,
    ROUND(AVG(order_count), 1) AS avg_orders,
    ROUND(SUM(total_spend), 2) AS tier_revenue,
    ROUND(SUM(total_spend) / SUM(SUM(total_spend)) OVER () * 100, 2) AS revenue_contribution_pct
FROM value_percentiles
GROUP BY
    CASE
        WHEN spend_percentile >= 0.9 THEN 'Platinum (Top 10%)'
        WHEN spend_percentile >= 0.75 THEN 'Gold (Top 25%)'
        WHEN spend_percentile >= 0.5 THEN 'Silver (Top 50%)'
        ELSE 'Bronze (Bottom 50%)'
    END
ORDER BY avg_spend DESC;


-- =============================================================================
-- Segment Migration Analysis
-- =============================================================================
-- Track how customers move between segments over time

WITH segment_period_1 AS (
    -- Segment 6 months ago
    SELECT
        customer_id,
        CASE
            WHEN NTILE(5) OVER (ORDER BY SUM(amount) DESC) = 1 THEN 'High Value'
            WHEN NTILE(5) OVER (ORDER BY SUM(amount) DESC) <= 3 THEN 'Medium Value'
            ELSE 'Low Value'
        END AS segment_then
    FROM transactions
    WHERE transaction_date BETWEEN CURRENT_DATE - INTERVAL '12 months'
                               AND CURRENT_DATE - INTERVAL '6 months'
    GROUP BY customer_id
),

segment_period_2 AS (
    -- Current segment
    SELECT
        customer_id,
        CASE
            WHEN NTILE(5) OVER (ORDER BY SUM(amount) DESC) = 1 THEN 'High Value'
            WHEN NTILE(5) OVER (ORDER BY SUM(amount) DESC) <= 3 THEN 'Medium Value'
            ELSE 'Low Value'
        END AS segment_now
    FROM transactions
    WHERE transaction_date >= CURRENT_DATE - INTERVAL '6 months'
    GROUP BY customer_id
)

SELECT
    COALESCE(s1.segment_then, 'New Customer') AS from_segment,
    COALESCE(s2.segment_now, 'Churned') AS to_segment,
    COUNT(*) AS customer_count,
    ROUND(COUNT(*)::NUMERIC / SUM(COUNT(*)) OVER (PARTITION BY COALESCE(s1.segment_then, 'New Customer')) * 100, 2) AS pct_of_from_segment
FROM segment_period_1 s1
FULL OUTER JOIN segment_period_2 s2 ON s1.customer_id = s2.customer_id
GROUP BY COALESCE(s1.segment_then, 'New Customer'), COALESCE(s2.segment_now, 'Churned')
ORDER BY from_segment, to_segment;
