-- ============================================================
-- PROJECT: Customer Churn & Revenue Leakage Analyzer
-- Dataset: Brazilian E-commerce (Olist) - Kaggle
-- Week 1: Data Extraction, Cleaning, RFM Scoring, Churn Flagging
-- ============================================================

-- ============================================================
-- STEP 1: UNDERSTAND THE SCHEMA
-- Core tables you'll work with:
--   olist_orders_dataset             → orders, status, timestamps
--   olist_customers_dataset          → customer_id, zip, city, state
--   olist_order_items_dataset        → order_id, product_id, price, freight
--   olist_order_payments_dataset     → order_id, payment_type, payment_value
--   olist_products_dataset           → product_id, category
--   olist_order_reviews_dataset      → order_id, review_score
-- ============================================================


-- ============================================================
-- STEP 2: BASE TABLE — Delivered Orders Only
-- Why: Cancelled/unavailable orders skew revenue and recency metrics
-- ============================================================

CREATE VIEW vw_delivered_orders AS
SELECT
    o.order_id,
    o.customer_id,
    o.order_status,
    DATE(o.order_purchase_timestamp)        AS order_date,
    DATE(o.order_delivered_customer_date)   AS delivery_date,
    SUM(p.payment_value)                    AS order_revenue
FROM olist_orders_dataset o
JOIN olist_order_payments_dataset p
    ON o.order_id = p.order_id
WHERE o.order_status = 'delivered'
GROUP BY
    o.order_id,
    o.customer_id,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date;


-- ============================================================
-- STEP 3: CUSTOMER ORDER HISTORY
-- Aggregates all delivered orders per customer
-- ============================================================

CREATE VIEW vw_customer_order_history AS
SELECT
    c.customer_unique_id,                           -- use unique_id, not customer_id (Olist quirk)
    c.customer_city,
    c.customer_state,
    COUNT(DISTINCT d.order_id)                      AS total_orders,
    SUM(d.order_revenue)                            AS total_revenue,
    ROUND(AVG(d.order_revenue), 2)                  AS avg_order_value,
    MIN(d.order_date)                               AS first_order_date,
    MAX(d.order_date)                               AS last_order_date,
    -- Days since last purchase (recency)
    DATEDIFF(
        (SELECT MAX(order_date) FROM vw_delivered_orders),  -- snapshot date = max date in dataset
        MAX(d.order_date)
    )                                               AS recency_days
FROM vw_delivered_orders d
JOIN olist_customers_dataset c
    ON d.customer_id = c.customer_id
GROUP BY
    c.customer_unique_id,
    c.customer_city,
    c.customer_state;


-- ============================================================
-- STEP 4: RFM SCORING
-- Recency:  lower days = better (score 5 = most recent)
-- Frequency: higher orders = better
-- Monetary:  higher revenue = better
-- Using NTILE(5) to assign scores 1-5 per dimension
-- ============================================================

CREATE VIEW vw_rfm_scores AS
SELECT
    customer_unique_id,
    customer_city,
    customer_state,
    total_orders,
    total_revenue,
    avg_order_value,
    first_order_date,
    last_order_date,
    recency_days,

    -- Recency Score: NTILE reversed (least days = score 5)
    6 - NTILE(5) OVER (ORDER BY recency_days ASC)       AS recency_score,

    -- Frequency Score
    NTILE(5) OVER (ORDER BY total_orders ASC)           AS frequency_score,

    -- Monetary Score
    NTILE(5) OVER (ORDER BY total_revenue ASC)          AS monetary_score

FROM vw_customer_order_history;


-- ============================================================
-- STEP 5: RFM SEGMENTS
-- Combined RFM score = R + F + M (max 15, min 3)
-- Segments map to business-meaningful labels
-- ============================================================

CREATE VIEW vw_rfm_segments AS
SELECT
    *,
    (recency_score + frequency_score + monetary_score)  AS rfm_total_score,

    CASE
        WHEN recency_score >= 4 AND frequency_score >= 4 AND monetary_score >= 4
            THEN 'Champion'
        WHEN recency_score >= 3 AND frequency_score >= 3
            THEN 'Loyal'
        WHEN recency_score >= 4 AND frequency_score <= 2
            THEN 'New Customer'
        WHEN recency_score = 3 AND frequency_score <= 3
            THEN 'Potential Loyalist'
        WHEN recency_score <= 2 AND frequency_score >= 3
            THEN 'At Risk'
        WHEN recency_score <= 2 AND frequency_score <= 2 AND monetary_score >= 3
            THEN 'Cant Lose Them'
        WHEN recency_score = 1
            THEN 'Lost'
        ELSE 'Needs Attention'
    END AS customer_segment

