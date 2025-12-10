# SQL Query Portfolio

This directory contains production-ready SQL queries demonstrating analytics proficiency against Echo's PostgreSQL data warehouse.

## Schema Overview

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   customers     │     │  transactions   │     │    products     │
├─────────────────┤     ├─────────────────┤     ├─────────────────┤
│ customer_id PK  │◄────│ customer_id FK  │     │ product_id PK   │
│ email           │     │ transaction_id  │────►│ product_name    │
│ name            │     │ product_id FK   │     │ category        │
│ segment         │     │ amount          │     │ price           │
│ created_at      │     │ quantity        │     │ is_active       │
│ updated_at      │     │ transaction_date│     └─────────────────┘
└─────────────────┘     │ channel         │
                        └─────────────────┘

┌─────────────────┐     ┌─────────────────┐
│ marketing_events│     │  experiments    │
├─────────────────┤     ├─────────────────┤
│ event_id PK     │     │ experiment_id PK│
│ customer_id FK  │     │ name            │
│ channel         │     │ hypothesis      │
│ campaign        │     │ status          │
│ stage           │     │ start_date      │
│ event_date      │     │ end_date        │
│ cost            │     └─────────────────┘
└─────────────────┘              │
                                 ▼
                        ┌─────────────────┐
                        │ variant_results │
                        ├─────────────────┤
                        │ result_id PK    │
                        │ experiment_id FK│
                        │ variant_name    │
                        │ visitors        │
                        │ conversions     │
                        │ revenue         │
                        └─────────────────┘
```

## Directory Structure

```
sql/
├── analytics/                    # Business analytics queries
│   ├── 01_revenue_analysis.sql   # Revenue trends, growth, MRR/ARR
│   ├── 02_cohort_retention.sql   # Customer retention by cohort
│   ├── 03_funnel_conversion.sql  # Marketing funnel analysis
│   ├── 04_customer_segmentation.sql  # RFM analysis
│   ├── 05_time_series_metrics.sql    # Moving averages, trends
│   └── 06_ab_test_analysis.sql   # Experiment statistics
│
├── profiling/                    # Data quality & profiling
│   ├── data_quality_check.sql    # NULL analysis, duplicates
│   └── column_statistics.sql     # Distributions, outliers
│
└── views/                        # Materialized views
    ├── vw_daily_metrics.sql      # Daily KPI snapshot
    └── vw_customer_360.sql       # Customer dimension view
```

## SQL Concepts Demonstrated

| Concept | Files | Description |
|---------|-------|-------------|
| **CTEs** | All analytics queries | Modular, readable query structure |
| **Window Functions** | 02, 04, 05 | ROW_NUMBER, RANK, LAG, LEAD, SUM OVER |
| **Date Math** | 01, 02, 05 | DATE_TRUNC, EXTRACT, intervals |
| **Aggregations** | All | SUM, COUNT, AVG with GROUP BY |
| **CASE Statements** | 03, 04 | Conditional logic in SELECT |
| **Self-Joins** | 02 | Comparing rows within same table |
| **Subqueries** | 04, 06 | Nested queries for complex logic |
| **Statistical Functions** | 06 | STDDEV, percentiles |

## Running Queries

### With psql
```bash
psql -d echo -f sql/analytics/01_revenue_analysis.sql
```

### With Docker
```bash
docker-compose exec db psql -U echo -d echo -f /sql/analytics/01_revenue_analysis.sql
```

### In Python
```python
import pandas as pd
from sqlalchemy import create_engine

engine = create_engine("postgresql://echo:echo@localhost:5432/echo")
df = pd.read_sql_file("sql/analytics/01_revenue_analysis.sql", engine)
```

## Sample Output

### Revenue Analysis (Query 01)
```
    month     │  revenue   │ customers │ mom_growth │ cumulative
──────────────┼────────────┼───────────┼────────────┼────────────
 2024-01-01   │  45,230.00 │       127 │      NULL  │   45,230.00
 2024-02-01   │  52,180.00 │       143 │     15.4%  │   97,410.00
 2024-03-01   │  48,920.00 │       138 │     -6.2%  │  146,330.00
```

### Cohort Retention (Query 02)
```
 cohort_month │ month_0 │ month_1 │ month_2 │ month_3
──────────────┼─────────┼─────────┼─────────┼─────────
 2024-01      │  100.0% │   72.3% │   58.1% │   51.2%
 2024-02      │  100.0% │   68.9% │   55.4% │   48.7%
 2024-03      │  100.0% │   71.1% │   57.2% │    NULL
```
