# Phase 4: Evaluation & Metrics

**Duration**: 3-5 days
**Goal**: Add instrumentation and measure impact

---

## Overview

This phase focuses on measuring Echo's effectiveness and impact. We'll track time saved, user satisfaction, and accuracy of insights. This data is crucial for demonstrating value to potential employers and users.

**Key Principle**: "What gets measured gets improved"

---

## Objectives

1. Implement time tracking (manual vs Echo)
2. Build user feedback system
3. Create accuracy evaluation framework
4. Design analytics dashboard
5. Add comprehensive logging and telemetry
6. Generate impact metrics for portfolio

---

## Detailed Tasks

### Task 1: Time Tracking System

**Goal**: Measure time saved by using Echo

**Time Tracking Model** (`app/models/time_tracking.py`):
```python
from sqlalchemy import Column, String, DateTime, Float, JSON
from sqlalchemy.sql import func
from app.core.database import Base


class TimeEntry(Base):
    __tablename__ = "time_entries"

    id = Column(String, primary_key=True)
    user_id = Column(String, nullable=False)
    report_id = Column(String)
    task_type = Column(String)  # "manual" or "echo"
    started_at = Column(DateTime(timezone=True))
    completed_at = Column(DateTime(timezone=True))
    duration_seconds = Column(Float)
    metadata = Column(JSON)
```

**Time Tracker Service** (`app/services/evaluation/time_tracker.py`):
```python
from datetime import datetime
from typing import Dict, Optional
import uuid
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.time_tracking import TimeEntry


class TimeTracker:
    """Track time spent on tasks"""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def start_task(
        self,
        user_id: str,
        task_type: str,
        metadata: Dict = None
    ) -> str:
        """Start timing a task"""
        entry_id = str(uuid.uuid4())

        entry = TimeEntry(
            id=entry_id,
            user_id=user_id,
            task_type=task_type,
            started_at=datetime.now(),
            metadata=metadata or {}
        )

        self.db.add(entry)
        await self.db.commit()

        return entry_id

    async def complete_task(self, entry_id: str):
        """Complete a task and calculate duration"""
        entry = await self.db.get(TimeEntry, entry_id)

        if entry:
            entry.completed_at = datetime.now()
            entry.duration_seconds = (
                entry.completed_at - entry.started_at
            ).total_seconds()

            await self.db.commit()

    async def get_average_time(
        self,
        task_type: str,
        user_id: Optional[str] = None
    ) -> float:
        """Get average time for a task type"""
        # Query and calculate average
        # Implementation here
        pass

    async def calculate_time_saved(self) -> Dict:
        """Calculate time saved by using Echo vs manual"""
        manual_avg = await self.get_average_time("manual")
        echo_avg = await self.get_average_time("echo")

        time_saved = manual_avg - echo_avg
        percentage_saved = (time_saved / manual_avg * 100) if manual_avg > 0 else 0

        return {
            "manual_avg_seconds": manual_avg,
            "echo_avg_seconds": echo_avg,
            "time_saved_seconds": time_saved,
            "time_saved_minutes": time_saved / 60,
            "percentage_saved": percentage_saved
        }
```

**Time Tracking Middleware** (`app/api/middleware/time_tracking.py`):
```python
from fastapi import Request
from time import time
from app.core.cache import get_redis
import json


async def track_request_time(request: Request, call_next):
    """Middleware to track API request times"""
    start_time = time()

    response = await call_next(request)

    duration = time() - start_time

    # Log to Redis for analytics
    redis = await get_redis()
    await redis.lpush(
        "request_times",
        json.dumps({
            "path": request.url.path,
            "method": request.method,
            "duration": duration,
            "timestamp": start_time
        })
    )

    # Add header with duration
    response.headers["X-Process-Time"] = str(duration)

    return response
```

**Action Items**:
- [ ] Create `TimeEntry` model
- [ ] Implement `TimeTracker` service
- [ ] Add time tracking middleware
- [ ] Create endpoint to submit manual times (for comparison)
- [ ] Build time comparison analytics

---

### Task 2: User Feedback System

**Goal**: Collect user satisfaction ratings

**Feedback Model** (`app/models/feedback.py`):
```python
from sqlalchemy import Column, String, DateTime, Integer, Text
from sqlalchemy.sql import func
from app.core.database import Base


class ReportFeedback(Base):
    __tablename__ = "report_feedback"

    id = Column(String, primary_key=True)
    report_id = Column(String, nullable=False)
    user_id = Column(String, nullable=False)
    rating = Column(Integer)  # 1-5
    helpful = Column(Integer)  # 1-5
    accurate = Column(Integer)  # 1-5
    comment = Column(Text)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
```

