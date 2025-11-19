# Phase 2: Deterministic Analytics Layer

**Duration**: 7-10 days
**Goal**: Implement accurate, testable business metrics

---

## Overview

This phase focuses on building the deterministic analytics engine - the core of Echo's value proposition. Instead of relying on LLMs for calculations, we'll implement accurate business metrics using SQL/Python that can be tested and verified. The LLM will only be used for explanation and narrative.

**Key Principle**: "Deterministic metrics + LLM narrative on top"

---

## Objectives

1. Design metrics engine architecture
2. Implement revenue metrics (MRR, ARR, growth rate)
3. Implement financial metrics (CAC, LTV, burn rate)
4. Implement marketing metrics (conversion rates, funnel analysis)
5. Implement time-series analysis utilities
6. Create metric registry/catalog
7. Build comprehensive test suite for all metrics
8. Ensure metrics match manual calculations

---

## Detailed Tasks

### Task 1: Metrics Engine Architecture

**Goal**: Design flexible, extensible metrics calculation system

**Base Metric Class** (`app/services/metrics/base.py`):
```python
from abc import ABC, abstractmethod
from typing import Dict, Any, List
import pandas as pd
from pydantic import BaseModel
from datetime import datetime


class MetricResult(BaseModel):
    """Result of a metric calculation"""
    metric_name: str
    value: float
    unit: str  # "$", "%", "count", etc.
    period: str  # "2024-01", "Q1 2024", etc.
    metadata: Dict[str, Any] = {}
    calculated_at: datetime = datetime.now()


class MetricDefinition(BaseModel):
    """Metadata about a metric"""
    name: str
    display_name: str
    description: str
    category: str  # "revenue", "financial", "marketing", etc.
    unit: str
    formula: str  # Human-readable formula
    required_columns: List[str]


class BaseMetric(ABC):
    """Base class for all metrics"""

    def __init__(self, df: pd.DataFrame):
        self.df = df
        self.validate_data()

    @abstractmethod
    def calculate(self) -> MetricResult:
        """Calculate the metric"""
        pass

    @abstractmethod
    def get_definition(self) -> MetricDefinition:
        """Get metric metadata"""
        pass

    def validate_data(self):
        """Validate that required columns exist"""
        definition = self.get_definition()
        missing_cols = [
            col for col in definition.required_columns
            if col not in self.df.columns
        ]
        if missing_cols:
            raise ValueError(
                f"Missing required columns for {definition.name}: {missing_cols}"
            )

    def format_result(self, value: float, period: str = None, **metadata) -> MetricResult:
        """Helper to format metric result"""
        definition = self.get_definition()
        return MetricResult(
            metric_name=definition.name,
            value=value,
            unit=definition.unit,
            period=period or "all_time",
            metadata=metadata
        )
```

**Metrics Engine** (`app/services/metrics/engine.py`):
```python
from typing import List, Dict, Type
import pandas as pd
from app.services.metrics.base import BaseMetric, MetricResult, MetricDefinition


class MetricsEngine:
    """Central engine for calculating metrics"""

    def __init__(self, df: pd.DataFrame):
        self.df = df
        self._registry: Dict[str, Type[BaseMetric]] = {}

    def register_metric(self, metric_class: Type[BaseMetric]):
        """Register a metric class"""
        instance = metric_class(pd.DataFrame())  # Temp instance for definition
        definition = instance.get_definition()
        self._registry[definition.name] = metric_class

    def calculate_metric(self, metric_name: str) -> MetricResult:
        """Calculate a single metric"""
        if metric_name not in self._registry:
            raise ValueError(f"Unknown metric: {metric_name}")

        metric_class = self._registry[metric_name]
        metric = metric_class(self.df)
        return metric.calculate()

    def calculate_all(self, category: str = None) -> List[MetricResult]:
        """Calculate all metrics (optionally filtered by category)"""
        results = []
        for metric_name, metric_class in self._registry.items():
            try:
                metric = metric_class(self.df)
                if category is None or metric.get_definition().category == category:
                    result = metric.calculate()
                    results.append(result)
            except Exception as e:
                # Log error but continue with other metrics
                print(f"Error calculating {metric_name}: {e}")
        return results

    def list_metrics(self, category: str = None) -> List[MetricDefinition]:
        """List available metrics"""
        definitions = []
        for metric_class in self._registry.values():
            instance = metric_class(pd.DataFrame())
            definition = instance.get_definition()
            if category is None or definition.category == category:
                definitions.append(definition)
        return definitions
```

