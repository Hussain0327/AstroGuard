# Echo - AI Data Scientist for Small Businesses

> Building an AI-powered analytics tool that turns messy business data into clear insights. Because small businesses deserve good data tools too.

**Status**: In Development - Phase 3 Complete (Reports), Phase 4 Next (Evaluation)
**Powered by**: DeepSeek 3.2, FastAPI, PostgreSQL, Redis
**Goal**: Transform 2-hour manual reports into 15-minute automated insights

---

## What I'm Building

Most small businesses drown in spreadsheets but can't afford a full-time data analyst. Echo is my solution to that problem.

**The core idea**:
- Upload your business data (Stripe exports, HubSpot CSVs, whatever you've got)
- Get accurate metrics calculated automatically (no LLM hallucinations on the math)
- Receive plain-English explanations powered by AI
- Ask follow-up questions in natural language

**Why "deterministic metrics + LLM narrative"?**
I don't trust LLMs to do calculations. They're great at explaining things, terrible at math. So I'm building it the right way:
- Calculate metrics using SQL/Python (accurate, testable)
- Use LLM (DeepSeek) only for explanations and insights
- No made-up numbers, just facts with context

---

## Current Status

### Phase 3 Complete (Conversational AI + Reports)
Built "Echo" - a conversational data consultant that generates structured business reports. Upload a CSV, get professional analysis with metrics and narratives.

**What's working now:**
- Conversational chat interface with DeepSeek
- Session management (maintains context across messages)
- Structured report generation (3 templates: Revenue, Marketing, Financial)
- Automatic metrics calculation + AI-generated narratives
- Report storage and retrieval in PostgreSQL
- McKinsey-style persona - direct, insightful, no jargon
- Guardrails to stay on topic and never make up numbers

Try the chat interface:
```bash
# Start the services
docker-compose up -d

# Chat with Echo
curl -X POST "http://localhost:8000/api/v1/chat" \
  -H "Content-Type: application/json" \
  -d '{"message": "Hi!"}'

# Chat with your data
curl -X POST "http://localhost:8000/api/v1/chat/with-data" \
  -F "message=How's my revenue looking?" \
  -F "file=@data/samples/revenue_sample.csv"
```

Try the report generation:
```bash
# Generate a revenue health report
curl -X POST "http://localhost:8000/api/v1/reports/generate?template_type=revenue_health" \
  -F "file=@data/samples/revenue_sample.csv"

# Generate a marketing funnel report
curl -X POST "http://localhost:8000/api/v1/reports/generate?template_type=marketing_funnel" \
  -F "file=@data/samples/marketing_sample.csv"

# List available templates
curl http://localhost:8000/api/v1/reports/templates

# List your reports
curl http://localhost:8000/api/v1/reports

# Get a specific report
curl http://localhost:8000/api/v1/reports/{report_id}
```

Each report includes:
- Executive summary (2-3 sentence overview)
- Key findings (3-5 data-driven insights)
- Detailed analysis (patterns, trends, anomalies)
- Recommendations (2-4 specific, actionable next steps)

The reports are stored in PostgreSQL, so you can retrieve them later or compare across time periods.

### Phase 2 Complete (Deterministic Analytics)
The metrics engine is done. 20 business metrics, all deterministic math, no AI hallucinations.

**What's working:**
- 7 revenue metrics (Total Revenue, MRR, ARR, Growth Rate, AOV, Revenue by Period/Product)
- 6 financial metrics (CAC, LTV, LTV:CAC Ratio, Gross Margin, Burn Rate, Runway)
- 7 marketing metrics (Conversion Rate, Channel/Campaign Performance, CPL, ROAS, Lead Velocity, Funnel)
- Time-series analysis (trends, growth, period comparisons)
- 184 tests passing, 83% coverage

```bash
# Calculate revenue metrics from a CSV
curl -X POST "http://localhost:8000/api/v1/metrics/calculate/revenue" \
  -F "file=@data/samples/revenue_sample.csv"
```

All numbers verified against manual calculations. Pure pandas math, no AI involved.

---

## API Endpoints

### Reports (Phase 3) - Structured Business Reports
```
GET  /api/v1/reports/templates            List available report templates
GET  /api/v1/reports/templates/{type}     Get template details
POST /api/v1/reports/generate             Generate report from CSV + template
GET  /api/v1/reports                      List user's reports
GET  /api/v1/reports/{id}                 Get specific report
DELETE /api/v1/reports/{id}               Delete report
```

### Chat (Phase 3) - Talk to Echo
```
POST /api/v1/chat                    Send a message to Echo
POST /api/v1/chat/with-data          Chat + upload data in one call
POST /api/v1/chat/load-data          Load data into existing session
GET  /api/v1/chat/history/{id}       Get conversation history
DELETE /api/v1/chat/session/{id}     Clear a session
GET  /api/v1/chat/sessions           List all active sessions
```

### Metrics (Phase 2) - Deterministic Calculations
```
GET  /api/v1/metrics/available           List all available metrics
POST /api/v1/metrics/calculate/csv       Calculate any metrics from CSV
POST /api/v1/metrics/calculate/revenue   Revenue metrics only
POST /api/v1/metrics/calculate/marketing Marketing metrics only
POST /api/v1/metrics/trend               Trend analysis on a column
POST /api/v1/metrics/growth              Growth analysis over time
```

### Ingestion (Phase 1) - Data Upload
```
POST /api/v1/ingestion/upload/csv     Upload CSV file
POST /api/v1/ingestion/upload/excel   Upload Excel file
GET  /api/v1/ingestion/sources        List all uploaded sources
GET  /api/v1/ingestion/sources/{id}   Get source by ID
```

### Health
```
GET  /                        Service info
GET  /api/v1/health           Basic health check
GET  /api/v1/health/db        Database health
GET  /api/v1/health/redis     Redis health
```

### API Documentation
```
GET  /docs                    Swagger UI
GET  /redoc                   ReDoc
```

---

## The Plan (5-6 Weeks)

I'm building this in 6 phases:

**Phase 0** - Foundation (Complete)
Docker environment, FastAPI + PostgreSQL + Redis, health checks

**Phase 1** - Data Ingestion (Complete)
File upload, schema detection, data validation, storage

**Phase 2** - Analytics Engine (Complete)
20 metrics: MRR, ARR, CAC, LTV, conversion rates, channel performance, funnel analysis

**Phase 3** - Intelligence (Next)
LLM-powered insights, natural language Q&A

**Phase 4** - Evaluation
Time tracking, accuracy metrics, user feedback

**Phase 5** - Production Ready
Tests, CI/CD, monitoring, error handling

**Phase 6** - Polish
Documentation, demos, portfolio presentation

Full roadmap: See `/planning/` folder

---

## Tech Stack

**Why I chose these tools:**

- **FastAPI** - Fast, modern, auto-generates docs
- **PostgreSQL** - Reliable, handles complex queries
- **Redis** - Cache repeated calculations
- **DeepSeek** - Affordable, powerful LLM (OpenAI-compatible API)
- **Docker** - Consistent dev environment
- **Pandas** - Data processing workhorse

**Full stack:**
```
Backend:     FastAPI, Python 3.11
Database:    PostgreSQL 15 (async)
Cache:       Redis 7
AI/LLM:      DeepSeek 3.2
Testing:     pytest, pytest-cov (83% coverage)
Monitoring:  structlog, Prometheus
DevOps:      Docker, GitHub Actions
```

---

## How to Run This

### Prerequisites
- Docker & Docker Compose
- DeepSeek API key (or OpenAI key)



### Development Commands
```bash
# View logs
docker-compose logs app -f

# Run tests
docker-compose exec app pytest

# Run tests with coverage
docker-compose exec app pytest --cov=app

# Restart after code changes
docker-compose restart app

# Stop everything
docker-compose down
```

---

## Project Structure

```
Echo/
├── app/                    # Main application
│   ├── api/v1/            # API endpoints
│   │   ├── health.py      # Health checks
│   │   ├── ingestion.py   # File upload endpoints
│   │   ├── metrics.py     # Metrics calculation endpoints
│   │   ├── chat.py        # Conversational AI endpoints (Phase 3)
│   │   └── reports.py     # Report generation endpoints (Phase 3)
│   ├── core/              # Database, cache, config
│   ├── models/            # SQLAlchemy & Pydantic models
│   │   ├── data_source.py # Upload tracking model
│   │   ├── report.py      # Report storage model
│   │   └── schemas.py     # API schemas
│   └── services/          # Business logic
│       ├── schema_detector.py   # Auto-detect column types
│       ├── data_validator.py    # Validation engine
│       ├── ingestion.py         # Upload orchestration
│       ├── metrics/             # Deterministic analytics (Phase 2)
│       │   ├── base.py          # BaseMetric, MetricResult
│       │   ├── engine.py        # MetricsEngine orchestrator
│       │   ├── registry.py      # Metric discovery
│       │   ├── revenue.py       # 7 revenue metrics
│       │   ├── financial.py     # 6 financial metrics
│       │   ├── marketing.py     # 7 marketing metrics
│       │   └── timeseries.py    # Time-series utilities
│       ├── llm/                 # Conversational AI (Phase 3)
│       │   ├── conversation.py  # Chat service, session management
│       │   ├── context_builder.py # Formats data/metrics for LLM
│       │   └── prompts/
│       │       └── consultant.py # Echo's persona and guardrails
│       └── reports/             # Report generation (Phase 3)
│           ├── templates.py     # Report templates (Revenue, Marketing, Financial)
│           └── generator.py     # Report generation service
├── tests/                 # Test suite (184 tests)
│   ├── api/              # API tests
│   └── services/         # Service tests
│       ├── metrics/      # Metrics tests (75 tests)
│       ├── llm/          # Conversation tests (31 tests)
│       └── reports/      # Report tests (16 tests)
├── planning/              # Detailed phase docs
├── data/samples/          # Sample datasets
│   ├── revenue_sample.csv
│   ├── marketing_sample.csv
│   └── bad_data_sample.csv
├── docker-compose.yml     # Services orchestration
└── requirements.txt       # Python dependencies
```

---

## What Makes This Different

**Not another analytics dashboard**
This isn't trying to be Tableau. It's focused on answering specific questions SMB owners actually ask:
- "How much did we make this month?"
- "Which marketing channel is working?"
- "Are we spending too much to acquire customers?"

**Deterministic + AI hybrid**
Most "AI analytics" tools just throw everything at an LLM and hope. I'm being deliberate:
- Hard calculations in code (testable, accurate)
- LLM for explanation (context, recommendations)
- Best of both worlds

**Built for real businesses**
Every feature is designed around actual SMB needs:
- Works with messy data (helpful error messages)
- Connects to tools they already use (Stripe, HubSpot)
- Plain English, no jargon

---

## Metrics I'm Tracking

To prove this actually works, I'm measuring:

**Time saved**
Target: 2 hours manual -> 15 minutes automated (8x faster)

**User satisfaction**
Target: >4.0/5 rating on generated insights

**Accuracy**
Target: >90% match with expert analysis (using golden datasets)

**Code Quality**
Current: 83% test coverage, 184 passing tests

---

## Current Roadmap

### Phase 0: Foundation (Complete)
- [x] Docker environment
- [x] FastAPI + PostgreSQL + Redis
- [x] Health checks working
- [x] DeepSeek configured

### Phase 1: Ingestion (Complete)
- [x] CSV/Excel upload
- [x] Schema detection (date, currency, email, URL, boolean)
- [x] Data validation with helpful messages
- [x] Store uploads in PostgreSQL

### Phase 2: Analytics (Complete)
- [x] Revenue metrics (Total, MRR, ARR, Growth, AOV, by Period, by Product)
- [x] Financial metrics (CAC, LTV, LTV:CAC, Gross Margin, Burn Rate, Runway)
- [x] Marketing metrics (Conversion, Channel, Campaign, CPL, ROAS, Velocity, Funnel)
- [x] Time-series utilities (trends, growth, comparisons)
- [x] Metrics API endpoints

### Phase 3: Intelligence (Complete)
- [x] Conversational chat interface with DeepSeek
- [x] Echo persona (McKinsey-style data consultant)
- [x] Session management and conversation history
- [x] Data context injection (metrics auto-calculated)
- [x] Guardrails (stays on topic, never fabricates numbers)
- [x] Report templates (Revenue Health, Marketing Funnel, Financial Overview)
- [x] Structured report generation (metrics + AI narratives)
- [x] Report storage and retrieval in PostgreSQL
- [x] 16 new tests for reports, 87% coverage on generator

### Phase 4-6: Polish and Production
- [ ] Evaluation metrics and accuracy tracking
- [ ] CI/CD pipeline
- [ ] Documentation and demos

See `/planning/` for detailed plans.

---

## Development Log

**2025-11-25** - Phase 3 Complete: Report Generation
Finished the report generation system. You can now upload a CSV and get a professional business report with metrics and AI-generated narratives.

What I built:
- Report database model with versioning and status tracking
- 3 report templates: Revenue Health, Marketing Funnel, Financial Overview
- Report generator service that calculates metrics + generates narratives
- 5 new API endpoints for report templates, generation, listing, retrieval, deletion
- 16 new tests, all passing, 87% coverage on report generator

Each template defines required metrics, required columns, and sections (executive summary, key findings, detailed analysis, recommendations). The generator validates data, calculates all metrics deterministically, then uses DeepSeek to generate natural language narratives for each section. Reports are stored in PostgreSQL with full metadata.

Tested it live:
- Generated revenue report: correctly identified -64% MoM decline, concentration risk in Enterprise product
- Generated marketing report: calculated 10.21% conversion rate, identified Email as best cost-per-conversion at $1.74
- Both reports stored and retrievable via API

Files created: 1 model, 3 services, 1 API endpoint, 3 test files
Files modified: 3 (imports and router registration)

Phase 3 is done. Next up: Phase 4 (evaluation metrics, accuracy tracking).

**2025-11-24** - Phase 3 Started: Conversational AI
Built "Echo" - the conversational data consultant interface:
- Created the McKinsey-style persona with guardrails
- Built conversation service with DeepSeek integration
- Added session management (tracks conversation history per user)
- Built data context builder that formats metrics for the LLM
- Created 6 new chat API endpoints
- 31 new tests, conversation service at 99% coverage

The idea is simple: you already have accurate metrics from Phase 2, now Echo explains them in plain English. Upload your data, ask questions, get insights. Echo never makes up numbers - it only uses the deterministic metrics we already calculated.

Key design decisions:
- LLM never does math, only explains
- Sessions maintain context across messages
- Auto-calculates all available metrics when you load data
- Politely redirects off-topic questions back to business analytics

Files created: conversation.py, context_builder.py, consultant.py (persona), chat.py (API)

**2025-11-23** - Phase 2 Complete
Built the entire deterministic analytics layer:
- 20 business metrics across revenue, financial, and marketing categories
- Time-series analysis with trend detection and growth calculations
- 6 new API endpoints for metric calculation
- All metrics verified against manual calculations - pure pandas math, no AI
- 124 tests passing with 88% coverage

Key metrics working:
- Revenue: $190,100.50 total from sample data (verified)
- Marketing: 10.21% conversion rate across 17,254 leads (verified)
- Channel analysis: Email cheapest at $1.74/conversion, LinkedIn best rate at 17.45%

Files created: 8 new service files, 5 test files, 1 API endpoint file
Ready for Phase 3: LLM narrative generation

**2025-11-22** - Phase 1 Complete
Built the entire data ingestion layer:
- Schema detector that auto-identifies column types (date, currency, email, URL, boolean)
- Validation engine with helpful error messages
- CSV and Excel upload endpoints
- All metadata stored in PostgreSQL
- 39 tests passing with 88% coverage

Files created: 12 new files, 7 modified
Ready for Phase 2: Analytics Engine

**2025-11-19** - Phase 0 Complete
Got the entire foundation working. FastAPI running, Docker containers healthy, all health checks passing. DeepSeek API key configured.

---

## Why I'm Building This

Small businesses are the backbone of the economy, but they're stuck with either:
1. Manual spreadsheet hell (hours of work, error-prone)
2. Enterprise tools they can't afford ($500+/month, too complex)

There's a gap for something simple, affordable, and actually useful. That's what Echo is.

Plus, this is a great way to showcase:
- Data engineering (pipelines, validation, ETL)
- Backend development (APIs, databases, caching)
- AI/ML application (practical LLM use, not just prompting)
- Product thinking (real user needs, measurable value)

---

## Want to Follow Along?

- Check `/planning/` for detailed phase documentation
- See `PHASE_2_COMPLETE.md` for the latest completed work
- Read `WHATS_NEXT.md` for immediate next steps

---

## License

MIT - Build whatever you want with this

---

## Contact

Building in public. Questions? Feedback? Open an issue.

---

*Last updated: 2025-11-25*
*Current phase: Phase 3 Complete - Moving to Phase 4 (Evaluation)*
*LLM: DeepSeek 3.2*