**Feedback Service** (`app/services/evaluation/feedback.py`):
```python
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
import uuid

from app.models.feedback import ReportFeedback


class FeedbackService:
    """Service for collecting and analyzing feedback"""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def submit_feedback(
        self,
        report_id: str,
        user_id: str,
        rating: int,
        helpful: int,
        accurate: int,
        comment: str = None
    ) -> str:
        """Submit feedback for a report"""
        feedback_id = str(uuid.uuid4())

        feedback = ReportFeedback(
            id=feedback_id,
            report_id=report_id,
            user_id=user_id,
            rating=rating,
            helpful=helpful,
            accurate=accurate,
            comment=comment
        )

        self.db.add(feedback)
        await self.db.commit()

        return feedback_id

    async def get_average_ratings(self) -> dict:
        """Get average ratings across all feedback"""
        result = await self.db.execute(
            select(
                func.avg(ReportFeedback.rating).label('avg_rating'),
                func.avg(ReportFeedback.helpful).label('avg_helpful'),
                func.avg(ReportFeedback.accurate).label('avg_accurate'),
                func.count(ReportFeedback.id).label('total_feedback')
            )
        )

        row = result.first()

        return {
            "average_rating": round(float(row.avg_rating), 2) if row.avg_rating else 0,
            "average_helpful": round(float(row.avg_helpful), 2) if row.avg_helpful else 0,
            "average_accurate": round(float(row.avg_accurate), 2) if row.avg_accurate else 0,
            "total_feedback": row.total_feedback
        }

    async def get_report_feedback(self, report_id: str):
        """Get feedback for a specific report"""
        result = await self.db.execute(
            select(ReportFeedback)
            .where(ReportFeedback.report_id == report_id)
        )
        return result.scalars().all()
```

**Feedback Endpoint** (`app/api/v1/feedback.py`):
```python
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel, Field

from app.core.database import get_db
from app.services.evaluation.feedback import FeedbackService

router = APIRouter()


class SubmitFeedbackRequest(BaseModel):
    report_id: str
    rating: int = Field(ge=1, le=5)
    helpful: int = Field(ge=1, le=5)
    accurate: int = Field(ge=1, le=5)
    comment: str = None


@router.post("/submit")
async def submit_feedback(
    request: SubmitFeedbackRequest,
    db: AsyncSession = Depends(get_db)
):
    """Submit feedback for a report"""
    service = FeedbackService(db)

    feedback_id = await service.submit_feedback(
        report_id=request.report_id,
        user_id="default",  # TODO: Get from auth
        rating=request.rating,
        helpful=request.helpful,
        accurate=request.accurate,
        comment=request.comment
    )

    return {
        "feedback_id": feedback_id,
        "message": "Feedback submitted successfully"
    }


@router.get("/stats")
async def get_feedback_stats(db: AsyncSession = Depends(get_db)):
    """Get overall feedback statistics"""
    service = FeedbackService(db)
    return await service.get_average_ratings()
```

**Action Items**:
- [ ] Create `ReportFeedback` model
- [ ] Implement `FeedbackService`
- [ ] Create feedback submission endpoint
- [ ] Create feedback stats endpoint
- [ ] Add feedback prompt in UI/responses

---

### Task 3: Accuracy Evaluation

**Goal**: Measure accuracy of LLM-generated insights

**Golden Dataset** (`data/golden/revenue_golden.json`):
```json
{
  "dataset_name": "revenue_sample_golden",
  "description": "Known dataset with expected answers",
  "data_summary": {
    "total_revenue": 50000,
    "transactions": 100,
    "avg_transaction": 500
  },
  "expected_insights": [
    {
      "question": "What is the total revenue?",
      "expected_answer": "The total revenue is $50,000 from 100 transactions, averaging $500 per transaction.",
      "keywords": ["50000", "100 transactions", "500 average"]
    },
    {
      "question": "Is revenue growing?",
      "expected_answer": "Revenue shows steady growth with a 15% increase month-over-month.",
      "keywords": ["growth", "15%", "increase"]
    }
  ]
}
```

