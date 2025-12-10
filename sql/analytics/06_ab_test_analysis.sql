-- =============================================================================
-- A/B Test Analysis
-- =============================================================================
-- Demonstrates: Statistical aggregations, experiment analysis, variant comparison,
--               sample size calculations, significance testing preparation
--
-- Purpose: Analyze A/B test results with proper statistical rigor
-- =============================================================================

-- Experiment Overview
SELECT
    e.experiment_id,
    e.name,
    e.hypothesis,
    e.status,
    e.start_date,
    e.end_date,
    e.end_date - e.start_date AS duration_days,
    COUNT(vr.result_id) AS num_variants,
    SUM(vr.visitors) AS total_visitors,
    SUM(vr.conversions) AS total_conversions,
    ROUND(SUM(vr.conversions)::NUMERIC / NULLIF(SUM(vr.visitors), 0) * 100, 2) AS overall_conversion_rate
FROM experiments e
LEFT JOIN variant_results vr ON e.experiment_id = vr.experiment_id
GROUP BY e.experiment_id, e.name, e.hypothesis, e.status, e.start_date, e.end_date
ORDER BY e.start_date DESC;


-- =============================================================================
-- Variant Comparison (Core A/B Analysis)
-- =============================================================================

WITH variant_stats AS (
    SELECT
        vr.experiment_id,
        e.name AS experiment_name,
        vr.variant_name,
        vr.visitors,
        vr.conversions,
        COALESCE(vr.revenue, 0) AS revenue,
        -- Conversion rate
        vr.conversions::NUMERIC / NULLIF(vr.visitors, 0) AS conversion_rate,
        -- Revenue per visitor
        COALESCE(vr.revenue, 0) / NULLIF(vr.visitors, 0) AS revenue_per_visitor,
        -- Standard error of proportion
        SQRT(
            (vr.conversions::NUMERIC / NULLIF(vr.visitors, 0)) *
            (1 - vr.conversions::NUMERIC / NULLIF(vr.visitors, 0)) /
            NULLIF(vr.visitors, 0)
        ) AS se_proportion
    FROM variant_results vr
    JOIN experiments e ON vr.experiment_id = e.experiment_id
),

control_stats AS (
    SELECT *
    FROM variant_stats
    WHERE LOWER(variant_name) IN ('control', 'baseline', 'a')
),

treatment_stats AS (
    SELECT *
    FROM variant_stats
    WHERE LOWER(variant_name) NOT IN ('control', 'baseline', 'a')
)

SELECT
    t.experiment_id,
    t.experiment_name,
    -- Control metrics
    c.variant_name AS control_name,
    c.visitors AS control_visitors,
    c.conversions AS control_conversions,
    ROUND(c.conversion_rate * 100, 4) AS control_rate_pct,
    -- Treatment metrics
    t.variant_name AS treatment_name,
    t.visitors AS treatment_visitors,
    t.conversions AS treatment_conversions,
    ROUND(t.conversion_rate * 100, 4) AS treatment_rate_pct,
    -- Lift calculation
    ROUND((t.conversion_rate - c.conversion_rate) * 100, 4) AS absolute_lift_pct,
    ROUND(
        (t.conversion_rate - c.conversion_rate) / NULLIF(c.conversion_rate, 0) * 100,
        2
    ) AS relative_lift_pct,
    -- Pooled standard error (for z-test)
    ROUND(
        SQRT(
            c.se_proportion * c.se_proportion +
            t.se_proportion * t.se_proportion
        ), 6
    ) AS pooled_se,
    -- Z-score
    ROUND(
        (t.conversion_rate - c.conversion_rate) /
        NULLIF(
            SQRT(c.se_proportion * c.se_proportion + t.se_proportion * t.se_proportion),
            0
        ),
        4
    ) AS z_score
FROM treatment_stats t
JOIN control_stats c ON t.experiment_id = c.experiment_id
ORDER BY t.experiment_id;