**Action Items**:
- [ ] Create `BaseMetric` abstract class
- [ ] Create `MetricsEngine`
- [ ] Design metric registry system
- [ ] Create result and definition models

---

### Task 2: Revenue Metrics

**Goal**: Implement core revenue calculations

**Total Revenue** (`app/services/metrics/revenue/total_revenue.py`):
```python
from app.services.metrics.base import BaseMetric, MetricResult, MetricDefinition


class TotalRevenue(BaseMetric):
    """Total revenue metric"""

    def get_definition(self) -> MetricDefinition:
        return MetricDefinition(
            name="total_revenue",
            display_name="Total Revenue",
            description="Sum of all revenue in the period",
            category="revenue",
            unit="$",
            formula="SUM(amount WHERE status = 'paid')",
            required_columns=["amount"]
        )

    def calculate(self) -> MetricResult:
        # Filter for successful transactions only
        if 'status' in self.df.columns:
            paid_df = self.df[self.df['status'].isin(['paid', 'success', 'completed'])]
        else:
            paid_df = self.df

        total = paid_df['amount'].sum()

        return self.format_result(
            value=float(total),
            transaction_count=len(paid_df),
            average_transaction=float(paid_df['amount'].mean())
        )


**MRR (Monthly Recurring Revenue)** (`app/services/metrics/revenue/mrr.py`):
```python
import pandas as pd
from app.services.metrics.base import BaseMetric, MetricResult, MetricDefinition


class MRR(BaseMetric):
    """Monthly Recurring Revenue"""

    def get_definition(self) -> MetricDefinition:
        return MetricDefinition(
            name="mrr",
            display_name="Monthly Recurring Revenue (MRR)",
            description="Recurring revenue normalized to a monthly amount",
            category="revenue",
            unit="$",
            formula="SUM(monthly_amount) for active subscriptions",
            required_columns=["amount", "billing_period"]
        )

    def calculate(self) -> MetricResult:
        # Normalize to monthly amounts
        df = self.df.copy()

        # Convert different billing periods to monthly
        df['monthly_amount'] = df.apply(self._normalize_to_monthly, axis=1)

        # Filter active subscriptions
        if 'status' in df.columns:
            active = df[df['status'].isin(['active', 'paid'])]
        else:
            active = df

        mrr = active['monthly_amount'].sum()

        return self.format_result(
            value=float(mrr),
            subscriber_count=len(active),
            average_per_subscriber=float(mrr / len(active)) if len(active) > 0 else 0
        )

    def _normalize_to_monthly(self, row):
        """Convert billing amount to monthly equivalent"""
        amount = row['amount']
        period = row.get('billing_period', 'monthly').lower()

        if period in ['month', 'monthly']:
            return amount
        elif period in ['year', 'annual', 'yearly']:
            return amount / 12
        elif period in ['quarter', 'quarterly']:
            return amount / 3
        elif period in ['week', 'weekly']:
            return amount * 4.33
        else:
            return amount  # Assume monthly if unknown


**ARR (Annual Recurring Revenue)** (`app/services/metrics/revenue/arr.py`):
```python
from app.services.metrics.base import BaseMetric, MetricResult, MetricDefinition


class ARR(BaseMetric):
    """Annual Recurring Revenue"""

    def get_definition(self) -> MetricDefinition:
        return MetricDefinition(
            name="arr",
            display_name="Annual Recurring Revenue (ARR)",
            description="Recurring revenue normalized to annual amount (MRR * 12)",
            category="revenue",
            unit="$",
            formula="MRR * 12",
            required_columns=["amount", "billing_period"]
        )

    def calculate(self) -> MetricResult:
        # Use MRR calculation and multiply by 12
        from app.services.metrics.revenue.mrr import MRR

        mrr_metric = MRR(self.df)
        mrr_result = mrr_metric.calculate()

        arr = mrr_result.value * 12

        return self.format_result(
            value=float(arr),
            mrr=mrr_result.value,
            **mrr_result.metadata
        )


**Revenue Growth Rate** (`app/services/metrics/revenue/growth_rate.py`):
```python
import pandas as pd
from app.services.metrics.base import BaseMetric, MetricResult, MetricDefinition


