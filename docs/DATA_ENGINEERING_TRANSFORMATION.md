# Echo Data Engineering Transformation Plan

---

## Progress Log

### Session: December 10, 2024

#### What We Accomplished

**1. Prefect Orchestration Layer - COMPLETE**
- Created `orchestration/` directory with tasks and flows
- Built 4 task modules:
  - `extract.py` - CSV, Excel, directory, database extraction with retries
  - `validate.py` - Great Expectations integration for data validation
  - `transform.py` - dbt runner and metrics calculation
  - `load.py` - Staging tables, warehouse, parquet, upsert operations
- Built 3 flow pipelines:
  - `daily_metrics.py` - Main ETL pipeline for revenue + marketing data
  - `data_ingestion.py` - Generic ETL for any data type
  - `experiment_analysis.py` - A/B test analysis pipeline
- Created deployment configuration for scheduled runs

**2. Great Expectations Data Quality - COMPLETE**
- Created `data_quality/` directory structure
- Built 3 expectation suites (JSON):
  - `revenue_data_suite.json` - 9 expectations for revenue data
  - `marketing_data_suite.json` - 9 expectations for marketing data
  - `experiment_data_suite.json` - 8 expectations for A/B test data
- Created Python wrapper (`validator.py`) for easy integration
- Integrated with Prefect tasks

**3. dbt Transformation Layer - COMPLETE (structure only)**
- Created full `dbt/` project structure
- Built staging models:
  - `stg_transactions.sql`
  - `stg_marketing_events.sql`
  - `stg_customers.sql`
  - `stg_experiment_assignments.sql`
- Built intermediate models:
  - `int_customer_transactions.sql`
- Built mart models:
  - `mrr_monthly.sql` (incremental)
  - `revenue_summary.sql`
  - `channel_performance.sql`
  - `funnel_conversion.sql`
  - `experiment_results.sql`
- Created macros: `calculate_conversion_rate.sql`, `calculate_growth_rate.sql`
- Added schema tests via `schema.yml`
- Installed dbt packages (dbt_utils)

**4. Infrastructure Updates - COMPLETE**
- Updated `requirements.txt` with new dependencies:
  - prefect, great-expectations, dbt-core, dbt-postgres, psycopg
- Updated `docker-compose.yml`:
  - Added Prefect server container (port 4200)
  - Added Prefect worker container
  - Added environment variables for dbt
- Created `Makefile` with common commands
- Updated `.gitignore` for new directories
- Created `.env` file with required variables

**5. Verified Pipeline Execution - COMPLETE**
- Successfully ran `daily_metrics_pipeline`:
  - Extracted 101 rows from revenue data, 93 from marketing data
  - Passed all 8 data quality expectations
  - Calculated 5 metrics (total_revenue, revenue_growth, AOV, conversion_rate, channel_performance)
- Sample results:
  - Total Revenue: $190,100.50
  - Average Order Value: $2,066.31
  - Overall Conversion Rate: 10.21%
  - Best Channel: LinkedIn (17.4% conversion rate)

#### Where We Left Off

**Blocker: Docker not installed**
- User needs to install Docker Desktop for macOS
- Download from: https://www.docker.com/products/docker-desktop/
- Required for:
  - PostgreSQL database (to run dbt models against real data)
  - Redis (for caching)
  - Prefect server (for UI and scheduling)

#### What Still Needs Docker

1. **dbt models can't run yet** - They need a PostgreSQL database to execute against
2. **Prefect UI unavailable** - Can run flows locally but no web UI for monitoring
3. **Data loading to warehouse** - The `load_to_staging` and `load_to_warehouse` tasks need a database
4. **Full pipeline execution** - Currently skipping the database load step

#### Immediate Next Steps (Once Docker is installed)

```bash
# 1. Start all services
docker compose up -d

# 2. Verify services are running
docker compose ps

# 3. Run database migrations
alembic upgrade head

# 4. Load sample data to staging
python -c "
from orchestration.flows.data_ingestion import data_ingestion_pipeline
data_ingestion_pipeline('data/samples/revenue_sample.csv', 'revenue')
"

# 5. Run dbt models
cd dbt && dbt run

# 6. Start Prefect UI
# Visit http://localhost:4200
```

---

## Remaining Work (Priority Order)

