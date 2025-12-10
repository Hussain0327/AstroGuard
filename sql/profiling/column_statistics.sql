-- =============================================================================
-- Column Statistics & Distribution Analysis
-- =============================================================================
-- Demonstrates: Statistical functions, percentiles, distribution analysis,
--               cardinality, outlier detection
--
-- Purpose: Generate detailed statistics for each column for data profiling
-- =============================================================================

-- =============================================================================
-- Numeric Column Statistics
-- =============================================================================

-- Transaction Amount Statistics
SELECT
    'transactions.amount' AS column_name,
    COUNT(*) AS total_rows,
    COUNT(amount) AS non_null_count,
    COUNT(*) - COUNT(amount) AS null_count,
    ROUND((COUNT(*) - COUNT(amount))::NUMERIC / COUNT(*) * 100, 2) AS null_pct,
    ROUND(MIN(amount), 2) AS min_value,
    ROUND(MAX(amount), 2) AS max_value,
    ROUND(AVG(amount), 2) AS mean,
    ROUND(STDDEV(amount), 2) AS std_dev,
    ROUND(VARIANCE(amount), 2) AS variance,
    -- Percentiles
    ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY amount)::NUMERIC, 2) AS p25,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY amount)::NUMERIC, 2) AS median,
    ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY amount)::NUMERIC, 2) AS p75,
    ROUND(PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY amount)::NUMERIC, 2) AS p90,
    ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY amount)::NUMERIC, 2) AS p95,
    ROUND(PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY amount)::NUMERIC, 2) AS p99,
    -- IQR for outlier detection
    ROUND(
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY amount)::NUMERIC -
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY amount)::NUMERIC,
        2
    ) AS iqr
FROM transactions;


-- =============================================================================
-- Histogram / Distribution Buckets
-- =============================================================================

-- Transaction Amount Distribution (10 equal-width buckets)
WITH amount_range AS (
    SELECT
        MIN(amount) AS min_val,
        MAX(amount) AS max_val,
        (MAX(amount) - MIN(amount)) / 10 AS bucket_width
    FROM transactions
    WHERE amount IS NOT NULL
)

SELECT
    bucket,
    ROUND(lower_bound, 2) AS range_start,
    ROUND(upper_bound, 2) AS range_end,
    count,
    ROUND(count::NUMERIC / SUM(count) OVER () * 100, 2) AS pct_of_total,
    REPEAT('*', (count::NUMERIC / MAX(count) OVER () * 50)::INT) AS histogram
FROM (
    SELECT
        WIDTH_BUCKET(amount, ar.min_val, ar.max_val + 0.01, 10) AS bucket,
        ar.min_val + (WIDTH_BUCKET(amount, ar.min_val, ar.max_val + 0.01, 10) - 1) * ar.bucket_width AS lower_bound,
        ar.min_val + WIDTH_BUCKET(amount, ar.min_val, ar.max_val + 0.01, 10) * ar.bucket_width AS upper_bound,
        COUNT(*) AS count
    FROM transactions, amount_range ar
    WHERE amount IS NOT NULL
    GROUP BY WIDTH_BUCKET(amount, ar.min_val, ar.max_val + 0.01, 10),
             ar.min_val, ar.bucket_width
) AS buckets
ORDER BY bucket;


-- =============================================================================
-- Cardinality Analysis
-- =============================================================================

SELECT
    'transactions' AS table_name,
    'transaction_id' AS column_name,
    COUNT(DISTINCT transaction_id) AS distinct_values,
    COUNT(*) AS total_rows,
    ROUND(COUNT(DISTINCT transaction_id)::NUMERIC / COUNT(*) * 100, 2) AS uniqueness_pct,
    CASE
        WHEN COUNT(DISTINCT transaction_id) = COUNT(*) THEN 'Unique (PK candidate)'
        WHEN COUNT(DISTINCT transaction_id)::NUMERIC / COUNT(*) > 0.95 THEN 'High cardinality'
        WHEN COUNT(DISTINCT transaction_id)::NUMERIC / COUNT(*) > 0.5 THEN 'Medium cardinality'
        WHEN COUNT(DISTINCT transaction_id)::NUMERIC / COUNT(*) > 0.1 THEN 'Low cardinality'
        ELSE 'Very low cardinality (categorical)'
    END AS cardinality_type
