-- =============================================================================
-- Data Quality Check Queries
-- =============================================================================
-- Demonstrates: NULL analysis, duplicate detection, referential integrity,
--               data freshness, completeness metrics
--
-- Purpose: Profile data quality issues before analysis
-- =============================================================================

-- =============================================================================
-- Table-Level Quality Summary
-- =============================================================================

-- Transactions Table Quality
SELECT
    'transactions' AS table_name,
    COUNT(*) AS total_rows,
    COUNT(DISTINCT transaction_id) AS unique_ids,
    COUNT(*) - COUNT(DISTINCT transaction_id) AS duplicate_ids,
    COUNT(customer_id) AS non_null_customer_id,
    COUNT(*) - COUNT(customer_id) AS null_customer_id,
    COUNT(amount) AS non_null_amount,
    COUNT(*) - COUNT(amount) AS null_amount,
    MIN(transaction_date) AS earliest_date,
    MAX(transaction_date) AS latest_date,
    CURRENT_DATE - MAX(transaction_date)::DATE AS days_since_last_record
FROM transactions

UNION ALL

-- Customers Table Quality
SELECT
    'customers' AS table_name,
    COUNT(*) AS total_rows,
    COUNT(DISTINCT customer_id) AS unique_ids,
    COUNT(*) - COUNT(DISTINCT customer_id) AS duplicate_ids,
    COUNT(email) AS non_null_email,
    COUNT(*) - COUNT(email) AS null_email,
    COUNT(segment) AS non_null_segment,
    COUNT(*) - COUNT(segment) AS null_segment,
    MIN(created_at) AS earliest_date,
    MAX(created_at) AS latest_date,
    CURRENT_DATE - MAX(created_at)::DATE AS days_since_last_record
FROM customers

UNION ALL

-- Marketing Events Table Quality
SELECT
    'marketing_events' AS table_name,
    COUNT(*) AS total_rows,
    COUNT(DISTINCT event_id) AS unique_ids,
    COUNT(*) - COUNT(DISTINCT event_id) AS duplicate_ids,
    COUNT(channel) AS non_null_channel,
    COUNT(*) - COUNT(channel) AS null_channel,
    COUNT(stage) AS non_null_stage,
    COUNT(*) - COUNT(stage) AS null_stage,
    MIN(event_date) AS earliest_date,
    MAX(event_date) AS latest_date,
    CURRENT_DATE - MAX(event_date)::DATE AS days_since_last_record
FROM marketing_events;


-- =============================================================================
-- Column-Level NULL Analysis
-- =============================================================================

-- Transactions NULL Analysis
SELECT
    'transactions' AS table_name,
    'transaction_id' AS column_name,
    COUNT(*) AS total_rows,
    COUNT(transaction_id) AS non_null_count,
    COUNT(*) - COUNT(transaction_id) AS null_count,
    ROUND((COUNT(*) - COUNT(transaction_id))::NUMERIC / COUNT(*) * 100, 2) AS null_pct
FROM transactions
UNION ALL
SELECT 'transactions', 'customer_id', COUNT(*), COUNT(customer_id),
       COUNT(*) - COUNT(customer_id),
       ROUND((COUNT(*) - COUNT(customer_id))::NUMERIC / COUNT(*) * 100, 2)
FROM transactions
UNION ALL
SELECT 'transactions', 'amount', COUNT(*), COUNT(amount),
       COUNT(*) - COUNT(amount),
       ROUND((COUNT(*) - COUNT(amount))::NUMERIC / COUNT(*) * 100, 2)
FROM transactions
UNION ALL
SELECT 'transactions', 'transaction_date', COUNT(*), COUNT(transaction_date),
       COUNT(*) - COUNT(transaction_date),
       ROUND((COUNT(*) - COUNT(transaction_date))::NUMERIC / COUNT(*) * 100, 2)
FROM transactions
UNION ALL
SELECT 'transactions', 'channel', COUNT(*), COUNT(channel),
       COUNT(*) - COUNT(channel),
       ROUND((COUNT(*) - COUNT(channel))::NUMERIC / COUNT(*) * 100, 2)
FROM transactions
UNION ALL
SELECT 'transactions', 'product_id', COUNT(*), COUNT(product_id),
       COUNT(*) - COUNT(product_id),
       ROUND((COUNT(*) - COUNT(product_id))::NUMERIC / COUNT(*) * 100, 2)
FROM transactions;


-- =============================================================================
-- Duplicate Detection
-- =============================================================================

-- Find duplicate transactions (same customer, amount, date)
SELECT
    customer_id,
    amount,
    transaction_date,
    COUNT(*) AS occurrence_count
FROM transactions
GROUP BY customer_id, amount, transaction_date
HAVING COUNT(*) > 1
ORDER BY COUNT(*) DESC
LIMIT 20;

-- Find duplicate customers (by email)
SELECT
    email,
    COUNT(*) AS occurrence_count,
    ARRAY_AGG(customer_id) AS customer_ids
FROM customers
WHERE email IS NOT NULL
GROUP BY email
HAVING COUNT(*) > 1
ORDER BY COUNT(*) DESC
LIMIT 20;