### P0 - Foundation (Blocked on Docker)
| Task | Status | Notes |
|------|--------|-------|
| Prefect orchestration | DONE | Works locally, needs Docker for UI |
| Great Expectations | DONE | Validation working |
| dbt project structure | DONE | Models written, needs DB to run |
| Docker services | BLOCKED | User needs to install Docker |
| Load data to PostgreSQL | PENDING | Needs Docker |
| Run dbt models | PENDING | Needs Docker |

### P1 - Depth (After Docker)
| Task | Status | Notes |
|------|--------|-------|
| Dimensional model (star schema) | NOT STARTED | Design exists in docs |
| SCD Type 2 for customers | NOT STARTED | SQL written, needs implementation |
| Bayesian A/B testing | NOT STARTED | Code examples in docs |
| Sequential testing | NOT STARTED | Code examples in docs |

### P2 - Differentiators (Future)
| Task | Status | Notes |
|------|--------|-------|
| Feature store (Feast) | NOT STARTED | |
| MLflow integration | NOT STARTED | |
| Churn prediction model | NOT STARTED | |

### P3 - Advanced (Optional)
| Task | Status | Notes |
|------|--------|-------|
| Kafka streaming | NOT STARTED | |

---

## Executive Summary

This document outlines the transformation of Echo from a **software engineering project** (FastAPI + React app that processes CSVs) to a **data engineering portfolio project** that demonstrates production-grade data platform skills.

### Current State vs Target State

| Aspect | Current State | Target State |
|--------|--------------|--------------|
| Data Flow | Upload CSV → Process → Display | Raw → Staging → Transform → Mart → Analytics |
| Orchestration | None (ad-hoc processing) | Prefect DAGs with scheduling, retries, observability |
| Data Quality | Reactive (`DataAutoFixer`) | Proactive (Great Expectations validation suites) |
| Transformations | Python functions | dbt models with lineage, tests, documentation |
| Data Model | Flat/OLTP tables | Star schema with facts, dimensions, SCDs |
| ML Ops | None | MLflow for experiment tracking, model registry |
| Feature Engineering | Computed on-the-fly | Feature store (Feast) with offline/online serving |
| Statistics | Basic z-test | Bayesian, sequential testing, power analysis |
| Streaming | None | Kafka for real-time event processing |

---

## Architecture Vision

```
                                    ┌─────────────────────────────────────────────────────────────┐
                                    │                    ECHO DATA PLATFORM                        │
                                    └─────────────────────────────────────────────────────────────┘

┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   SOURCES    │     │   INGEST     │     │  TRANSFORM   │     │    SERVE     │     │   CONSUME    │
│              │     │              │     │              │     │              │     │              │
│ • CSV/Excel  │────▶│ • Prefect    │────▶│ • dbt        │────▶│ • Feature    │────▶│ • FastAPI    │
│ • APIs       │     │ • GX Valid.  │     │ • Star       │     │   Store      │     │ • Dashboards │
│ • Databases  │     │ • Staging    │     │   Schema     │     │ • ML Models  │     │ • Reports    │
│ • Kafka      │     │   Tables     │     │ • SCDs       │     │ • Metrics    │     │ • Chat       │
└──────────────┘     └──────────────┘     └──────────────┘     └──────────────┘     └──────────────┘
                            │                    │                    │
                            ▼                    ▼                    ▼
                     ┌──────────────────────────────────────────────────────┐
                     │                   OBSERVABILITY                       │
                     │  • Prefect UI  • dbt Docs  • GX Data Docs  • MLflow  │
                     └──────────────────────────────────────────────────────┘
```

---

## Implementation Phases

### Phase 1: ETL Pipeline Foundation (Days 1-3)
**Goal:** Replace ad-hoc CSV processing with orchestrated pipelines

#### 1.1 Prefect Setup
- Install Prefect 2.x
- Create base DAG structure
- Implement retry logic, logging, and failure notifications

#### 1.2 Core Pipelines to Build
```
daily_data_pipeline.py
├── extract_csv_sources()      # Pull from configured sources
├── validate_schema()          # Great Expectations checkpoint
├── load_to_staging()          # Raw → staging tables
├── run_dbt_transforms()       # Staging → marts
└── update_feature_store()     # Refresh features

experiment_pipeline.py
├── extract_experiment_data()
├── validate_experiment_data()
├── calculate_statistics()
├── generate_decision()
└── store_results()
```

