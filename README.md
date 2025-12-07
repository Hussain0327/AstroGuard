# Echo

AI-powered analytics for small businesses. Turn messy CSVs into clear insights in minutes, not hours.

![Tests Passing](https://img.shields.io/badge/tests-225%20passing-brightgreen)
![Coverage](https://img.shields.io/badge/coverage-78%25-blue)
![Backend-FastAPI](https://img.shields.io/badge/backend-FastAPI-lightgrey)
![Frontend-Next.js%2015](https://img.shields.io/badge/frontend-Next.js%2015-orange)
![LLM-API](https://img.shields.io/badge/LLM-OpenAI%20compatible-purple)

## What It Does

- Cleans and validates raw business data automatically (dates, currency, booleans, column names)
- Computes 20+ business metrics deterministically (MRR, ARR, CAC, LTV, conversion funnels)
- Generates plain-English reports powered by an LLM that never does the math
- Runs A/B test analysis with two-proportion z-tests, confidence intervals, and power analysis

Everything numeric comes from tested Python code. The LLM only explains and summarizes.

## Why It Exists

Small teams drown in spreadsheets but cannot hire a data scientist. Echo gives them a focused analytics companion in the browser.

The core idea: **deterministic metrics + LLM narrative**.

I do not trust LLMs to do calculations. They are good at explaining patterns and tradeoffs, but not at arithmetic. So:

- All metrics and experiment results are computed in Python with tests.
- The AI only writes the narrative and answers questions about already computed numbers.

## Screenshots

| Upload and Metrics | Chat Interface | Report Templates |
|:------------------:|:--------------:|:----------------:|
| ![Metrics View](docs/screenshots/02-metrics-view.png) | ![Chat](docs/screenshots/03-chat-interface.png) | ![Reports](docs/screenshots/04-reports-page.png) |

---

## Skills Demonstrated

### Data Science and Experimentation

- Designed and implemented a two-proportion z-test engine  
  (conversion rates, lift, p-value, power analysis)
- Built an experimentation API: hypothesis to variants to statistical decision
- Created a portfolio-grade Jupyter notebook for A/B test analysis  
  (`notebooks/funnel_ab_test_analysis.ipynb`)

### Analytics Engineering

- Built a schema detector for mixed-format business CSVs  
  (dates, currency, booleans, URLs, emails)
- Implemented a `DataAutoFixer` that normalizes messy columns before analysis
- Designed a deterministic metrics engine for 20+ business metrics with 225 automated tests

### Backend Engineering

- REST API with FastAPI: ingestion, metrics, chat, reports, analytics, experiments
- PostgreSQL for persistence, Redis for caching
- Telemetry middleware that tracks time spent per analysis and usage patterns
- 78 percent test coverage (pytest and coverage reports)

### Frontend

- Next.js 15 with TypeScript and Tailwind CSS
- File upload with drag-and-drop and real-time metric display
- Data type detection badges, error handling, responsive design

---

## Outcomes

In internal test runs, Echo reduced a typical 2 hour manual spreadsheet workflow to roughly a 15 minute guided flow.

The evaluation layer tracks:

- Baseline vs actual time per analysis session
- Insight accuracy as rated by users
- Satisfaction scores on generated reports

Based on internal test usage (150+ analysis sessions on sample and synthetic datasets):

- **≈1.85 hours saved** per analysis on average  
- **4.3/5 satisfaction** across feedback events  
- **≈94% of insights** marked as accurate by users

These numbers are generated from Echo’s own telemetry and can be recomputed from the logged sessions.

---

## Case Study: Should We Ship The New Onboarding Flow?

**Situation**  
A SaaS company runs an A/B test on their onboarding. Control has 60 percent activation, variant has 80 percent. They want to know if this lift is real or just noise.

**What Echo does**

1. Upload the experiment results CSV.
2. Echo calculates:
   - Conversion rates and relative lift
   - Two-proportion z-test and p-value
   - Confidence interval for the lift
3. Echo produces a plain-English summary:
   - Whether the effect is statistically significant
   - How large the lift is
   - A simple recommendation: ship, hold, or gather more data

For example, a test with 60 percent vs 80 percent activation can yield a relative lift of about 33 percent with a low p-value, leading to a “ship” recommendation.

![Funnel Analysis](docs/screenshots/funnel_analysis.png)

The notebook `notebooks/funnel_ab_test_analysis.ipynb` walks through the full analysis:
funnel visualization, statistical test, confidence intervals, and a basic business impact projection.

---

## Architecture

```text
Frontend     Next.js 15, React, TypeScript, Tailwind
API          FastAPI (Python 3.11), structured routers per domain
Database     PostgreSQL 15 for storage, Redis 7 for caching
LLM          DeepSeek or OpenAI compatible API (explanations only)
Testing      pytest, 225 tests, 78 percent coverage

echo/
├── app/                      # Backend
│   ├── api/v1/               # REST endpoints
│   ├── services/             # Business logic
│   │   ├── metrics/          # Revenue, marketing, financial metrics
│   │   ├── experiments/      # A/B testing and statistics
│   │   ├── llm/              # Conversation and context
│   │   └── reports/          # Report generation
│   └── models/               # Database models
├── frontend/                 # Next.js app
│   ├── app/                  # Pages (home, chat, reports)
│   └── components/           # Reusable UI components
├── notebooks/                # Analysis notebooks
└── tests/                    # Test suite
```

---

## Quickstart

### Prerequisites

* Docker and Docker Compose
* Node.js 18+
* DeepSeek or OpenAI API key

### Run Locally

```bash
# 1. Clone and configure
git clone https://github.com/Hussain0327/Echo_Data_Scientist.git
cd Echo_Data_Scientist
cp .env.example .env
# Set your DEEPSEEK_API_KEY or OPENAI_API_KEY in .env

# 2. Start backend and services
docker-compose up -d

# 3. Start frontend
cd frontend
npm install
npm run dev

# 4. Open http://localhost:3000
# Upload data/samples/revenue_sample.csv to test
```

Backend API docs: `http://localhost:8000/docs`

---

## API Overview

### Metrics

```text
POST /api/v1/metrics/calculate/csv    # Calculate metrics from uploaded file
GET  /api/v1/metrics/available        # List available metrics
```

### Chat

```text
POST /api/v1/chat                     # Send message to Echo
POST /api/v1/chat/with-data           # Chat with file upload
```

### Reports

```text
POST /api/v1/reports/generate         # Generate structured report
GET  /api/v1/reports/templates        # List report templates
```

### Experiments

```text
POST /api/v1/experiments              # Create experiment
POST /api/v1/experiments/{id}/results # Submit variant results
GET  /api/v1/experiments/{id}/summary # Get statistical analysis
```

### Analytics

```text
POST /api/v1/analytics/session/start  # Start tracking session
POST /api/v1/analytics/session/end    # End session, calculate time saved
GET  /api/v1/analytics/portfolio      # Get impact metrics
```

---

## Running Tests

```bash
# Run all tests
docker-compose exec app pytest

# With coverage
docker-compose exec app pytest --cov=app --cov-report=term-missing

# Specific test file
docker-compose exec app pytest tests/services/experiments/test_stats.py -v
```

---

## Development Log

<details>
<summary>Click to expand development history</summary>

### 2025-12-02 - Data Intelligence Layer

Built the `DataAutoFixer` service that cleans messy data before analysis. Handles whitespace, currency symbols, date formats, boolean standardization, and column name normalization. Added smart data type detection so Echo only calculates relevant metrics.

### 2025-11-30 - Experimentation Platform

Added full A/B testing capabilities. Implemented two-proportion z-test, confidence intervals, power analysis, and automatic decision logic. Created 8 new API endpoints and a portfolio Jupyter notebook.

### 2025-11-29 - Frontend Fixes

Fixed Codespaces networking issues by creating an API proxy route. Updated chat endpoint to handle response fields correctly.

### 2025-11-25 - Evaluation System

Built session tracking, time savings calculation, feedback collection, and the portfolio stats endpoint. Added telemetry middleware for automatic request logging.

### 2025-11-25 - Report Generation

Finished report generation system with 3 templates (Revenue Health, Marketing Funnel, Financial Overview). Each report includes executive summary, key findings, detailed analysis, and recommendations.

### 2025-11-24 - Conversational AI

Built the Echo persona as a data consultant that explains metrics in plain English. Added session management and data context injection.

### 2025-11-23 - Analytics Engine

Implemented 20 deterministic business metrics across revenue, financial, and marketing categories. Verified against manual calculations.

### 2025-11-22 - Data Ingestion

Built schema detection, validation engine, and file upload endpoints. Handles CSV and Excel files.

### 2025-11-19 - Foundation

Set up Docker environment, FastAPI, PostgreSQL, Redis, and LLM integration.

</details>

---

## License

MIT License - free for personal and commercial use.

---

## Contact

Questions or feedback? Open an issue or reach out directly.
