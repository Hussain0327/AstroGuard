-- =============================================================================
-- Funnel Conversion Analysis
-- =============================================================================
-- Demonstrates: CASE statements, conditional aggregation, conversion rates,
--               funnel visualization data, channel attribution
--
-- Purpose: Analyze marketing funnel performance and conversion rates
-- =============================================================================

-- Marketing Funnel Overview
WITH funnel_stages AS (
    SELECT
        DATE_TRUNC('month', event_date)::DATE AS month,
        channel,
        campaign,
        -- Count each funnel stage
        COUNT(CASE WHEN stage = 'impression' THEN 1 END) AS impressions,
        COUNT(CASE WHEN stage = 'click' THEN 1 END) AS clicks,
        COUNT(CASE WHEN stage = 'lead' THEN 1 END) AS leads,
        COUNT(CASE WHEN stage = 'qualified' THEN 1 END) AS qualified_leads,
        COUNT(CASE WHEN stage = 'opportunity' THEN 1 END) AS opportunities,
        COUNT(CASE WHEN stage = 'customer' THEN 1 END) AS customers,
        -- Sum costs for ROI calculation
        SUM(COALESCE(cost, 0)) AS total_cost
    FROM marketing_events
    WHERE event_date >= CURRENT_DATE - INTERVAL '6 months'
    GROUP BY DATE_TRUNC('month', event_date), channel, campaign
)

SELECT
    month,
    channel,
    campaign,
    impressions,
    clicks,
    leads,
    qualified_leads,
    opportunities,
    customers,
    total_cost,
    -- Conversion rates between stages
    ROUND(clicks::NUMERIC / NULLIF(impressions, 0) * 100, 2) AS click_through_rate,
    ROUND(leads::NUMERIC / NULLIF(clicks, 0) * 100, 2) AS click_to_lead_rate,
    ROUND(qualified_leads::NUMERIC / NULLIF(leads, 0) * 100, 2) AS lead_qualification_rate,
    ROUND(opportunities::NUMERIC / NULLIF(qualified_leads, 0) * 100, 2) AS qualified_to_opp_rate,
    ROUND(customers::NUMERIC / NULLIF(opportunities, 0) * 100, 2) AS opp_to_customer_rate,
    -- Overall funnel conversion
    ROUND(customers::NUMERIC / NULLIF(leads, 0) * 100, 2) AS lead_to_customer_rate,
    -- Cost metrics
    ROUND(total_cost / NULLIF(customers, 0), 2) AS cost_per_acquisition,
    ROUND(total_cost / NULLIF(leads, 0), 2) AS cost_per_lead
FROM funnel_stages
ORDER BY month DESC, customers DESC;


-- =============================================================================
-- Channel Performance Comparison
-- =============================================================================

WITH channel_metrics AS (
    SELECT
        channel,
        COUNT(CASE WHEN stage = 'lead' THEN 1 END) AS total_leads,
        COUNT(CASE WHEN stage = 'customer' THEN 1 END) AS total_customers,
        SUM(COALESCE(cost, 0)) AS total_spend,
        COUNT(DISTINCT campaign) AS num_campaigns
    FROM marketing_events
    WHERE event_date >= CURRENT_DATE - INTERVAL '3 months'
    GROUP BY channel
),

channel_revenue AS (
    SELECT
        m.channel,
        SUM(t.amount) AS attributed_revenue
    FROM marketing_events m
    JOIN transactions t ON m.customer_id = t.customer_id
        AND t.transaction_date >= m.event_date
        AND t.transaction_date <= m.event_date + INTERVAL '30 days'
    WHERE m.stage = 'customer'
      AND m.event_date >= CURRENT_DATE - INTERVAL '3 months'
    GROUP BY m.channel
)

SELECT
    cm.channel,
    cm.total_leads,
    cm.total_customers,
    ROUND(cm.total_customers::NUMERIC / NULLIF(cm.total_leads, 0) * 100, 2) AS conversion_rate,
    cm.total_spend,
    ROUND(cm.total_spend / NULLIF(cm.total_customers, 0), 2) AS cac,
    COALESCE(cr.attributed_revenue, 0) AS attributed_revenue,
    ROUND(COALESCE(cr.attributed_revenue, 0) / NULLIF(cm.total_spend, 0), 2) AS roas,
    cm.num_campaigns,
    -- Rank channels by efficiency
    RANK() OVER (ORDER BY cm.total_customers::NUMERIC / NULLIF(cm.total_leads, 0) DESC) AS conversion_rank,
    RANK() OVER (ORDER BY COALESCE(cr.attributed_revenue, 0) / NULLIF(cm.total_spend, 0) DESC) AS roas_rank
FROM channel_metrics cm
LEFT JOIN channel_revenue cr ON cm.channel = cr.channel
ORDER BY attributed_revenue DESC;


-- =============================================================================
-- Funnel Drop-off Analysis
-- =============================================================================
-- Identify where prospects are dropping off in the funnel

WITH funnel_counts AS (
    SELECT
        channel,
        COUNT(CASE WHEN stage = 'lead' THEN 1 END) AS stage_1_leads,
        COUNT(CASE WHEN stage = 'qualified' THEN 1 END) AS stage_2_qualified,
        COUNT(CASE WHEN stage = 'opportunity' THEN 1 END) AS stage_3_opportunity,
        COUNT(CASE WHEN stage = 'customer' THEN 1 END) AS stage_4_customer
    FROM marketing_events
    WHERE event_date >= CURRENT_DATE - INTERVAL '3 months'
    GROUP BY channel
)