#### 1.3 Why Prefect over Airflow?
- Lighter weight, faster setup
- Better local development experience
- Modern Python-native API
- Free tier for UI/scheduling
- More impressive for portfolio (shows you know modern tools)

---

### Phase 2: Data Quality Framework (Days 4-5)
**Goal:** Move from reactive cleaning to proactive validation

#### 2.1 Great Expectations Implementation
```python
# Current approach (reactive):
fix_result = auto_fix_dataframe(df)  # Clean after the fact

# New approach (proactive):
validation_result = gx_context.run_checkpoint(
    checkpoint_name="revenue_data_checkpoint",
    batch_request=batch_request
)
if not validation_result.success:
    raise DataQualityError(validation_result.to_json())
```

#### 2.2 Expectation Suites to Create
| Suite Name | Purpose | Key Expectations |
|------------|---------|------------------|
| `raw_revenue_data` | Validate revenue uploads | Non-null amount, positive values, valid dates |
| `raw_marketing_data` | Validate marketing uploads | Valid channels, numeric leads/conversions |
| `raw_experiment_data` | Validate A/B test data | Binary variant assignment, valid user IDs |
| `staging_customers` | Post-staging validation | Unique customer_id, valid email format |
| `mart_metrics` | Final metrics validation | Reasonable ranges, consistency checks |

#### 2.3 Data Contracts
Define explicit contracts for each data source:
```yaml
# contracts/revenue_data_contract.yaml
name: revenue_data
version: 1.0
owner: analytics_team
schema:
  - name: transaction_id
    type: string
    required: true
    unique: true
  - name: amount
    type: float
    required: true
    constraints:
      - min: 0
      - max: 1000000
  - name: date
    type: date
    required: true
```

---

### Phase 3: dbt Transformation Layer (Days 6-9)
**Goal:** Move business logic from Python to SQL with lineage and testing

#### 3.1 dbt Project Structure
```
dbt/
├── dbt_project.yml
├── profiles.yml
├── models/
│   ├── staging/                    # 1:1 with sources, light cleaning
│   │   ├── stg_transactions.sql
│   │   ├── stg_customers.sql
│   │   ├── stg_marketing_events.sql
│   │   └── stg_experiments.sql
│   ├── intermediate/               # Business logic, joins
│   │   ├── int_customer_orders.sql
│   │   ├── int_marketing_attribution.sql
│   │   └── int_experiment_assignments.sql
│   └── marts/                      # Final analytics tables
│       ├── finance/
│       │   ├── mrr_monthly.sql
│       │   ├── arr_quarterly.sql
│       │   └── revenue_by_product.sql
│       ├── marketing/
│       │   ├── channel_performance.sql
│       │   ├── funnel_conversion.sql
│       │   └── campaign_roi.sql
│       └── experiments/
│           ├── experiment_results.sql
│           └── variant_performance.sql
├── tests/
│   ├── assert_mrr_positive.sql
│   └── assert_no_duplicate_customers.sql
├── macros/
│   ├── calculate_conversion_rate.sql
│   └── date_spine.sql
└── seeds/
    └── dim_date.csv
```

#### 3.2 Key dbt Models

**MRR Calculation (currently in Python, move to dbt):**
```sql
-- models/marts/finance/mrr_monthly.sql
{{ config(materialized='incremental', unique_key='month') }}

WITH active_subscriptions AS (
    SELECT
        customer_id,
        subscription_amount,
        billing_period,
        DATE_TRUNC('month', effective_date) AS month,
        -- Normalize to monthly
        CASE billing_period
            WHEN 'annual' THEN subscription_amount / 12
            WHEN 'quarterly' THEN subscription_amount / 3
            ELSE subscription_amount
        END AS monthly_amount
    FROM {{ ref('stg_subscriptions') }}
    WHERE status IN ('active', 'paid')
)

SELECT
    month,
    SUM(monthly_amount) AS mrr,
    COUNT(DISTINCT customer_id) AS active_subscribers,
    AVG(monthly_amount) AS arpu
FROM active_subscriptions
{% if is_incremental() %}
WHERE month > (SELECT MAX(month) FROM {{ this }})
{% endif %}
GROUP BY 1
```