-- =============================================================================
-- Statistical Significance Helper
-- =============================================================================
-- Provides data needed for significance calculation
-- (Actual p-value calculation typically done in Python/application layer)

WITH experiment_data AS (
    SELECT
        e.experiment_id,
        e.name,
        MAX(CASE WHEN LOWER(vr.variant_name) IN ('control', 'baseline', 'a')
            THEN vr.visitors END) AS control_n,
        MAX(CASE WHEN LOWER(vr.variant_name) IN ('control', 'baseline', 'a')
            THEN vr.conversions END) AS control_conversions,
        MAX(CASE WHEN LOWER(vr.variant_name) NOT IN ('control', 'baseline', 'a')
            THEN vr.visitors END) AS treatment_n,
        MAX(CASE WHEN LOWER(vr.variant_name) NOT IN ('control', 'baseline', 'a')
            THEN vr.conversions END) AS treatment_conversions
    FROM experiments e
    JOIN variant_results vr ON e.experiment_id = vr.experiment_id
    GROUP BY e.experiment_id, e.name
)

SELECT
    experiment_id,
    name,
    control_n,
    control_conversions,
    ROUND(control_conversions::NUMERIC / NULLIF(control_n, 0), 6) AS p_control,
    treatment_n,
    treatment_conversions,
    ROUND(treatment_conversions::NUMERIC / NULLIF(treatment_n, 0), 6) AS p_treatment,
    -- Pooled proportion (under null hypothesis)
    ROUND(
        (control_conversions + treatment_conversions)::NUMERIC /
        NULLIF(control_n + treatment_n, 0),
        6
    ) AS p_pooled,
    -- Standard error under null
    ROUND(
        SQRT(
            ((control_conversions + treatment_conversions)::NUMERIC / NULLIF(control_n + treatment_n, 0)) *
            (1 - (control_conversions + treatment_conversions)::NUMERIC / NULLIF(control_n + treatment_n, 0)) *
            (1.0 / NULLIF(control_n, 0) + 1.0 / NULLIF(treatment_n, 0))
        ),
        6
    ) AS se_null,
    -- Minimum detectable effect at current sample size (approximation)
    ROUND(
        1.96 * 2 * SQRT(
            ((control_conversions + treatment_conversions)::NUMERIC / NULLIF(control_n + treatment_n, 0)) *
            (1 - (control_conversions + treatment_conversions)::NUMERIC / NULLIF(control_n + treatment_n, 0)) *
            (1.0 / NULLIF(control_n, 0) + 1.0 / NULLIF(treatment_n, 0))
        ) * 100,
        2
    ) AS mde_at_95_confidence
FROM experiment_data;


-- =============================================================================
-- Experiment Timeline Analysis
-- =============================================================================
-- Track how metrics evolve during the experiment

WITH daily_results AS (
    -- This assumes we have a table tracking daily variant performance
    -- If not, this would come from event-level data
    SELECT
        vr.experiment_id,
        vr.variant_name,
        DATE_TRUNC('day', e.start_date + (gs.n || ' days')::INTERVAL)::DATE AS date,
        -- Simulated cumulative data (in practice, from event stream)
        vr.visitors * (gs.n + 1) /
            GREATEST((e.end_date - e.start_date), 1) AS cumulative_visitors,
        vr.conversions * (gs.n + 1) /
            GREATEST((e.end_date - e.start_date), 1) AS cumulative_conversions
    FROM variant_results vr
    JOIN experiments e ON vr.experiment_id = e.experiment_id
    CROSS JOIN generate_series(0, 30) AS gs(n)
    WHERE e.start_date + (gs.n || ' days')::INTERVAL <= COALESCE(e.end_date, CURRENT_DATE)
)

SELECT
    experiment_id,
    date,
    variant_name,
    ROUND(cumulative_visitors) AS visitors,
    ROUND(cumulative_conversions) AS conversions,
    ROUND(
        cumulative_conversions / NULLIF(cumulative_visitors, 0) * 100,
        2
    ) AS cumulative_rate