FROM transactions

UNION ALL

SELECT 'transactions', 'customer_id',
    COUNT(DISTINCT customer_id), COUNT(*),
    ROUND(COUNT(DISTINCT customer_id)::NUMERIC / COUNT(*) * 100, 2),
    CASE
        WHEN COUNT(DISTINCT customer_id) = COUNT(*) THEN 'Unique (PK candidate)'
        WHEN COUNT(DISTINCT customer_id)::NUMERIC / COUNT(*) > 0.95 THEN 'High cardinality'
        WHEN COUNT(DISTINCT customer_id)::NUMERIC / COUNT(*) > 0.5 THEN 'Medium cardinality'
        WHEN COUNT(DISTINCT customer_id)::NUMERIC / COUNT(*) > 0.1 THEN 'Low cardinality'
        ELSE 'Very low cardinality (categorical)'
    END
FROM transactions

UNION ALL

SELECT 'transactions', 'channel',
    COUNT(DISTINCT channel), COUNT(*),
    ROUND(COUNT(DISTINCT channel)::NUMERIC / COUNT(*) * 100, 2),
    CASE
        WHEN COUNT(DISTINCT channel) = COUNT(*) THEN 'Unique (PK candidate)'
        WHEN COUNT(DISTINCT channel)::NUMERIC / COUNT(*) > 0.95 THEN 'High cardinality'
        WHEN COUNT(DISTINCT channel)::NUMERIC / COUNT(*) > 0.5 THEN 'Medium cardinality'
        WHEN COUNT(DISTINCT channel)::NUMERIC / COUNT(*) > 0.1 THEN 'Low cardinality'
        ELSE 'Very low cardinality (categorical)'
    END
FROM transactions

UNION ALL

SELECT 'customers', 'segment',
    COUNT(DISTINCT segment), COUNT(*),
    ROUND(COUNT(DISTINCT segment)::NUMERIC / COUNT(*) * 100, 2),
    CASE
        WHEN COUNT(DISTINCT segment) = COUNT(*) THEN 'Unique (PK candidate)'
        WHEN COUNT(DISTINCT segment)::NUMERIC / COUNT(*) > 0.95 THEN 'High cardinality'
        WHEN COUNT(DISTINCT segment)::NUMERIC / COUNT(*) > 0.5 THEN 'Medium cardinality'
        WHEN COUNT(DISTINCT segment)::NUMERIC / COUNT(*) > 0.1 THEN 'Low cardinality'
        ELSE 'Very low cardinality (categorical)'
    END
FROM customers;


-- =============================================================================
-- Top Values Analysis (for categorical columns)
-- =============================================================================

-- Top channels by transaction count
SELECT
    'transactions.channel' AS column_name,
    channel AS value,
    COUNT(*) AS count,
    ROUND(COUNT(*)::NUMERIC / SUM(COUNT(*)) OVER () * 100, 2) AS pct,
    ROUND(SUM(COUNT(*)::NUMERIC) OVER (ORDER BY COUNT(*) DESC) /
          SUM(COUNT(*)) OVER () * 100, 2) AS cumulative_pct
FROM transactions
WHERE channel IS NOT NULL
GROUP BY channel
ORDER BY count DESC
LIMIT 10;

-- Top segments by customer count
SELECT
    'customers.segment' AS column_name,
    segment AS value,
    COUNT(*) AS count,
    ROUND(COUNT(*)::NUMERIC / SUM(COUNT(*)) OVER () * 100, 2) AS pct,
    ROUND(SUM(COUNT(*)::NUMERIC) OVER (ORDER BY COUNT(*) DESC) /
          SUM(COUNT(*)) OVER () * 100, 2) AS cumulative_pct
FROM customers
WHERE segment IS NOT NULL
GROUP BY segment
ORDER BY count DESC;


-- =============================================================================
-- Outlier Detection (IQR Method)
-- =============================================================================