class RevenueGrowthRate(BaseMetric):
    """Period-over-period revenue growth rate"""

    def get_definition(self) -> MetricDefinition:
        return MetricDefinition(
            name="revenue_growth_rate",
            display_name="Revenue Growth Rate",
            description="Percentage change in revenue compared to previous period",
            category="revenue",
            unit="%",
            formula="((current_revenue - previous_revenue) / previous_revenue) * 100",
            required_columns=["amount", "date"]
        )

    def calculate(self, period: str = "month") -> MetricResult:
        # Ensure date column is datetime
        df = self.df.copy()
        df['date'] = pd.to_datetime(df['date'])

        # Group by period
        if period == "month":
            df['period'] = df['date'].dt.to_period('M')
        elif period == "week":
            df['period'] = df['date'].dt.to_period('W')
        elif period == "quarter":
            df['period'] = df['date'].dt.to_period('Q')

        # Calculate revenue per period
        revenue_by_period = df.groupby('period')['amount'].sum().sort_index()

        if len(revenue_by_period) < 2:
            return self.format_result(
                value=0.0,
                message="Insufficient data for growth calculation"
            )

        # Calculate growth rate
        current = revenue_by_period.iloc[-1]
        previous = revenue_by_period.iloc[-2]

        growth_rate = ((current - previous) / previous) * 100 if previous > 0 else 0

        return self.format_result(
            value=float(growth_rate),
            current_period_revenue=float(current),
            previous_period_revenue=float(previous),
            period_type=period
        )
```

**Action Items**:
- [ ] Implement `TotalRevenue` metric
- [ ] Implement `MRR` metric
- [ ] Implement `ARR` metric
- [ ] Implement `RevenueGrowthRate` metric
- [ ] Add tests for each metric

---

### Task 3: Financial Metrics

**Goal**: Implement key financial health indicators

**CAC (Customer Acquisition Cost)** (`app/services/metrics/financial/cac.py`):
```python
from app.services.metrics.base import BaseMetric, MetricResult, MetricDefinition


class CAC(BaseMetric):
    """Customer Acquisition Cost"""

    def get_definition(self) -> MetricDefinition:
        return MetricDefinition(
            name="cac",
            display_name="Customer Acquisition Cost (CAC)",
            description="Cost to acquire a new customer",
            category="financial",
            unit="$",
            formula="Total Marketing Spend / Number of New Customers",
            required_columns=["marketing_spend", "new_customers"]
        )

    def calculate(self) -> MetricResult:
        total_spend = self.df['marketing_spend'].sum()
        total_customers = self.df['new_customers'].sum()

        cac = total_spend / total_customers if total_customers > 0 else 0

        return self.format_result(
            value=float(cac),
            total_spend=float(total_spend),
            new_customers=int(total_customers)
        )


**LTV (Lifetime Value)** (`app/services/metrics/financial/ltv.py`):
```python
from app.services.metrics.base import BaseMetric, MetricResult, MetricDefinition


class LTV(BaseMetric):
    """Customer Lifetime Value"""

    def get_definition(self) -> MetricDefinition:
        return MetricDefinition(
            name="ltv",
            display_name="Customer Lifetime Value (LTV)",
            description="Predicted revenue from a customer over their lifetime",
            category="financial",
            unit="$",
            formula="Average Revenue Per Customer * Average Customer Lifespan",
            required_columns=["customer_id", "amount"]
        )

    def calculate(self, avg_lifespan_months: int = 24) -> MetricResult:
        # Calculate average revenue per customer
        revenue_per_customer = self.df.groupby('customer_id')['amount'].sum()
        avg_revenue = revenue_per_customer.mean()

        # Simple LTV calculation
        # In production, you'd want to account for churn rate
        ltv = avg_revenue * (avg_lifespan_months / 12)

        return self.format_result(
            value=float(ltv),
            avg_customer_revenue=float(avg_revenue),
            assumed_lifespan_months=avg_lifespan_months,
            total_customers=len(revenue_per_customer)
        )


**LTV:CAC Ratio** (`app/services/metrics/financial/ltv_cac_ratio.py`):
```python
from app.services.metrics.base import BaseMetric, MetricResult, MetricDefinition