FROM daily_results
ORDER BY experiment_id, date, variant_name;


-- =============================================================================
-- Sample Size Calculator Data
-- =============================================================================
-- Provides baseline metrics for planning new experiments

WITH baseline_stats AS (
    SELECT
        COUNT(DISTINCT customer_id) AS total_customers,
        COUNT(*) AS total_events,
        -- Historical conversion rate (e.g., purchases / visitors)
        COUNT(CASE WHEN amount > 0 THEN 1 END)::NUMERIC / COUNT(*) AS baseline_conversion_rate,
        STDDEV(amount) AS revenue_stddev,
        AVG(amount) AS revenue_mean
    FROM transactions
    WHERE transaction_date >= CURRENT_DATE - INTERVAL '3 months'
)

SELECT
    total_customers,
    total_events,
    ROUND(baseline_conversion_rate * 100, 2) AS baseline_rate_pct,
    ROUND(revenue_mean, 2) AS avg_revenue,
    ROUND(revenue_stddev, 2) AS revenue_stddev,
    -- Sample size needed for different MDEs (assuming 80% power, 95% confidence)
    -- Formula approximation: n = 2 * ((1.96 + 0.84)^2) * p * (1-p) / (mde^2)
    ROUND(
        2 * POWER(1.96 + 0.84, 2) * baseline_conversion_rate * (1 - baseline_conversion_rate) /
        POWER(0.01, 2)
    ) AS sample_for_1pct_mde,
    ROUND(
        2 * POWER(1.96 + 0.84, 2) * baseline_conversion_rate * (1 - baseline_conversion_rate) /
        POWER(0.02, 2)
    ) AS sample_for_2pct_mde,
    ROUND(
        2 * POWER(1.96 + 0.84, 2) * baseline_conversion_rate * (1 - baseline_conversion_rate) /
        POWER(0.05, 2)
    ) AS sample_for_5pct_mde
FROM baseline_stats;


-- =============================================================================
-- Experiment Summary Report
-- =============================================================================

WITH experiment_summary AS (
    SELECT
        e.experiment_id,
        e.name,
        e.status,
        e.start_date,
        e.end_date,
        MAX(CASE WHEN LOWER(vr.variant_name) IN ('control', 'baseline', 'a')
            THEN vr.conversions::NUMERIC / NULLIF(vr.visitors, 0) END) AS control_rate,
        MAX(CASE WHEN LOWER(vr.variant_name) NOT IN ('control', 'baseline', 'a')
            THEN vr.conversions::NUMERIC / NULLIF(vr.visitors, 0) END) AS treatment_rate,
        SUM(vr.visitors) AS total_sample_size
    FROM experiments e
    JOIN variant_results vr ON e.experiment_id = vr.experiment_id
    GROUP BY e.experiment_id, e.name, e.status, e.start_date, e.end_date
)

SELECT
    experiment_id,
    name,
    status,
    start_date,
    COALESCE(end_date, CURRENT_DATE) AS end_date,
    COALESCE(end_date, CURRENT_DATE) - start_date AS days_running,
    total_sample_size,
    ROUND(control_rate * 100, 2) AS control_rate_pct,
    ROUND(treatment_rate * 100, 2) AS treatment_rate_pct,
    ROUND((treatment_rate - control_rate) * 100, 2) AS lift_pct,
    ROUND((treatment_rate - control_rate) / NULLIF(control_rate, 0) * 100, 1) AS relative_lift_pct,
    -- Simple decision logic
    CASE
        WHEN treatment_rate > control_rate * 1.05 AND total_sample_size >= 1000
            THEN 'SHIP - Significant positive lift'
        WHEN treatment_rate < control_rate * 0.95 AND total_sample_size >= 1000
            THEN 'HOLD - Significant negative lift'
        WHEN total_sample_size < 500
            THEN 'WAIT - Insufficient sample size'
        ELSE 'INCONCLUSIVE - Continue test'
    END AS recommendation
FROM experiment_summary
ORDER BY start_date DESC;