WITH stats AS (
    SELECT
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY amount) AS q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY amount) AS q3
    FROM transactions
    WHERE amount IS NOT NULL
),

bounds AS (
    SELECT
        q1,
        q3,
        q3 - q1 AS iqr,
        q1 - 1.5 * (q3 - q1) AS lower_bound,
        q3 + 1.5 * (q3 - q1) AS upper_bound
    FROM stats
)

SELECT
    'transactions.amount' AS column_name,
    ROUND(b.q1, 2) AS q1,
    ROUND(b.q3, 2) AS q3,
    ROUND(b.iqr, 2) AS iqr,
    ROUND(b.lower_bound, 2) AS lower_fence,
    ROUND(b.upper_bound, 2) AS upper_fence,
    COUNT(CASE WHEN t.amount < b.lower_bound THEN 1 END) AS low_outliers,
    COUNT(CASE WHEN t.amount > b.upper_bound THEN 1 END) AS high_outliers,
    COUNT(CASE WHEN t.amount < b.lower_bound OR t.amount > b.upper_bound THEN 1 END) AS total_outliers,
    ROUND(
        COUNT(CASE WHEN t.amount < b.lower_bound OR t.amount > b.upper_bound THEN 1 END)::NUMERIC /
        COUNT(*) * 100,
        2
    ) AS outlier_pct
FROM transactions t
CROSS JOIN bounds b
GROUP BY b.q1, b.q3, b.iqr, b.lower_bound, b.upper_bound;


-- Show actual outlier records
WITH stats AS (
    SELECT
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY amount) AS q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY amount) AS q3
    FROM transactions
)

SELECT
    transaction_id,
    customer_id,
    amount,
    transaction_date,
    CASE
        WHEN amount < (SELECT q1 - 1.5 * (q3 - q1) FROM stats) THEN 'Low Outlier'
        WHEN amount > (SELECT q3 + 1.5 * (q3 - q1) FROM stats) THEN 'High Outlier'
    END AS outlier_type
FROM transactions
WHERE amount < (SELECT q1 - 1.5 * (q3 - q1) FROM stats)
   OR amount > (SELECT q3 + 1.5 * (q3 - q1) FROM stats)
ORDER BY amount DESC
LIMIT 20;


-- =============================================================================
-- Date Column Statistics
-- =============================================================================

SELECT
    'transactions.transaction_date' AS column_name,
    COUNT(*) AS total_rows,
    COUNT(transaction_date) AS non_null_count,
    MIN(transaction_date) AS min_date,
    MAX(transaction_date) AS max_date,
    MAX(transaction_date)::DATE - MIN(transaction_date)::DATE AS date_range_days,
    COUNT(DISTINCT transaction_date::DATE) AS distinct_days,
    ROUND(COUNT(*)::NUMERIC / NULLIF(COUNT(DISTINCT transaction_date::DATE), 0), 2) AS avg_records_per_day
FROM transactions;


-- =============================================================================
-- String Length Statistics
-- =============================================================================

SELECT
    'customers.email' AS column_name,
    COUNT(*) AS total_rows,
    COUNT(email) AS non_null_count,
    MIN(LENGTH(email)) AS min_length,
    MAX(LENGTH(email)) AS max_length,
    ROUND(AVG(LENGTH(email)), 2) AS avg_length,
    COUNT(CASE WHEN email !~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN 1 END) AS invalid_email_count
FROM customers;


-- =============================================================================
-- Correlation Analysis (Revenue vs Quantity)
-- =============================================================================

SELECT
    ROUND(CORR(amount, quantity)::NUMERIC, 4) AS amount_quantity_correlation,
    CASE
        WHEN ABS(CORR(amount, quantity)) > 0.7 THEN 'Strong'
        WHEN ABS(CORR(amount, quantity)) > 0.4 THEN 'Moderate'
        WHEN ABS(CORR(amount, quantity)) > 0.2 THEN 'Weak'
        ELSE 'Very Weak/None'
    END AS correlation_strength
FROM transactions
WHERE amount IS NOT NULL AND quantity IS NOT NULL;
