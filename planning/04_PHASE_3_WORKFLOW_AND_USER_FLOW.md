# Phase 3: Workflow & User Flow

**Duration**: 7-10 days
**Goal**: Create opinionated, production-ready user workflows with LLM-powered insights

---

## Overview

This phase brings together data ingestion and deterministic metrics with LLM-powered explanations to create a complete user workflow. We'll build report templates, implement multi-agent orchestration, and enable natural language Q&A.

**Key Principle**: Deterministic calculations + LLM narrative = Actionable insights

---

## Objectives

1. Design report template system
2. Implement multi-agent orchestration
3. Build report generation pipeline
4. Create narrative generation with LLMs
5. Implement follow-up Q&A with RAG
6. Add report history and versioning
7. Build complete user workflow

---

## Detailed Tasks

### Task 1: Report Template System

**Goal**: Create predefined report templates for common use cases

**Template Model** (`app/models/report_template.py`):
```python
from sqlalchemy import Column, String, JSON, Enum as SQLEnum
from app.core.database import Base
import enum


class TemplateType(str, enum.Enum):
    REVENUE_HEALTH = "revenue_health"
    MARKETING_FUNNEL = "marketing_funnel"
    FINANCIAL_OVERVIEW = "financial_overview"
    CUSTOM = "custom"


class ReportTemplate(Base):
    __tablename__ = "report_templates"

    id = Column(String, primary_key=True)
    name = Column(String, nullable=False)
    template_type = Column(SQLEnum(TemplateType), nullable=False)
    description = Column(String)
    required_metrics = Column(JSON)  # List of metric names
    required_columns = Column(JSON)  # Expected data columns
    narrative_prompts = Column(JSON)  # LLM prompts for different sections
    configuration = Column(JSON)  # Additional config
```

**Template Definitions** (`app/services/reports/templates.py`):
```python
from typing import Dict, List
from app.models.report_template import TemplateType


REPORT_TEMPLATES: Dict[TemplateType, dict] = {
    TemplateType.REVENUE_HEALTH: {
        "name": "Weekly Revenue Health",
        "description": "Comprehensive revenue snapshot with trends and insights",
        "required_metrics": [
            "total_revenue",
            "revenue_growth_rate",
            "mrr",
            "arr"
        ],
        "required_columns": ["date", "amount"],
        "optional_columns": ["customer_id", "product_id", "status"],
        "narrative_sections": [
            {
                "section": "executive_summary",
                "prompt": "Provide a brief 2-3 sentence executive summary of the revenue performance. Focus on the most important finding.",
                "max_length": 200
            },
            {
                "section": "key_findings",
                "prompt": "List 3-5 key findings from the revenue data. Each finding should be specific and actionable.",
                "format": "bullet_points"
            },
            {
                "section": "trends",
                "prompt": "Analyze revenue trends over time. Identify patterns, anomalies, or concerning changes.",
                "max_length": 300
            },
            {
                "section": "recommendations",
                "prompt": "Provide 2-3 actionable recommendations based on the revenue data.",
                "format": "numbered_list"
            }
        ],
        "visualizations": ["revenue_over_time", "growth_rate_chart"]
    },

    TemplateType.MARKETING_FUNNEL: {
        "name": "Marketing Funnel Performance",
        "description": "Analyze lead generation and conversion efficiency",
        "required_metrics": [
            "conversion_rate",
            "funnel_analysis",
            "channel_performance"
        ],
        "required_columns": ["source", "status"],
        "optional_columns": ["date", "campaign", "spend"],
        "narrative_sections": [
            {
                "section": "funnel_summary",
                "prompt": "Summarize the overall funnel performance. Where are the biggest drop-offs?",
                "max_length": 200
            },
            {
                "section": "channel_insights",
                "prompt": "Compare channel performance. Which channels are most effective and why?",
                "max_length": 250
            },
            {
                "section": "optimization_opportunities",
                "prompt": "Identify 2-3 specific opportunities to improve conversion rates.",
                "format": "bullet_points"
            }
        ],
        "visualizations": ["funnel_chart", "channel_comparison"]
    },

    TemplateType.FINANCIAL_OVERVIEW: {
        "name": "Financial Health Overview",
        "description": "Key financial metrics and unit economics",
        "required_metrics": [
            "cac",
            "ltv",
            "ltv_cac_ratio",
            "total_revenue"
        ],
        "required_columns": ["amount", "customer_id"],
        "optional_columns": ["marketing_spend", "new_customers"],
        "narrative_sections": [
            {
                "section": "financial_health",
                "prompt": "Assess the overall financial health. Is the LTV:CAC ratio healthy? Are there concerns?",
                "max_length": 250
            },
            {
                "section": "unit_economics",
                "prompt": "Explain the unit economics. Are we spending efficiently to acquire customers?",
                "max_length": 200
            },
            {
                "section": "strategic_recommendations",
                "prompt": "Provide strategic recommendations for improving financial performance.",
                "format": "numbered_list"
            }
        ],
        "visualizations": ["ltv_cac_chart", "revenue_breakdown"]
    }
}


def get_template(template_type: TemplateType) -> dict:
    """Get template configuration"""
    return REPORT_TEMPLATES.get(template_type)
```

