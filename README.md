markdown# Olist E-Commerce Customer Churn & Revenue Leakage Analysis

## Problem Statement
Olist, a Brazilian e-commerce platform, faces significant revenue leakage due to 
customer churn. This project identifies at-risk customer segments, quantifies 
revenue impact, and provides actionable retention recommendations for marketing 
and operations teams.

## Key Finding
**58.1% of total revenue ($9.3M) is tied to churned or at-risk customers** 
across 99,441 orders and 93,470 unique customers.

## Tools & Technologies
- **SQL (SQLite)** — Data extraction, RFM scoring, churn flagging
- **Python (Pandas, Seaborn, Matplotlib)** — EDA, cohort analysis, visualization
- **Tableau Public** — Executive dashboard
- **Notion** — BRD, user stories, stakeholder memo

## Dataset
[Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)
- 99,441 orders
- 93,470 unique customers
- 9 relational tables

## Project Structure
olist-churn-analysis/
│
├── README.md
├── sql/
│   └── week1_olist_sql.sql
├── python/
│   └── rfm_analysis.ipynb
├── charts/
│   ├── chart1_revenue_by_segment.png
│   ├── chart2_churn_rate_by_segment.png
│   ├── chart3_revenue_at_risk.png
│   └── chart4_cohort_retention.png
└── docs/
├── BRD.md
├── user_stories.md
└── stakeholder_memo.md

## Key Insights
1. **At-Risk segment** — 22,024 customers, $5.3M revenue, 100% churn rate
2. **Champions** — 15,116 customers, $4.6M revenue, 0% churn — protect these
3. **São Paulo** drives 40%+ of total revenue — churn here has outsized impact
4. **Credit card** accounts for 75%+ of payment volume
5. **Beauty & health** is the top revenue category at $1.2M

## Dashboard
🔗 [View Live Tableau Dashboard](https://public.tableau.com/app/profile/anjali.tallapally3611/viz/OlistE-CommerceAnalytics_17803467526630/Dashboard1)

## Recommendations
| Priority | Action | Expected Impact |
|----------|--------|----------------|
| High | Win-back campaign for At-Risk segment | Recover 15-20% of $5.3M |
| High | Loyalty program for Champions | Protect $4.6M revenue |
| Medium | Investigate credit card payment friction in SP | Reduce churn in top state |
| Low | Monitor beauty & health review scores monthly | Early churn warning |

## Author
**Anjali Tallapally**
- LinkedIn: [linkedin.com/in/anjali-tallapally](https://linkedin.com/in/anjali-tallapally)
- Email: anjalitallapally2912@gmail.com