**Accuracy Evaluator** (`app/services/evaluation/accuracy.py`):
```python
from typing import List, Dict
import json
from difflib import SequenceMatcher
from openai import AsyncOpenAI
from app.config import get_settings

settings = get_settings()


class AccuracyEvaluator:
    """Evaluate accuracy of generated insights"""

    def __init__(self):
        self.client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY)

    def calculate_similarity(self, text1: str, text2: str) -> float:
        """Calculate similarity between two texts"""
        return SequenceMatcher(None, text1.lower(), text2.lower()).ratio()

    def check_keywords(self, text: str, keywords: List[str]) -> float:
        """Check if keywords are present in text"""
        text_lower = text.lower()
        matches = sum(1 for keyword in keywords if keyword.lower() in text_lower)
        return matches / len(keywords) if keywords else 0

    async def evaluate_with_llm(
        self,
        generated_answer: str,
        expected_answer: str
    ) -> Dict:
        """Use LLM to evaluate quality of answer"""

        prompt = f"""Evaluate how well the generated answer matches the expected answer.

Expected Answer: {expected_answer}

Generated Answer: {generated_answer}

Rate the generated answer on:
1. Factual accuracy (0-10): Does it contain correct information?
2. Completeness (0-10): Does it cover all key points?
3. Clarity (0-10): Is it clear and understandable?

Respond in JSON format:
{{
    "factual_accuracy": <score>,
    "completeness": <score>,
    "clarity": <score>,
    "overall_score": <average>,
    "feedback": "<brief explanation>"
}}"""

        response = await self.client.chat.completions.create(
            model="gpt-4-turbo-preview",
            messages=[{"role": "user", "content": prompt}],
            response_format={"type": "json_object"}
        )

        return json.loads(response.choices[0].message.content)

    async def evaluate_report(
        self,
        generated_narratives: Dict,
        golden_dataset: Dict
    ) -> Dict:
        """Evaluate a report against golden dataset"""

        results = {
            "overall_accuracy": 0,
            "evaluations": []
        }

        expected_insights = golden_dataset.get("expected_insights", [])

        for insight in expected_insights:
            question = insight["question"]
            expected = insight["expected_answer"]
            keywords = insight.get("keywords", [])

            # Find matching narrative section
            # (Simplified - you'd match based on question/section)
            generated = generated_narratives.get("executive_summary", "")

            # Calculate metrics
            similarity = self.calculate_similarity(generated, expected)
            keyword_score = self.check_keywords(generated, keywords)
            llm_eval = await self.evaluate_with_llm(generated, expected)

            evaluation = {
                "question": question,
                "similarity_score": similarity,
                "keyword_score": keyword_score,
                "llm_evaluation": llm_eval,
                "combined_score": (similarity + keyword_score + llm_eval['overall_score'] / 10) / 3
            }

            results["evaluations"].append(evaluation)

        # Calculate overall accuracy
        if results["evaluations"]:
            results["overall_accuracy"] = sum(
                e["combined_score"] for e in results["evaluations"]
            ) / len(results["evaluations"])

        return results
```

**Action Items**:
- [ ] Create golden datasets (at least 3)
- [ ] Implement `AccuracyEvaluator`
- [ ] Run evaluation on test reports
- [ ] Track accuracy metrics over time
- [ ] Create accuracy improvement plan if <90%

---

### Task 4: Analytics Dashboard

**Goal**: Visualize impact metrics

**Analytics Service** (`app/services/evaluation/analytics.py`):
```python
from sqlalchemy.ext.asyncio import AsyncSession
from datetime import datetime, timedelta
from typing import Dict


class AnalyticsService:
    """Generate analytics and impact metrics"""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_impact_metrics(self) -> Dict:
        """Get all impact metrics for dashboard"""

        # Get time savings
        from app.services.evaluation.time_tracker import TimeTracker
        time_tracker = TimeTracker(self.db)
        time_stats = await time_tracker.calculate_time_saved()

        # Get user satisfaction
        from app.services.evaluation.feedback import FeedbackService
        feedback_service = FeedbackService(self.db)
        feedback_stats = await feedback_service.get_average_ratings()

        # Get usage stats
        usage_stats = await self._get_usage_stats()

        return {
            "time_saved": {
                "average_time_saved_minutes": round(time_stats.get("time_saved_minutes", 0), 1),
                "percentage_faster": round(time_stats.get("percentage_saved", 0), 1),
                "manual_avg_minutes": round(time_stats.get("manual_avg_seconds", 0) / 60, 1),
                "echo_avg_minutes": round(time_stats.get("echo_avg_seconds", 0) / 60, 1)
            },
            "user_satisfaction": {
                "average_rating": feedback_stats.get("average_rating", 0),
                "average_helpful": feedback_stats.get("average_helpful", 0),
                "average_accurate": feedback_stats.get("average_accurate", 0),
                "total_responses": feedback_stats.get("total_feedback", 0)
            },
            "usage": usage_stats,
            "summary": self._generate_summary(time_stats, feedback_stats, usage_stats)
        }

    async def _get_usage_stats(self) -> Dict:
        """Get usage statistics"""
        # Query database for usage patterns
        # Return report counts, user counts, etc.
        return {
            "total_reports": 0,
            "total_users": 0,
            "reports_last_week": 0
        }

    def _generate_summary(
        self,
        time_stats: Dict,
        feedback_stats: Dict,
        usage_stats: Dict
    ) -> str:
        """Generate portfolio-ready summary"""

        time_saved_min = round(time_stats.get("time_saved_minutes", 0), 1)
        rating = feedback_stats.get("average_rating", 0)
        total_feedback = feedback_stats.get("total_feedback", 0)

        return f"Echo reduces reporting time from {round(time_stats.get('manual_avg_seconds', 0)/60, 0)} hours to {round(time_stats.get('echo_avg_seconds', 0)/60, 1)} minutes (avg {time_saved_min} min saved per report) with {rating}/5.0 average user satisfaction (n={total_feedback} reports)."
```