SELECT
    channel,
    stage_1_leads,
    stage_2_qualified,
    stage_3_opportunity,
    stage_4_customer,
    -- Drop-off at each stage
    stage_1_leads - stage_2_qualified AS dropoff_1_to_2,
    stage_2_qualified - stage_3_opportunity AS dropoff_2_to_3,
    stage_3_opportunity - stage_4_customer AS dropoff_3_to_4,
    -- Drop-off percentages
    ROUND((stage_1_leads - stage_2_qualified)::NUMERIC / NULLIF(stage_1_leads, 0) * 100, 1) AS pct_lost_at_qualification,
    ROUND((stage_2_qualified - stage_3_opportunity)::NUMERIC / NULLIF(stage_2_qualified, 0) * 100, 1) AS pct_lost_at_opportunity,
    ROUND((stage_3_opportunity - stage_4_customer)::NUMERIC / NULLIF(stage_3_opportunity, 0) * 100, 1) AS pct_lost_at_close,
    -- Identify biggest drop-off stage
    CASE
        WHEN (stage_1_leads - stage_2_qualified)::NUMERIC / NULLIF(stage_1_leads, 0) >=
             GREATEST(
                 (stage_2_qualified - stage_3_opportunity)::NUMERIC / NULLIF(stage_2_qualified, 0),
                 (stage_3_opportunity - stage_4_customer)::NUMERIC / NULLIF(stage_3_opportunity, 0)
             ) THEN 'Lead Qualification'
        WHEN (stage_2_qualified - stage_3_opportunity)::NUMERIC / NULLIF(stage_2_qualified, 0) >=
             (stage_3_opportunity - stage_4_customer)::NUMERIC / NULLIF(stage_3_opportunity, 0)
             THEN 'Opportunity Creation'
        ELSE 'Deal Closing'
    END AS biggest_dropoff_stage
FROM funnel_counts
WHERE stage_1_leads > 0
ORDER BY stage_1_leads DESC;


-- =============================================================================
-- Time-to-Convert Analysis
-- =============================================================================
-- How long does it take leads to become customers?

WITH lead_events AS (
    SELECT
        customer_id,
        channel,
        MIN(CASE WHEN stage = 'lead' THEN event_date END) AS lead_date,
        MIN(CASE WHEN stage = 'customer' THEN event_date END) AS customer_date
    FROM marketing_events
    WHERE event_date >= CURRENT_DATE - INTERVAL '6 months'
    GROUP BY customer_id, channel
),

conversion_times AS (
    SELECT
        channel,
        customer_id,
        lead_date,
        customer_date,
        customer_date - lead_date AS days_to_convert
    FROM lead_events
    WHERE customer_date IS NOT NULL
      AND lead_date IS NOT NULL
)

SELECT
    channel,
    COUNT(*) AS total_conversions,
    ROUND(AVG(days_to_convert), 1) AS avg_days_to_convert,
    MIN(days_to_convert) AS min_days,
    MAX(days_to_convert) AS max_days,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY days_to_convert) AS median_days,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY days_to_convert) AS p75_days,
    -- Conversion speed buckets
    COUNT(CASE WHEN days_to_convert <= 7 THEN 1 END) AS converted_within_1_week,
    COUNT(CASE WHEN days_to_convert <= 30 THEN 1 END) AS converted_within_1_month,
    COUNT(CASE WHEN days_to_convert > 30 THEN 1 END) AS converted_after_1_month
FROM conversion_times
GROUP BY channel
ORDER BY avg_days_to_convert;


-- =============================================================================
-- Campaign Performance Ranking
-- =============================================================================

WITH campaign_stats AS (
    SELECT
        campaign,
        channel,
        MIN(event_date) AS start_date,
        MAX(event_date) AS end_date,
        COUNT(CASE WHEN stage = 'lead' THEN 1 END) AS leads,
        COUNT(CASE WHEN stage = 'customer' THEN 1 END) AS customers,
        SUM(COALESCE(cost, 0)) AS spend
    FROM marketing_events
    WHERE event_date >= CURRENT_DATE - INTERVAL '6 months'
    GROUP BY campaign, channel
)

SELECT
    campaign,
    channel,
    start_date,
    end_date,
    end_date - start_date AS campaign_duration_days,
    leads,
    customers,
    ROUND(customers::NUMERIC / NULLIF(leads, 0) * 100, 2) AS conversion_rate,
    spend,
    ROUND(spend / NULLIF(customers, 0), 2) AS cac,
    -- Rank campaigns
    ROW_NUMBER() OVER (ORDER BY customers DESC) AS rank_by_volume,
    ROW_NUMBER() OVER (ORDER BY customers::NUMERIC / NULLIF(leads, 0) DESC) AS rank_by_conversion,
    ROW_NUMBER() OVER (ORDER BY spend / NULLIF(customers, 0)) AS rank_by_efficiency
FROM campaign_stats
WHERE leads >= 10  -- Filter out small campaigns
ORDER BY customers DESC
LIMIT 20;