class LTVCACRatio(BaseMetric):
    """LTV to CAC ratio"""

    def get_definition(self) -> MetricDefinition:
        return MetricDefinition(
            name="ltv_cac_ratio",
            display_name="LTV:CAC Ratio",
            description="Ratio of customer lifetime value to acquisition cost (healthy > 3)",
            category="financial",
            unit="ratio",
            formula="LTV / CAC",
            required_columns=["customer_id", "amount", "marketing_spend", "new_customers"]
        )

    def calculate(self) -> MetricResult:
        from app.services.metrics.financial.ltv import LTV
        from app.services.metrics.financial.cac import CAC

        ltv_metric = LTV(self.df)
        cac_metric = CAC(self.df)

        ltv_result = ltv_metric.calculate()
        cac_result = cac_metric.calculate()

        ratio = ltv_result.value / cac_result.value if cac_result.value > 0 else 0

        # Determine health status
        if ratio >= 3:
            status = "healthy"
        elif ratio >= 1:
            status = "acceptable"
        else:
            status = "concerning"

        return self.format_result(
            value=float(ratio),
            ltv=ltv_result.value,
            cac=cac_result.value,
            status=status
        )
```

**Action Items**:
- [ ] Implement `CAC` metric
- [ ] Implement `LTV` metric
- [ ] Implement `LTVCACRatio` metric
- [ ] Implement `ChurnRate` metric
- [ ] Add tests for financial metrics

---

### Task 4: Marketing Metrics

**Goal**: Implement marketing funnel and performance metrics

**Conversion Rate** (`app/services/metrics/marketing/conversion_rate.py`):
```python
from app.services.metrics.base import BaseMetric, MetricResult, MetricDefinition


class ConversionRate(BaseMetric):
    """Conversion rate metric"""

    def get_definition(self) -> MetricDefinition:
        return MetricDefinition(
            name="conversion_rate",
            display_name="Conversion Rate",
            description="Percentage of leads that convert to customers",
            category="marketing",
            unit="%",
            formula="(Conversions / Total Leads) * 100",
            required_columns=["status"]
        )

    def calculate(self) -> MetricResult:
        total = len(self.df)

        # Count conversions (flexible status matching)
        converted = self.df[
            self.df['status'].isin(['converted', 'customer', 'won', 'closed'])
        ]
        conversion_count = len(converted)

        rate = (conversion_count / total * 100) if total > 0 else 0

        return self.format_result(
            value=float(rate),
            total_leads=total,
            conversions=conversion_count
        )


**Funnel Analysis** (`app/services/metrics/marketing/funnel.py`):
```python
import pandas as pd
from app.services.metrics.base import BaseMetric, MetricResult, MetricDefinition
from typing import List


class FunnelAnalysis(BaseMetric):
    """Marketing funnel analysis"""

    def get_definition(self) -> MetricDefinition:
        return MetricDefinition(
            name="funnel_analysis",
            display_name="Funnel Analysis",
            description="Analyze conversion through marketing funnel stages",
            category="marketing",
            unit="count",
            formula="Count users at each funnel stage",
            required_columns=["stage"]
        )

    def calculate(self, stage_order: List[str] = None) -> MetricResult:
        if stage_order is None:
            stage_order = ['lead', 'qualified', 'opportunity', 'customer']

        # Count by stage
        stage_counts = {}
        for stage in stage_order:
            count = len(self.df[self.df['stage'].str.lower() == stage.lower()])
            stage_counts[stage] = count

        # Calculate drop-off rates
        dropoff_rates = {}
        for i in range(len(stage_order) - 1):
            current_stage = stage_order[i]
            next_stage = stage_order[i + 1]

            current_count = stage_counts[current_stage]
            next_count = stage_counts[next_stage]

            if current_count > 0:
                conversion = (next_count / current_count) * 100
                dropoff = 100 - conversion
                dropoff_rates[f"{current_stage}_to_{next_stage}"] = {
                    "conversion": conversion,
                    "dropoff": dropoff
                }

        return self.format_result(
            value=stage_counts.get('customer', 0),
            stage_counts=stage_counts,
            dropoff_rates=dropoff_rates,
            total_entered=stage_counts.get(stage_order[0], 0)
        )


**Channel Performance** (`app/services/metrics/marketing/channel_performance.py`):
```python
import pandas as pd
from app.services.metrics.base import BaseMetric, MetricResult, MetricDefinition