**Action Items**:
- [ ] Create `ReportTemplate` database model
- [ ] Define template configurations
- [ ] Create template selection endpoint
- [ ] Validate data against template requirements

---

### Task 2: Multi-Agent Orchestration

**Goal**: Coordinate multiple specialized agents for report generation

**Agent Definitions** (`app/services/agents/base_agent.py`):
```python
from abc import ABC, abstractmethod
from typing import Any, Dict
from pydantic import BaseModel


class AgentResult(BaseModel):
    """Result from an agent"""
    agent_name: str
    success: bool
    output: Any
    error: str = None
    metadata: Dict = {}


class BaseAgent(ABC):
    """Base class for all agents"""

    def __init__(self, context: Dict[str, Any]):
        self.context = context

    @abstractmethod
    async def execute(self) -> AgentResult:
        """Execute the agent's task"""
        pass

    @property
    @abstractmethod
    def name(self) -> str:
        """Agent name"""
        pass
```

**Validation Agent** (`app/services/agents/validation_agent.py`):
```python
import pandas as pd
from app.services.agents.base_agent import BaseAgent, AgentResult
from app.services.data_validator import DataValidator


class ValidationAgent(BaseAgent):
    """Agent for data validation"""

    @property
    def name(self) -> str:
        return "validation_agent"

    async def execute(self) -> AgentResult:
        """Validate data quality"""
        df: pd.DataFrame = self.context.get('dataframe')
        template = self.context.get('template')

        if df is None:
            return AgentResult(
                agent_name=self.name,
                success=False,
                error="No dataframe provided"
            )

        # Run validation
        validator = DataValidator(df, use_case=template.get('template_type'))
        errors = validator.validate()

        # Check for critical errors
        critical_errors = [e for e in errors if e.severity == "error"]

        return AgentResult(
            agent_name=self.name,
            success=len(critical_errors) == 0,
            output={
                "validation_errors": errors,
                "is_valid": len(critical_errors) == 0
            },
            metadata={"error_count": len(errors)}
        )
```

**Metrics Agent** (`app/services/agents/metrics_agent.py`):
```python
import pandas as pd
from app.services.agents.base_agent import BaseAgent, AgentResult
from app.services.metrics.registry import create_metrics_engine


class MetricsAgent(BaseAgent):
    """Agent for calculating metrics"""

    @property
    def name(self) -> str:
        return "metrics_agent"

    async def execute(self) -> AgentResult:
        """Calculate required metrics"""
        df: pd.DataFrame = self.context.get('dataframe')
        template = self.context.get('template')

        required_metrics = template.get('required_metrics', [])

        # Create metrics engine
        engine = create_metrics_engine(df)

        # Calculate metrics
        results = {}
        errors = []

        for metric_name in required_metrics:
            try:
                result = engine.calculate_metric(metric_name)
                results[metric_name] = result.dict()
            except Exception as e:
                errors.append(f"Failed to calculate {metric_name}: {str(e)}")

        return AgentResult(
            agent_name=self.name,
            success=len(errors) == 0,
            output=results,
            error="; ".join(errors) if errors else None,
            metadata={"metrics_calculated": len(results)}
        )
```