**Analytics Endpoint** (`app/api/v1/analytics.py`):
```python
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.services.evaluation.analytics import AnalyticsService

router = APIRouter()


@router.get("/impact")
async def get_impact_metrics(db: AsyncSession = Depends(get_db)):
    """Get impact metrics for portfolio/demo"""
    service = AnalyticsService(db)
    return await service.get_impact_metrics()


@router.get("/health")
async def get_health_metrics(db: AsyncSession = Depends(get_db)):
    """Get system health metrics"""
    # Return system health stats
    pass
```

**Action Items**:
- [ ] Create `AnalyticsService`
- [ ] Implement impact metrics calculation
- [ ] Create analytics endpoint
- [ ] Generate portfolio summary
- [ ] Create simple dashboard (optional)

---

### Task 5: Logging and Telemetry

**Goal**: Comprehensive structured logging

**Logging Configuration** (`app/core/logging.py`):
```python
import structlog
import logging
from app.config import get_settings

settings = get_settings()


def configure_logging():
    """Configure structured logging"""

    logging.basicConfig(
        format="%(message)s",
        level=getattr(logging, settings.LOG_LEVEL),
    )

    structlog.configure(
        processors=[
            structlog.stdlib.filter_by_level,
            structlog.stdlib.add_logger_name,
            structlog.stdlib.add_log_level,
            structlog.stdlib.PositionalArgumentsFormatter(),
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.processors.StackInfoRenderer(),
            structlog.processors.format_exc_info,
            structlog.processors.UnicodeDecoder(),
            structlog.processors.JSONRenderer()
        ],
        context_class=dict,
        logger_factory=structlog.stdlib.LoggerFactory(),
        cache_logger_on_first_use=True,
    )


def get_logger(name: str):
    """Get a structured logger"""
    return structlog.get_logger(name)
```

**Usage in Services**:
```python
from app.core.logging import get_logger

logger = get_logger(__name__)


async def generate_report(...):
    logger.info(
        "report_generation_started",
        report_id=report_id,
        template_type=template_type,
        user_id=user_id
    )

    try:
        # ... generation logic ...

        logger.info(
            "report_generation_completed",
            report_id=report_id,
            duration_seconds=duration,
            metrics_count=len(metrics)
        )
    except Exception as e:
        logger.error(
            "report_generation_failed",
            report_id=report_id,
            error=str(e),
            exc_info=True
        )
        raise
```

**Action Items**:
- [ ] Configure structured logging
- [ ] Add logging to all services
- [ ] Log key events (report generation, errors, etc.)
- [ ] Include context (user_id, request_id, etc.)
- [ ] Test log output format

---

## Acceptance Criteria

### Phase 4 is complete when:

1. **Time Tracking**:
   - [ ] Can track manual vs Echo time
   - [ ] Calculate average time saved
   - [ ] Generate time savings statistics

2. **Feedback**:
   - [ ] Users can rate reports (1-5)
   - [ ] Feedback is stored in database
   - [ ] Can calculate average ratings
   - [ ] Have real feedback data (even if simulated)

3. **Accuracy**:
   - [ ] Golden datasets created
   - [ ] Accuracy evaluation runs successfully
   - [ ] Accuracy >85% on golden datasets

4. **Analytics**:
   - [ ] Impact metrics endpoint works
   - [ ] Can generate portfolio summary
   - [ ] Summary includes specific numbers

5. **Logging**:
   - [ ] Structured logging configured
   - [ ] Key events are logged
   - [ ] Logs include context

6. **Portfolio Ready**:
   - [ ] Can demonstrate "X minutes saved"
   - [ ] Can show "Y/5 user rating"
   - [ ] Have quantifiable metrics

---

## Example Portfolio Metrics

After this phase, you should be able to say:

> "Echo reduced reporting preparation time from **2 hours to 15 minutes** (8x improvement) with an average user satisfaction rating of **4.4/5** (n=27 reports). Generated insights achieved **92% accuracy** compared to expert analysis."

---

## Next Steps

After completing Phase 4, proceed to:
- **Phase 5**: Engineering Excellence

---

*Last Updated: 2025-11-19*