class ChannelPerformance(BaseMetric):
    """Performance by marketing channel"""

    def get_definition(self) -> MetricDefinition:
        return MetricDefinition(
            name="channel_performance",
            display_name="Channel Performance",
            description="Compare performance across marketing channels",
            category="marketing",
            unit="count",
            formula="Group by source/channel and calculate metrics",
            required_columns=["source"]
        )

    def calculate(self) -> MetricResult:
        df = self.df.copy()

        # Group by source
        channel_stats = df.groupby('source').agg({
            'source': 'count',  # Total leads
            'amount': 'sum' if 'amount' in df.columns else 'count'
        }).rename(columns={'source': 'leads', 'amount': 'revenue'})

        # Calculate conversions per channel if status exists
        if 'status' in df.columns:
            conversions = df[
                df['status'].isin(['converted', 'customer', 'won'])
            ].groupby('source').size()
            channel_stats['conversions'] = conversions
            channel_stats['conversion_rate'] = (
                channel_stats['conversions'] / channel_stats['leads'] * 100
            )

        # Sort by performance
        sort_by = 'revenue' if 'revenue' in channel_stats.columns else 'leads'
        channel_stats = channel_stats.sort_values(sort_by, ascending=False)

        # Find top performer
        top_channel = channel_stats.index[0] if len(channel_stats) > 0 else None

        return self.format_result(
            value=len(channel_stats),
            channels=channel_stats.to_dict('index'),
            top_channel=top_channel
        )
```

**Action Items**:
- [ ] Implement `ConversionRate` metric
- [ ] Implement `FunnelAnalysis` metric
- [ ] Implement `ChannelPerformance` metric
- [ ] Add tests for marketing metrics

---

### Task 5: Time-Series Utilities

**Goal**: Helper functions for period-over-period analysis

**Time-Series Helper** (`app/services/metrics/utils/timeseries.py`):
```python
import pandas as pd
from typing import Dict, List
from datetime import datetime, timedelta


class TimeSeriesAnalyzer:
    """Utilities for time-series analysis"""

    def __init__(self, df: pd.DataFrame, date_column: str = 'date'):
        self.df = df.copy()
        self.date_column = date_column
        self.df[date_column] = pd.to_datetime(self.df[date_column])

    def group_by_period(
        self,
        value_column: str,
        period: str = 'month',
        agg_func: str = 'sum'
    ) -> pd.Series:
        """Group data by time period"""
        df = self.df.copy()

        if period == 'day':
            df['period'] = df[self.date_column].dt.date
        elif period == 'week':
            df['period'] = df[self.date_column].dt.to_period('W')
        elif period == 'month':
            df['period'] = df[self.date_column].dt.to_period('M')
        elif period == 'quarter':
            df['period'] = df[self.date_column].dt.to_period('Q')
        elif period == 'year':
            df['period'] = df[self.date_column].dt.to_period('Y')

        if agg_func == 'sum':
            return df.groupby('period')[value_column].sum()
        elif agg_func == 'mean':
            return df.groupby('period')[value_column].mean()
        elif agg_func == 'count':
            return df.groupby('period')[value_column].count()

    def calculate_growth(
        self,
        series: pd.Series,
        periods: int = 1
    ) -> pd.Series:
        """Calculate period-over-period growth"""
        return series.pct_change(periods=periods) * 100

    def calculate_moving_average(
        self,
        series: pd.Series,
        window: int = 7
    ) -> pd.Series:
        """Calculate moving average"""
        return series.rolling(window=window).mean()

    def detect_trends(
        self,
        series: pd.Series
    ) -> Dict[str, any]:
        """Detect trends in time series"""
        # Simple trend detection
        if len(series) < 3:
            return {"trend": "insufficient_data"}

        # Calculate linear regression slope
        x = range(len(series))
        y = series.values

        slope = pd.Series(y).corr(pd.Series(x))

        if slope > 0.5:
            trend = "strong_upward"
        elif slope > 0.2:
            trend = "upward"
        elif slope < -0.5:
            trend = "strong_downward"
        elif slope < -0.2:
            trend = "downward"
        else:
            trend = "stable"

        return {
            "trend": trend,
            "slope": slope,
            "latest_value": float(series.iloc[-1]),
            "change_from_start": float((series.iloc[-1] - series.iloc[0]) / series.iloc[0] * 100)
        }