**Narrative Agent** (`app/services/agents/narrative_agent.py`):
```python
from app.services.agents.base_agent import BaseAgent, AgentResult
from app.services.llm.narrator import Narrator


class NarrativeAgent(BaseAgent):
    """Agent for generating narrative with LLM"""

    @property
    def name(self) -> str:
        return "narrative_agent"

    async def execute(self) -> AgentResult:
        """Generate narrative sections"""
        template = self.context.get('template')
        metrics = self.context.get('metrics', {})

        narrative_sections = template.get('narrative_sections', [])

        narrator = Narrator()
        narratives = {}

        for section_config in narrative_sections:
            section_name = section_config['section']
            prompt = section_config['prompt']

            # Generate narrative
            narrative = await narrator.generate_narrative(
                prompt=prompt,
                metrics=metrics,
                max_length=section_config.get('max_length', 500)
            )

            narratives[section_name] = narrative

        return AgentResult(
            agent_name=self.name,
            success=True,
            output=narratives,
            metadata={"sections_generated": len(narratives)}
        )
```

**Orchestrator** (`app/services/agents/orchestrator.py`):
```python
from typing import List, Dict, Any
from app.services.agents.base_agent import BaseAgent, AgentResult
from app.services.agents.validation_agent import ValidationAgent
from app.services.agents.metrics_agent import MetricsAgent
from app.services.agents.narrative_agent import NarrativeAgent


class ReportOrchestrator:
    """Orchestrates multiple agents to generate a report"""

    def __init__(self, context: Dict[str, Any]):
        self.context = context
        self.results: Dict[str, AgentResult] = {}

    async def execute_pipeline(self) -> Dict[str, Any]:
        """Execute the complete report generation pipeline"""

        # Step 1: Validation
        validation_agent = ValidationAgent(self.context)
        validation_result = await validation_agent.execute()
        self.results['validation'] = validation_result

        if not validation_result.success:
            return {
                "success": False,
                "error": "Data validation failed",
                "details": validation_result.output
            }

        # Step 2: Calculate Metrics
        metrics_agent = MetricsAgent(self.context)
        metrics_result = await metrics_agent.execute()
        self.results['metrics'] = metrics_result

        if not metrics_result.success:
            return {
                "success": False,
                "error": "Metrics calculation failed",
                "details": metrics_result.error
            }

        # Add metrics to context for narrative generation
        self.context['metrics'] = metrics_result.output

        # Step 3: Generate Narrative
        narrative_agent = NarrativeAgent(self.context)
        narrative_result = await narrative_agent.execute()
        self.results['narrative'] = narrative_result

        # Compile final report
        return {
            "success": True,
            "report": {
                "metrics": metrics_result.output,
                "narratives": narrative_result.output,
                "validation": validation_result.output
            },
            "agent_results": {k: v.dict() for k, v in self.results.items()}
        }
```

**Action Items**:
- [ ] Create base agent class
- [ ] Implement validation agent
- [ ] Implement metrics agent
- [ ] Implement narrative agent
- [ ] Create orchestrator
- [ ] Test agent pipeline

---

### Task 3: LLM Narrative Generation

**Goal**: Use LLM to explain metrics and provide insights