**Conversion Funnel (currently Python, move to dbt):**
```sql
-- models/marts/marketing/funnel_conversion.sql
{{ config(materialized='table') }}

WITH funnel_stages AS (
    SELECT
        source,
        campaign,
        DATE_TRUNC('month', event_date) AS month,
        COUNT(CASE WHEN stage = 'lead' THEN 1 END) AS leads,
        COUNT(CASE WHEN stage = 'qualified' THEN 1 END) AS qualified,
        COUNT(CASE WHEN stage = 'opportunity' THEN 1 END) AS opportunities,
        COUNT(CASE WHEN stage = 'customer' THEN 1 END) AS customers
    FROM {{ ref('stg_marketing_events') }}
    GROUP BY 1, 2, 3
)

SELECT
    *,
    {{ calculate_conversion_rate('qualified', 'leads') }} AS lead_to_qualified_rate,
    {{ calculate_conversion_rate('opportunities', 'qualified') }} AS qualified_to_opp_rate,
    {{ calculate_conversion_rate('customers', 'opportunities') }} AS opp_to_customer_rate,
    {{ calculate_conversion_rate('customers', 'leads') }} AS overall_conversion_rate
FROM funnel_stages
```

#### 3.3 Why This Matters for DE Roles
- dbt is THE tool for analytics engineering (most in-demand skill)
- Shows you understand ELT vs ETL
- Demonstrates SQL proficiency at scale
- Built-in testing, documentation, lineage = production-ready

---

### Phase 4: Dimensional Data Warehouse (Days 10-12)
**Goal:** Demonstrate warehouse design skills with star schema and SCDs

#### 4.1 Dimensional Model Design

```
                          ┌─────────────────┐
                          │   dim_date      │
                          │─────────────────│
                          │ date_key (PK)   │
                          │ full_date       │
                          │ day_of_week     │
                          │ month           │
                          │ quarter         │
                          │ year            │
                          │ is_weekend      │
                          │ is_holiday      │
                          └────────┬────────┘
                                   │
┌─────────────────┐    ┌──────────┴────────────┐    ┌─────────────────┐
│  dim_customer   │    │   fact_transactions   │    │  dim_product    │
│─────────────────│    │───────────────────────│    │─────────────────│
│ customer_key    │◄───│ customer_key (FK)     │───►│ product_key     │
│ customer_id     │    │ product_key (FK)      │    │ product_id      │
│ email           │    │ date_key (FK)         │    │ product_name    │
│ name            │    │ transaction_id        │    │ category        │
│ segment         │    │ amount                │    │ price_tier      │
│ created_at      │    │ quantity              │    │ is_active       │
│ -- SCD Type 2 --│    │ discount              │    └─────────────────┘
│ valid_from      │    │ channel_key (FK)      │
│ valid_to        │    └───────────────────────┘
│ is_current      │
└─────────────────┘
                       ┌───────────────────────┐
                       │   fact_experiments    │
                       │───────────────────────│
                       │ experiment_key (FK)   │
                       │ customer_key (FK)     │
                       │ date_key (FK)         │
                       │ variant_name          │
                       │ converted             │
                       │ revenue               │
                       └───────────────────────┘
```

#### 4.2 SCD Type 2 Implementation
```sql
-- models/intermediate/int_customer_scd2.sql
-- Slowly Changing Dimension Type 2 for customer attributes

WITH customer_changes AS (
    SELECT
        customer_id,
        email,
        segment,
        plan_type,
        updated_at,
        LAG(segment) OVER (PARTITION BY customer_id ORDER BY updated_at) AS prev_segment,
        LAG(plan_type) OVER (PARTITION BY customer_id ORDER BY updated_at) AS prev_plan
    FROM {{ ref('stg_customers') }}
),

detected_changes AS (
    SELECT *,
        CASE
            WHEN prev_segment IS NULL THEN TRUE
            WHEN segment != prev_segment THEN TRUE
            WHEN plan_type != prev_plan THEN TRUE
            ELSE FALSE
        END AS is_change
    FROM customer_changes
),

versioned AS (
    SELECT
        {{ dbt_utils.generate_surrogate_key(['customer_id', 'updated_at']) }} AS customer_key,
        customer_id,
        email,
        segment,
        plan_type,
        updated_at AS valid_from,
        LEAD(updated_at) OVER (PARTITION BY customer_id ORDER BY updated_at) AS valid_to
    FROM detected_changes
    WHERE is_change = TRUE
)

SELECT
    customer_key,
    customer_id,
    email,
    segment,
    plan_type,
    valid_from,
    COALESCE(valid_to, '9999-12-31'::DATE) AS valid_to,
    valid_to IS NULL AS is_current
FROM versioned
```