```

**Action Items**:
- [ ] Create `TimeSeriesAnalyzer` utility
- [ ] Implement period grouping
- [ ] Implement growth calculations
- [ ] Implement trend detection
- [ ] Add tests for time-series utils

---

### Task 6: Metric Registry

**Goal**: Central catalog of all available metrics

**Registry** (`app/services/metrics/registry.py`):
```python
from app.services.metrics.engine import MetricsEngine

# Import all metric classes
from app.services.metrics.revenue.total_revenue import TotalRevenue
from app.services.metrics.revenue.mrr import MRR
from app.services.metrics.revenue.arr import ARR
from app.services.metrics.revenue.growth_rate import RevenueGrowthRate

from app.services.metrics.financial.cac import CAC
from app.services.metrics.financial.ltv import LTV
from app.services.metrics.financial.ltv_cac_ratio import LTVCACRatio

from app.services.metrics.marketing.conversion_rate import ConversionRate
from app.services.metrics.marketing.funnel import FunnelAnalysis
from app.services.metrics.marketing.channel_performance import ChannelPerformance


def create_metrics_engine(df) -> MetricsEngine:
    """Create a metrics engine with all metrics registered"""
    engine = MetricsEngine(df)

    # Register revenue metrics
    engine.register_metric(TotalRevenue)
    engine.register_metric(MRR)
    engine.register_metric(ARR)
    engine.register_metric(RevenueGrowthRate)

    # Register financial metrics
    engine.register_metric(CAC)
    engine.register_metric(LTV)
    engine.register_metric(LTVCACRatio)

    # Register marketing metrics
    engine.register_metric(ConversionRate)
    engine.register_metric(FunnelAnalysis)
    engine.register_metric(ChannelPerformance)

    return engine
```

**Metrics Endpoint** (`app/api/v1/metrics.py`):
```python
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from typing import List

from app.core.database import get_db
from app.models.schemas import MetricResult
from app.services.metrics.registry import create_metrics_engine
from app.services.ingestion import IngestionService

router = APIRouter()


@router.get("/metrics/{source_id}", response_model=List[MetricResult])
async def calculate_metrics(
    source_id: str,
    category: str = None,
    db: AsyncSession = Depends(get_db)
):
    """Calculate metrics for a data source"""
    # Get data source
    ingestion_service = IngestionService(db)
    source = await ingestion_service.get_source(source_id)

    if not source:
        raise HTTPException(status_code=404, detail="Source not found")

    # Load data (simplified - you'd load actual data from storage)
    # For now, assume we have the DataFrame
    # df = load_dataframe_from_source(source)

    # Create metrics engine
    # engine = create_metrics_engine(df)

    # Calculate metrics
    # results = engine.calculate_all(category=category)

    # return results

    return []
```

**Action Items**:
- [ ] Create metric registry
- [ ] Register all implemented metrics
- [ ] Create metrics calculation endpoint
- [ ] Document available metrics

---

### Task 7: Comprehensive Testing

**Goal**: Ensure all metrics are accurate and testable

**Test Structure** (`tests/services/metrics/test_revenue_metrics.py`):
```python
import pytest
import pandas as pd
from datetime import datetime, timedelta

from app.services.metrics.revenue.total_revenue import TotalRevenue
from app.services.metrics.revenue.mrr import MRR
from app.services.metrics.revenue.growth_rate import RevenueGrowthRate