**Narrator Service** (`app/services/llm/narrator.py`):
```python
from typing import Dict, Any, List
from openai import AsyncOpenAI
from anthropic import AsyncAnthropic
from app.config import get_settings

settings = get_settings()


class Narrator:
    """Service for generating narratives with LLM"""

    def __init__(self, provider: str = "openai"):
        self.provider = provider

        if provider == "openai":
            self.client = AsyncOpenAI(api_key=settings.OPENAI_API_KEY)
            self.model = "gpt-4-turbo-preview"
        elif provider == "anthropic":
            self.client = AsyncAnthropic(api_key=settings.ANTHROPIC_API_KEY)
            self.model = "claude-3-sonnet-20240229"

    async def generate_narrative(
        self,
        prompt: str,
        metrics: Dict[str, Any],
        max_length: int = 500
    ) -> str:
        """Generate narrative based on metrics"""

        # Format metrics for context
        metrics_context = self._format_metrics(metrics)

        # Build system prompt
        system_prompt = """You are an expert business analyst helping small business owners understand their data.

Your role is to:
1. Explain metrics in simple, non-technical language
2. Identify trends and patterns
3. Provide actionable insights
4. Be concise and direct
5. Focus on "so what?" - why does this matter?

DO NOT:
- Use technical jargon
- Make up numbers or calculations (only use provided metrics)
- Be vague or generic
- Provide lengthy explanations"""

        # Build user prompt
        user_prompt = f"""Based on these metrics:

{metrics_context}

{prompt}

Keep your response under {max_length} characters and focus on actionable insights."""

        # Generate with LLM
        if self.provider == "openai":
            response = await self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_prompt}
                ],
                max_tokens=max_length // 2,
                temperature=0.7
            )
            return response.choices[0].message.content

        elif self.provider == "anthropic":
            response = await self.client.messages.create(
                model=self.model,
                max_tokens=max_length // 2,
                system=system_prompt,
                messages=[
                    {"role": "user", "content": user_prompt}
                ]
            )
            return response.content[0].text

    def _format_metrics(self, metrics: Dict[str, Any]) -> str:
        """Format metrics for LLM context"""
        formatted = []
        for metric_name, metric_data in metrics.items():
            if isinstance(metric_data, dict):
                value = metric_data.get('value', 'N/A')
                unit = metric_data.get('unit', '')
                formatted.append(f"- {metric_name}: {value}{unit}")

                # Add metadata if available
                if 'metadata' in metric_data:
                    for key, val in metric_data['metadata'].items():
                        formatted.append(f"  - {key}: {val}")
        return "\n".join(formatted)

    async def answer_question(
        self,
        question: str,
        report_context: Dict[str, Any],
        conversation_history: List[Dict] = None
    ) -> str:
        """Answer follow-up questions about a report"""

        system_prompt = """You are a data analyst assistant helping users understand their business reports.

Answer questions based on the provided report data. Be concise and specific. If you don't have the information to answer, say so clearly."""

        # Format report context
        context = f"""Report Data:
Metrics: {self._format_metrics(report_context.get('metrics', {}))}

Previous Insights: {report_context.get('narratives', {}).get('executive_summary', '')}
"""

        messages = [{"role": "system", "content": system_prompt}]

        # Add conversation history if available
        if conversation_history:
            messages.extend(conversation_history)

        messages.append({
            "role": "user",
            "content": f"{context}\n\nQuestion: {question}"
        })

        if self.provider == "openai":
            response = await self.client.chat.completions.create(
                model=self.model,
                messages=messages,
                max_tokens=500,
                temperature=0.7
            )
            return response.choices[0].message.content

        elif self.provider == "anthropic":
            # Convert messages for Anthropic format
            anthropic_messages = [
                msg for msg in messages if msg["role"] != "system"
            ]
            response = await self.client.messages.create(
                model=self.model,
                max_tokens=500,
                system=system_prompt,
                messages=anthropic_messages
            )
            return response.content[0].text
```

**Action Items**:
- [ ] Create `Narrator` service
- [ ] Implement narrative generation
- [ ] Implement Q&A functionality
- [ ] Test with different metrics
- [ ] Optimize prompts for quality

---

### Task 4: Report Generation Endpoint

**Goal**: Complete report generation workflow

**Report Model** (`app/models/report.py`):
```python
from sqlalchemy import Column, String, DateTime, JSON, ForeignKey
from sqlalchemy.sql import func
from app.core.database import Base


class Report(Base):
    __tablename__ = "reports"

    id = Column(String, primary_key=True)
    user_id = Column(String, nullable=False)
    data_source_id = Column(String, ForeignKey('data_sources.id'))
    template_type = Column(String, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    metrics = Column(JSON)  # Calculated metrics
    narratives = Column(JSON)  # Generated narratives
    metadata = Column(JSON)  # Additional info
```