#### 4.3 Why This Matters
- Interviewers WILL ask about star schema vs snowflake
- SCD Type 2 is a specific skill they test for
- Shows you can design, not just implement

---

### Phase 5: Feature Store (Days 13-15)
**Goal:** Demonstrate ML engineering skills with feature management

#### 5.1 Feast Setup
```python
# feature_store/feature_repo/features.py
from feast import Entity, Feature, FeatureView, ValueType
from feast.data_sources import FileSource

# Entities
customer = Entity(
    name="customer",
    value_type=ValueType.STRING,
    description="Customer ID"
)

# Data source
customer_features_source = FileSource(
    path="data/customer_features.parquet",
    timestamp_field="event_timestamp"
)

# Feature view
customer_features = FeatureView(
    name="customer_features",
    entities=["customer"],
    ttl=timedelta(days=1),
    features=[
        Feature(name="lifetime_value", dtype=ValueType.FLOAT),
        Feature(name="total_orders", dtype=ValueType.INT64),
        Feature(name="days_since_last_order", dtype=ValueType.INT64),
        Feature(name="avg_order_value", dtype=ValueType.FLOAT),
        Feature(name="order_frequency_30d", dtype=ValueType.FLOAT),
        Feature(name="churn_probability", dtype=ValueType.FLOAT),
    ],
    online=True,
    source=customer_features_source,
)
```

#### 5.2 Feature Definitions
| Feature | Entity | Aggregation | Window | Refresh |
|---------|--------|-------------|--------|---------|
| `customer_lifetime_value` | customer | sum(amount) | all time | daily |
| `orders_last_30d` | customer | count | 30 days | hourly |
| `avg_order_value` | customer | avg(amount) | 90 days | daily |
| `days_since_last_order` | customer | datediff | - | hourly |
| `channel_conversion_rate` | channel | rate | 7 days | hourly |
| `experiment_exposure_count` | customer | count | - | real-time |

---

### Phase 6: Enhanced Statistical Testing (Days 16-17)
**Goal:** Move beyond basic z-test to production experimentation

#### 6.1 Bayesian A/B Testing
```python
# app/services/experiments/bayesian_stats.py
import pymc as pm
import numpy as np

def bayesian_ab_test(control_conversions, control_total,
                     variant_conversions, variant_total):
    """
    Bayesian A/B test using Beta-Binomial model.
    Returns probability that variant beats control.
    """
    with pm.Model() as model:
        # Priors (uninformative)
        p_control = pm.Beta('p_control', alpha=1, beta=1)
        p_variant = pm.Beta('p_variant', alpha=1, beta=1)

        # Likelihoods
        obs_control = pm.Binomial('obs_control', n=control_total,
                                   p=p_control, observed=control_conversions)
        obs_variant = pm.Binomial('obs_variant', n=variant_total,
                                   p=p_variant, observed=variant_conversions)

        # Difference
        delta = pm.Deterministic('delta', p_variant - p_control)

        # Sample
        trace = pm.sample(2000, return_inferencedata=True)

    # Probability variant wins
    prob_variant_wins = (trace.posterior['delta'] > 0).mean().values

    # Credible interval
    ci = np.percentile(trace.posterior['delta'].values.flatten(), [2.5, 97.5])

    return {
        'prob_variant_wins': float(prob_variant_wins),
        'credible_interval': ci.tolist(),
        'expected_lift': float(trace.posterior['delta'].mean().values)
    }
```

