# Echo - AI Data Scientist for Small Businesses

> Building an AI-powered analytics tool that turns messy business data into clear insights. Because small businesses deserve good data tools too.

**Status**: 🚧 In Development - Phase 0 Complete ✅
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

### ✅ Phase 0 Complete (Foundation)
What's working right now:
- FastAPI backend running in Docker
- PostgreSQL database connected
- Redis cache working
- Health check endpoints live
- DeepSeek API configured and ready
- Testing framework set up

Try it:
```bash
docker-compose up -d
curl http://localhost:8000/api/v1/health
# → {"status":"healthy","service":"echo-api"}
```

### 🎯 Next Up: Phase 1 (Data Ingestion)
What I'm building next (this week):
- CSV/Excel upload endpoints
- Automatic schema detection ("Oh, this column looks like currency")
- Smart data validation with helpful error messages
- Stripe API connector to pull transaction data
- Store everything in PostgreSQL for later analysis

---

## The Plan (5-6 Weeks)

I'm building this in 6 phases:

**Week 1** - Get data in
Upload files, detect schemas, validate quality

**Week 2** - Calculate metrics
MRR, CAC, LTV, conversion rates (the real numbers SMBs care about)

**Week 3-4** - Make it smart
Multi-agent system, LLM-powered insights, natural language Q&A

**Week 5** - Make it production-ready
Tests, CI/CD, monitoring, error handling

**Week 6** - Polish and document
README, architecture diagrams, demo video

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
AI/LLM:      DeepSeek 3.2 Exp
Testing:     pytest, pytest-cov
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

# Access Python shell
docker-compose exec app python

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
│   ├── core/              # Database, cache, config
│   ├── models/            # SQLAlchemy & Pydantic models
│   └── services/          # Business logic
│       ├── llm/           # DeepSeek integration (Phase 3)
│       ├── agents/        # Multi-agent system (Phase 3)
│       └── metrics/       # Analytics engine (Phase 2)
├── tests/                 # Test suite
├── planning/              # Detailed phase docs
├── data/samples/          # Sample datasets
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
Target: 2 hours manual → 15 minutes automated (8x faster)

**User satisfaction**
Target: >4.0/5 rating on generated insights

**Accuracy**
Target: >90% match with expert analysis (using golden datasets)

**Adoption**
Target: Actually usable by non-technical business owners

---

## Current Roadmap

### ✅ Phase 0: Foundation (Complete)
- [x] Docker environment
- [x] FastAPI + PostgreSQL + Redis
- [x] Health checks working
- [x] DeepSeek configured

### 🏗️ Phase 1: Ingestion (In Progress)
- [ ] CSV/Excel upload
- [ ] Schema detection
- [ ] Data validation
- [ ] Stripe connector

### 📋 Phase 2: Analytics (Next)
- [ ] Revenue metrics (MRR, ARR)
- [ ] Financial metrics (CAC, LTV)
- [ ] Marketing metrics (conversion rates)

### 🤖 Phase 3: Intelligence (Upcoming)
- [ ] Report templates
- [ ] Multi-agent orchestration
- [ ] DeepSeek narrative generation
- [ ] Natural language Q&A

See `/planning/` for detailed plans.

---

## Development Log

**2025-11-19** - Phase 0 Complete
Got the entire foundation working. FastAPI running, Docker containers healthy, all health checks passing. DeepSeek API key configured. Ready to build actual features.

Next up: File upload endpoints and schema detection.

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
- See `PHASE_0_COMPLETE.md` for what's done
- Read `WHATS_NEXT.md` for immediate next steps

---

## License

MIT - Build whatever you want with this

---

## Contact

Building in public. Questions? Feedback? Open an issue.

---

*Last updated: 2025-11-19*
*Current phase: Ingestion & Schema Handling*
*LLM: DeepSeek 3.2 Exp*