**Report Endpoint** (`app/api/v1/reports.py`):
```python
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel
import uuid
import pandas as pd

from app.core.database import get_db
from app.services.agents.orchestrator import ReportOrchestrator
from app.services.reports.templates import get_template, TemplateType
from app.models.report import Report

router = APIRouter()


class GenerateReportRequest(BaseModel):
    data_source_id: str
    template_type: TemplateType


class GenerateReportResponse(BaseModel):
    report_id: str
    status: str
    metrics: dict
    narratives: dict


@router.post("/generate", response_model=GenerateReportResponse)
async def generate_report(
    request: GenerateReportRequest,
    db: AsyncSession = Depends(get_db)
):
    """Generate a report from a data source"""

    # Get template
    template = get_template(request.template_type)
    if not template:
        raise HTTPException(status_code=400, detail="Invalid template type")

    # Load data (simplified - you'd load actual data)
    # df = load_dataframe(request.data_source_id)
    df = pd.DataFrame()  # Placeholder

    # Create context for orchestrator
    context = {
        'dataframe': df,
        'template': template,
        'data_source_id': request.data_source_id
    }

    # Execute orchestration
    orchestrator = ReportOrchestrator(context)
    result = await orchestrator.execute_pipeline()

    if not result['success']:
        raise HTTPException(
            status_code=400,
            detail=f"Report generation failed: {result.get('error')}"
        )

    # Save report
    report_id = str(uuid.uuid4())
    report = Report(
        id=report_id,
        user_id="default",  # TODO: Get from auth
        data_source_id=request.data_source_id,
        template_type=request.template_type.value,
        metrics=result['report']['metrics'],
        narratives=result['report']['narratives']
    )

    db.add(report)
    await db.commit()

    return GenerateReportResponse(
        report_id=report_id,
        status="success",
        metrics=result['report']['metrics'],
        narratives=result['report']['narratives']
    )


@router.get("/{report_id}")
async def get_report(
    report_id: str,
    db: AsyncSession = Depends(get_db)
):
    """Get a previously generated report"""
    # Implementation
    pass


@router.post("/{report_id}/ask")
async def ask_question(
    report_id: str,
    question: str,
    db: AsyncSession = Depends(get_db)
):
    """Ask a follow-up question about a report"""
    # Get report from database
    # Use Narrator to answer question
    # Return answer
    pass
```

**Action Items**:
- [ ] Create `Report` database model
- [ ] Implement report generation endpoint
- [ ] Implement report retrieval endpoint
- [ ] Implement Q&A endpoint
- [ ] Add error handling

---

## Acceptance Criteria

### Phase 3 is complete when:

1. **Templates**:
   - [ ] At least 2 report templates defined
   - [ ] Templates specify required metrics and columns
   - [ ] Templates include narrative prompts

2. **Orchestration**:
   - [ ] Multi-agent pipeline works end-to-end
   - [ ] Validation runs before metrics
   - [ ] Metrics feed into narrative generation
   - [ ] Pipeline handles errors gracefully

3. **Narrative**:
   - [ ] LLM generates clear, actionable insights
   - [ ] Narratives are based on actual metrics
   - [ ] No hallucinated numbers
   - [ ] Language is simple and non-technical

4. **Workflow**:
   - [ ] User can select template
   - [ ] User can upload/select data source
   - [ ] Report generates within reasonable time (<30s)
   - [ ] Report includes metrics + narrative
   - [ ] User can ask follow-up questions

5. **Quality**:
   - [ ] Reports are consistent and reliable
   - [ ] Insights are relevant and actionable
   - [ ] Follow-up Q&A works correctly

---

## Next Steps

After completing Phase 3, proceed to:
- **Phase 4**: Evaluation & Metrics

---

*Last Updated: 2025-11-19*