#### 6.2 Sequential Testing (Early Stopping)
```python
# app/services/experiments/sequential_stats.py
from scipy import stats
import numpy as np

def sequential_probability_ratio_test(
    control_conversions, control_total,
    variant_conversions, variant_total,
    alpha=0.05, beta=0.20, mde=0.02
):
    """
    SPRT for early stopping in A/B tests.
    Returns: 'continue', 'reject_null' (variant wins), or 'accept_null' (no difference)
    """
    p0 = control_conversions / control_total  # Null hypothesis rate
    p1 = p0 + mde  # Alternative hypothesis rate

    # Current variant rate
    p_variant = variant_conversions / variant_total

    # Likelihood ratio
    if p_variant == 0 or p_variant == 1:
        return 'continue', None

    # Log likelihood ratio for each observation
    llr = variant_conversions * np.log(p1/p0) + \
          (variant_total - variant_conversions) * np.log((1-p1)/(1-p0))

    # Boundaries
    A = np.log((1-beta)/alpha)  # Upper boundary (reject null)
    B = np.log(beta/(1-alpha))  # Lower boundary (accept null)

    if llr >= A:
        return 'reject_null', {'llr': llr, 'boundary': A}
    elif llr <= B:
        return 'accept_null', {'llr': llr, 'boundary': B}
    else:
        return 'continue', {'llr': llr, 'boundaries': (B, A)}
```

#### 6.3 Power Analysis
```python
# app/services/experiments/power_analysis.py
from scipy import stats
import numpy as np

def calculate_required_sample_size(
    baseline_rate: float,
    mde: float,  # Minimum detectable effect (absolute)
    alpha: float = 0.05,
    power: float = 0.80
) -> int:
    """
    Calculate required sample size per variant for A/B test.
    """
    p1 = baseline_rate
    p2 = baseline_rate + mde

    # Effect size (Cohen's h)
    h = 2 * np.arcsin(np.sqrt(p1)) - 2 * np.arcsin(np.sqrt(p2))

    # Z values
    z_alpha = stats.norm.ppf(1 - alpha/2)
    z_beta = stats.norm.ppf(power)

    # Sample size formula
    n = 2 * ((z_alpha + z_beta) / h) ** 2

    return int(np.ceil(n))

def analyze_test_power(
    control_rate: float,
    variant_rate: float,
    sample_size: int,
    alpha: float = 0.05
) -> dict:
    """
    Calculate achieved power given observed rates and sample size.
    """
    effect = abs(variant_rate - control_rate)
    pooled_se = np.sqrt(2 * control_rate * (1 - control_rate) / sample_size)

    z_alpha = stats.norm.ppf(1 - alpha/2)
    z_effect = effect / pooled_se

    power = 1 - stats.norm.cdf(z_alpha - z_effect)

    return {
        'achieved_power': power,
        'effect_size': effect,
        'is_adequately_powered': power >= 0.80
    }
```

---

### Phase 7: ML Ops with MLflow (Days 18-19)
**Goal:** Add model tracking and registry for production ML

#### 7.1 MLflow Setup
```python
# ml/training/churn_model.py
import mlflow
import mlflow.sklearn
from sklearn.ensemble import GradientBoostingClassifier
from sklearn.model_selection import cross_val_score
import pandas as pd

def train_churn_model(feature_df: pd.DataFrame):
    """
    Train churn prediction model with MLflow tracking.
    """
    mlflow.set_experiment("churn_prediction")

    with mlflow.start_run():
        # Features and target
        X = feature_df.drop(['customer_id', 'churned'], axis=1)
        y = feature_df['churned']

        # Model
        model = GradientBoostingClassifier(
            n_estimators=100,
            max_depth=5,
            learning_rate=0.1
        )

        # Cross-validation
        cv_scores = cross_val_score(model, X, y, cv=5, scoring='roc_auc')

        # Train final model
        model.fit(X, y)

        # Log parameters
        mlflow.log_param("model_type", "GradientBoostingClassifier")
        mlflow.log_param("n_estimators", 100)
        mlflow.log_param("max_depth", 5)
        mlflow.log_param("features", list(X.columns))

        # Log metrics
        mlflow.log_metric("cv_auc_mean", cv_scores.mean())
        mlflow.log_metric("cv_auc_std", cv_scores.std())

        # Log model
        mlflow.sklearn.log_model(
            model,
            "churn_model",
            registered_model_name="churn_predictor"
        )

        # Log feature importance
        importance_df = pd.DataFrame({
            'feature': X.columns,
            'importance': model.feature_importances_
        }).sort_values('importance', ascending=False)

        mlflow.log_table(importance_df, "feature_importance.json")

        return model, cv_scores.mean()
```