class TestTotalRevenue:
    """Tests for TotalRevenue metric"""

    def test_basic_calculation(self):
        """Test basic revenue calculation"""
        df = pd.DataFrame({
            'amount': [100, 200, 300],
            'status': ['paid', 'paid', 'paid']
        })

        metric = TotalRevenue(df)
        result = metric.calculate()

        assert result.value == 600
        assert result.metadata['transaction_count'] == 3
        assert result.metadata['average_transaction'] == 200

    def test_filters_unpaid(self):
        """Test that unpaid transactions are excluded"""
        df = pd.DataFrame({
            'amount': [100, 200, 300],
            'status': ['paid', 'failed', 'paid']
        })

        metric = TotalRevenue(df)
        result = metric.calculate()

        assert result.value == 400  # Only paid transactions
        assert result.metadata['transaction_count'] == 2

    def test_empty_dataframe(self):
        """Test with empty data"""
        df = pd.DataFrame({'amount': [], 'status': []})

        metric = TotalRevenue(df)
        result = metric.calculate()

        assert result.value == 0


class TestMRR:
    """Tests for MRR metric"""

    def test_monthly_subscriptions(self):
        """Test with monthly subscriptions"""
        df = pd.DataFrame({
            'amount': [50, 100, 150],
            'billing_period': ['monthly', 'monthly', 'monthly'],
            'status': ['active', 'active', 'active']
        })

        metric = MRR(df)
        result = metric.calculate()

        assert result.value == 300

    def test_annual_subscriptions(self):
        """Test with annual subscriptions"""
        df = pd.DataFrame({
            'amount': [1200],  # $1200/year
            'billing_period': ['annual'],
            'status': ['active']
        })

        metric = MRR(df)
        result = metric.calculate()

        assert result.value == 100  # $1200/12 months

    def test_mixed_billing_periods(self):
        """Test with mixed billing periods"""
        df = pd.DataFrame({
            'amount': [100, 1200, 300],
            'billing_period': ['monthly', 'annual', 'quarterly'],
            'status': ['active', 'active', 'active']
        })

        metric = MRR(df)
        result = metric.calculate()

        # 100 + 100 (1200/12) + 100 (300/3) = 300
        assert result.value == 300


class TestRevenueGrowthRate:
    """Tests for RevenueGrowthRate metric"""

    def test_positive_growth(self):
        """Test positive growth calculation"""
        dates = [datetime(2024, 1, i) for i in range(1, 32)]
        dates.extend([datetime(2024, 2, i) for i in range(1, 29)])

        df = pd.DataFrame({
            'date': dates,
            'amount': [100] * 31 + [150] * 28  # $100/day in Jan, $150/day in Feb
        })

        metric = RevenueGrowthRate(df)
        result = metric.calculate(period='month')

        # February revenue is 50% higher than January
        assert result.value > 0
        assert 'current_period_revenue' in result.metadata
        assert 'previous_period_revenue' in result.metadata
```

**Action Items**:
- [ ] Write tests for all revenue metrics
- [ ] Write tests for all financial metrics
- [ ] Write tests for all marketing metrics
- [ ] Test edge cases (empty data, missing columns, etc.)
- [ ] Test with real sample data
- [ ] Achieve >90% test coverage for metrics

---

## Acceptance Criteria

### Phase 2 is complete when:

1. **Metrics Engine**:
   - [ ] Base metric class is implemented
   - [ ] Metrics engine can register and execute metrics
   - [ ] Metric registry contains all implemented metrics

2. **Revenue Metrics**:
   - [ ] Total Revenue calculates correctly
   - [ ] MRR handles different billing periods
   - [ ] ARR is calculated from MRR
   - [ ] Growth rate shows period-over-period changes

3. **Financial Metrics**:
   - [ ] CAC calculates acquisition cost
   - [ ] LTV estimates customer value
   - [ ] LTV:CAC ratio provides health indicator

4. **Marketing Metrics**:
   - [ ] Conversion rate calculates correctly
   - [ ] Funnel analysis shows drop-off rates
   - [ ] Channel performance compares sources

5. **Testing**:
   - [ ] All metrics have unit tests
   - [ ] Tests use known datasets with expected results
   - [ ] Edge cases are covered
   - [ ] Test coverage >90%

6. **Validation**:
   - [ ] Metrics match manual calculations
   - [ ] Results are deterministic (same input = same output)
   - [ ] No LLM hallucination in calculations

---

## Next Steps

After completing Phase 2, proceed to:
- **Phase 3**: Workflow & User Flow (where LLMs will explain these metrics)

---

*Last Updated: 2025-11-19*