-- =============================================================================
-- Referential Integrity Checks
-- =============================================================================

-- Transactions with non-existent customers
SELECT
    'Orphan transactions (no customer)' AS issue,
    COUNT(*) AS count
FROM transactions t
LEFT JOIN customers c ON t.customer_id = c.customer_id
WHERE c.customer_id IS NULL
  AND t.customer_id IS NOT NULL;

-- Transactions with non-existent products
SELECT
    'Orphan transactions (no product)' AS issue,
    COUNT(*) AS count
FROM transactions t
LEFT JOIN products p ON t.product_id = p.product_id
WHERE p.product_id IS NULL
  AND t.product_id IS NOT NULL;

-- Marketing events with non-existent customers
SELECT
    'Orphan marketing events (no customer)' AS issue,
    COUNT(*) AS count
FROM marketing_events m
LEFT JOIN customers c ON m.customer_id = c.customer_id
WHERE c.customer_id IS NULL
  AND m.customer_id IS NOT NULL;


-- =============================================================================
-- Value Range Validation
-- =============================================================================

-- Transactions with suspicious amounts
SELECT
    'Negative amounts' AS issue,
    COUNT(*) AS count
FROM transactions
WHERE amount < 0

UNION ALL

SELECT
    'Zero amounts' AS issue,
    COUNT(*) AS count
FROM transactions
WHERE amount = 0

UNION ALL

SELECT
    'Extremely large amounts (>$100K)' AS issue,
    COUNT(*) AS count
FROM transactions
WHERE amount > 100000

UNION ALL

SELECT
    'Future dates' AS issue,
    COUNT(*) AS count
FROM transactions
WHERE transaction_date > CURRENT_DATE

UNION ALL

SELECT
    'Very old dates (>5 years)' AS issue,
    COUNT(*) AS count
FROM transactions
WHERE transaction_date < CURRENT_DATE - INTERVAL '5 years';


-- =============================================================================
-- Categorical Value Validation
-- =============================================================================

-- Check for unexpected channel values
SELECT
    'transactions' AS table_name,
    'channel' AS column_name,
    channel AS value,
    COUNT(*) AS count
FROM transactions
GROUP BY channel
ORDER BY count DESC;

-- Check for unexpected stage values
SELECT
    'marketing_events' AS table_name,
    'stage' AS column_name,
    stage AS value,
    COUNT(*) AS count
FROM marketing_events
GROUP BY stage
ORDER BY count DESC;

-- Check for unexpected segment values
SELECT
    'customers' AS table_name,
    'segment' AS column_name,
    segment AS value,
    COUNT(*) AS count
FROM customers
GROUP BY segment
ORDER BY count DESC;


-- =============================================================================
-- Data Freshness Check
-- =============================================================================

SELECT
    table_name,
    last_record_date,
    CURRENT_DATE - last_record_date AS days_stale,
    CASE
        WHEN CURRENT_DATE - last_record_date <= 1 THEN 'Fresh'
        WHEN CURRENT_DATE - last_record_date <= 7 THEN 'Slightly Stale'
        WHEN CURRENT_DATE - last_record_date <= 30 THEN 'Stale'
        ELSE 'Very Stale'
    END AS freshness_status
FROM (
    SELECT 'transactions' AS table_name, MAX(transaction_date)::DATE AS last_record_date
    FROM transactions
    UNION ALL
    SELECT 'customers', MAX(created_at)::DATE FROM customers
    UNION ALL
    SELECT 'marketing_events', MAX(event_date)::DATE FROM marketing_events
    UNION ALL
    SELECT 'experiments', MAX(start_date)::DATE FROM experiments
) AS freshness;


-- =============================================================================
-- Completeness Score
-- =============================================================================

WITH completeness AS (
    SELECT
        'transactions' AS table_name,
        COUNT(*) AS total_rows,
        AVG(CASE WHEN transaction_id IS NOT NULL THEN 1 ELSE 0 END) AS transaction_id_complete,
        AVG(CASE WHEN customer_id IS NOT NULL THEN 1 ELSE 0 END) AS customer_id_complete,
        AVG(CASE WHEN amount IS NOT NULL THEN 1 ELSE 0 END) AS amount_complete,
        AVG(CASE WHEN transaction_date IS NOT NULL THEN 1 ELSE 0 END) AS date_complete,
        AVG(CASE WHEN channel IS NOT NULL THEN 1 ELSE 0 END) AS channel_complete
    FROM transactions
)

SELECT
    table_name,
    total_rows,
    ROUND(
        (transaction_id_complete + customer_id_complete + amount_complete +
         date_complete + channel_complete) / 5 * 100,
        2
    ) AS overall_completeness_pct,
    ROUND(transaction_id_complete * 100, 2) AS transaction_id_pct,
    ROUND(customer_id_complete * 100, 2) AS customer_id_pct,
    ROUND(amount_complete * 100, 2) AS amount_pct,
    ROUND(date_complete * 100, 2) AS date_pct,
    ROUND(channel_complete * 100, 2) AS channel_pct
FROM completeness;