#### 7.2 Model Registry Integration
```python
# ml/inference/model_serving.py
import mlflow

class ModelServer:
    def __init__(self, model_name: str, stage: str = "Production"):
        self.model_uri = f"models:/{model_name}/{stage}"
        self.model = mlflow.pyfunc.load_model(self.model_uri)

    def predict(self, features: dict) -> float:
        """
        Get churn probability for a customer.
        """
        import pandas as pd
        df = pd.DataFrame([features])
        return self.model.predict(df)[0]

    def predict_batch(self, feature_df) -> list:
        """
        Batch prediction for multiple customers.
        """
        return self.model.predict(feature_df).tolist()
```

---

### Phase 8: Streaming with Kafka (Days 20-22) - OPTIONAL
**Goal:** Add real-time processing capability

#### 8.1 Kafka Setup
```yaml
# docker-compose.kafka.yml
services:
  zookeeper:
    image: confluentinc/cp-zookeeper:7.4.0
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181

  kafka:
    image: confluentinc/cp-kafka:7.4.0
    depends_on:
      - zookeeper
    ports:
      - "9092:9092"
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: zookeeper:2181
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://localhost:9092
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
```

#### 8.2 Event Consumer
```python
# streaming/consumers/metrics_consumer.py
from kafka import KafkaConsumer
import json
from datetime import datetime

class RealTimeMetricsConsumer:
    def __init__(self):
        self.consumer = KafkaConsumer(
            'user_events',
            bootstrap_servers=['localhost:9092'],
            value_deserializer=lambda m: json.loads(m.decode('utf-8')),
            group_id='metrics_processor'
        )
        self.metrics_buffer = []

    def process_events(self):
        for message in self.consumer:
            event = message.value

            # Route by event type
            if event['type'] == 'transaction':
                self.update_revenue_metrics(event)
            elif event['type'] == 'signup':
                self.update_funnel_metrics(event)
            elif event['type'] == 'experiment_exposure':
                self.update_experiment_metrics(event)

            # Flush buffer periodically
            if len(self.metrics_buffer) >= 100:
                self.flush_to_warehouse()

    def update_revenue_metrics(self, event):
        # Real-time revenue tracking
        pass

    def flush_to_warehouse(self):
        # Batch insert to data warehouse
        pass
```

---

## Revised Project Structure

```
echo/
├── orchestration/                 # NEW: Prefect
│   ├── flows/
│   │   ├── daily_metrics_flow.py
│   │   ├── experiment_analysis_flow.py
│   │   └── data_quality_flow.py
│   ├── tasks/
│   │   ├── extract.py
│   │   ├── validate.py
│   │   ├── transform.py
│   │   └── load.py
│   └── deployments/
│       └── production.yaml
│
├── dbt/                           # NEW: dbt
│   ├── models/
│   │   ├── staging/
│   │   ├── intermediate/
│   │   └── marts/
│   ├── tests/
│   ├── macros/
│   ├── seeds/
│   └── dbt_project.yml
│
├── data_quality/                  # NEW: Great Expectations
│   ├── expectations/
│   │   ├── revenue_data_suite.json
│   │   ├── marketing_data_suite.json
│   │   └── experiment_data_suite.json
│   ├── checkpoints/
│   └── great_expectations.yml
│
├── feature_store/                 # NEW: Feast
│   ├── feature_repo/
│   │   ├── features.py
│   │   ├── entities.py
│   │   └── feature_store.yaml
│   └── data/
│
├── ml/                            # NEW: MLflow
│   ├── training/
│   │   ├── churn_model.py
│   │   └── forecasting_model.py
│   ├── inference/
│   │   └── model_serving.py
│   └── experiments/
│
├── warehouse/                     # NEW: Dimensional Model
│   ├── schemas/
│   │   ├── facts.sql
│   │   └── dimensions.sql
│   └── migrations/
│
├── streaming/                     # NEW: Kafka (optional)
│   ├── consumers/
│   └── producers/
│
├── app/                           # EXISTING: FastAPI (slimmed down)
│   ├── api/v1/
│   ├── services/
│   │   ├── experiments/          # Enhanced stats
│   │   └── llm/                  # Keep conversational AI
│   └── models/
│
├── frontend/                      # EXISTING: Keep as-is
│
├── tests/                         # ENHANCED: More integration tests
│   ├── unit/
│   ├── integration/
│   │   ├── test_pipeline.py
│   │   └── test_data_quality.py
│   └── dbt/
│
├── notebooks/                     # ENHANCED
│   ├── exploratory/
│   ├── modeling/
│   └── experiments/
│
├── docs/                          # ENHANCED
│   ├── architecture.md
│   ├── data_dictionary.md
│   └── runbook.md
│
├── docker-compose.yml             # ENHANCED: Add Kafka, MLflow
├── Makefile                       # NEW: Common commands
└── README.md                      # REWRITTEN for DE focus
```