FROM vw_rfm_scores;


-- ============================================================
-- STEP 6: CHURN FLAG
-- Definition: No purchase in last 180 days = churned
-- Adjust threshold based on dataset's date range
-- ============================================================

CREATE VIEW vw_churn_flags AS
SELECT
    *,
    CASE
        WHEN recency_days > 180 THEN 1
        ELSE 0
    END AS is_churned,

    CASE
        WHEN recency_days BETWEEN 91 AND 180 THEN 1
        ELSE 0
    END AS is_at_risk

FROM vw_rfm_segments;


-- ============================================================
-- STEP 7: REVENUE LEAKAGE SUMMARY
-- Quantifies $ tied up in churned and at-risk customers
-- This is your headline business metric
-- ============================================================

SELECT
    customer_segment,
    COUNT(customer_unique_id)               AS customer_count,
    ROUND(SUM(total_revenue), 2)            AS total_revenue,
    ROUND(AVG(total_revenue), 2)            AS avg_revenue_per_customer,
    ROUND(AVG(recency_days), 0)             AS avg_recency_days,
    SUM(is_churned)                         AS churned_count,
    SUM(is_at_risk)                         AS at_risk_count,

    -- Revenue at risk = revenue from churned + at-risk customers
    ROUND(SUM(CASE WHEN is_churned = 1 OR is_at_risk = 1 THEN total_revenue ELSE 0 END), 2)
                                            AS revenue_at_risk

FROM vw_churn_flags
GROUP BY customer_segment
ORDER BY total_revenue DESC;


-- ============================================================
-- STEP 8: TOP PRODUCT CATEGORIES DRIVING CHURN
-- Helps answer: "What did churned customers buy last?"
-- ============================================================

SELECT
    p.product_category_name                 AS category,
    COUNT(DISTINCT cf.customer_unique_id)   AS churned_customers,
    ROUND(SUM(i.price), 2)                  AS revenue_from_churned,
    ROUND(AVG(r.review_score), 2)           AS avg_review_score

FROM vw_churn_flags cf
JOIN olist_customers_dataset c
    ON cf.customer_unique_id = c.customer_unique_id
JOIN olist_orders_dataset o
    ON c.customer_id = o.customer_id
JOIN olist_order_items_dataset i
    ON o.order_id = i.order_id
JOIN olist_products_dataset p
    ON i.product_id = p.product_id
LEFT JOIN olist_order_reviews_dataset r
    ON o.order_id = r.order_id
WHERE cf.is_churned = 1
GROUP BY p.product_category_name
ORDER BY churned_customers DESC
LIMIT 20;


-- ============================================================
-- STEP 9: STATE-LEVEL CHURN HEATMAP DATA
-- For Tableau geographic visualization
-- ============================================================

SELECT
    customer_state,
    COUNT(customer_unique_id)               AS total_customers,
    SUM(is_churned)                         AS churned_customers,
    ROUND(100.0 * SUM(is_churned) / COUNT(customer_unique_id), 2)
                                            AS churn_rate_pct,
    ROUND(SUM(total_revenue), 2)            AS total_revenue,
    ROUND(SUM(CASE WHEN is_churned = 1 THEN total_revenue ELSE 0 END), 2)
                                            AS churned_revenue

FROM vw_churn_flags
GROUP BY customer_state
ORDER BY churn_rate_pct DESC;


-- ============================================================
-- STEP 10: MONTHLY CHURN TREND
-- For Tableau time-series visualization
-- ============================================================

SELECT
    DATE_FORMAT(last_order_date, '%Y-%m')   AS cohort_month,
    COUNT(customer_unique_id)               AS total_customers,
    SUM(is_churned)                         AS churned_customers,
    ROUND(100.0 * SUM(is_churned) / COUNT(customer_unique_id), 2)
                                            AS churn_rate_pct,
    ROUND(SUM(total_revenue), 2)            AS total_revenue

FROM vw_churn_flags
GROUP BY DATE_FORMAT(last_order_date, '%Y-%m')
ORDER BY cohort_month ASC;