---

## README Transformation

### Before (Current)
```markdown
# Echo
AI-powered analytics for small businesses. Turn messy CSVs into clear insights.
```

### After (Data Engineering Focus)
```markdown
# Echo Data Platform

Production-grade data platform demonstrating end-to-end data engineering:
ETL orchestration, data quality frameworks, dimensional modeling,
feature stores, and statistical experimentation.

## Architecture
- **Orchestration**: Prefect pipelines with scheduling, retries, observability
- **Data Quality**: Great Expectations with 50+ expectations across 15 data assets
- **Transformation**: dbt with 30+ models, tests, and documentation
- **Warehouse**: Star schema with SCD Type 2 dimensions
- **Feature Store**: Feast managing 25+ features for ML models
- **ML Ops**: MLflow for experiment tracking and model registry
- **Statistics**: Bayesian A/B testing, sequential analysis, power calculations

## Data Engineering Skills Demonstrated
- Designed and implemented ETL pipelines processing 100K+ records
- Built dimensional data warehouse with slowly changing dimensions
- Created data quality framework preventing bad data from entering warehouse
- Implemented feature store for consistent feature engineering
- Built statistical experimentation platform for product decisions
```

---

## Priority Matrix

| Priority | Task | Time | Impact | Dependencies |
|----------|------|------|--------|--------------|
| **P0** | Prefect DAG setup | 2 days | Very High | None |
| **P0** | Great Expectations | 2 days | Very High | Prefect |
| **P0** | dbt project setup | 3 days | Very High | None |
| **P1** | Dimensional model | 2 days | High | dbt |
| **P1** | SCD Type 2 implementation | 1 day | High | Dimensional model |
| **P1** | Bayesian A/B testing | 1 day | High | None |
| **P2** | Feature store (Feast) | 2 days | Medium | dbt |
| **P2** | MLflow integration | 2 days | Medium | Feature store |
| **P2** | Churn prediction model | 2 days | Medium | MLflow |
| **P3** | Kafka streaming | 3 days | Low | All above |

---

## Success Criteria

When complete, Echo should demonstrate:

1. **Can design data pipelines**: Prefect DAGs with proper error handling
2. **Understands data quality**: Great Expectations suites with meaningful checks
3. **Knows analytics engineering**: dbt models with tests and documentation
4. **Can model data warehouses**: Star schema, SCDs, proper grain
5. **Understands ML engineering**: Feature stores, model registry
6. **Has statistical rigor**: Multiple testing approaches, power analysis
7. **Can explain decisions**: Clear documentation and lineage

---

## Timeline

**Aggressive (Winter Break Focus):**
- Week 1: Prefect + Great Expectations + dbt setup
- Week 2: Dimensional model + dbt models
- Week 3: Feature store + Enhanced statistics
- Week 4: MLflow + Polish + Documentation

**Conservative (Ongoing):**
- Month 1: Core pipeline (Prefect + GX + dbt)
- Month 2: Warehouse design + Feature store
- Month 3: ML Ops + Streaming

---

## Questions to Address in Interviews

After this transformation, you'll be able to answer:

1. "Walk me through your ETL pipeline" → Prefect flow with GX validation
2. "How do you ensure data quality?" → Great Expectations suites + data contracts
3. "Explain your data model" → Star schema with facts, dimensions, SCDs
4. "How do you handle slowly changing dimensions?" → SCD Type 2 implementation
5. "How do you manage features for ML?" → Feast feature store
6. "How do you track ML experiments?" → MLflow experiment tracking
7. "How would you decide if an A/B test is significant?" → Bayesian + frequentist approaches
8. "What's your approach to data testing?" → dbt tests + GX expectations

---

## Next Steps

1. Review this plan and provide feedback
2. Prioritize based on your timeline
3. Start with Phase 1 (Prefect) as foundation
4. Iterate and document as you build
