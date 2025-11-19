# Phase 0: Project Setup & Foundation

**Duration**: 3-5 days
**Goal**: Establish clean project structure and development environment

---

## Overview

This phase focuses on setting up a solid foundation for the Echo project. We'll establish the project structure, configure the development environment, set up core infrastructure (database, cache), and create a basic FastAPI skeleton.

---

## Objectives

1. Create proper project structure following Python best practices
2. Set up Docker development environment
3. Configure Supabase (PostgreSQL) database
4. Configure Redis cache
5. Create basic FastAPI application with health endpoints
6. Set up environment configuration
7. Establish dependency management

---

## Detailed Tasks

### Task 1: Project Structure Setup

**Goal**: Organize codebase for scalability and maintainability

**Directory Structure**:
```
echo/
├── .github/
│   └── workflows/          # CI/CD pipelines (later phase)
├── app/
│   ├── __init__.py
│   ├── main.py            # FastAPI app entry point
│   ├── config.py          # Configuration management
│   ├── dependencies.py    # Dependency injection
│   ├── api/
│   │   ├── __init__.py
│   │   ├── v1/
│   │   │   ├── __init__.py
│   │   │   ├── health.py  # Health check endpoints
│   │   │   └── router.py  # Main API router
│   ├── core/
│   │   ├── __init__.py
│   │   ├── database.py    # Database connection
│   │   ├── cache.py       # Redis connection
│   │   ├── logging.py     # Logging configuration
│   │   └── exceptions.py  # Custom exceptions
│   ├── models/
│   │   ├── __init__.py
│   │   └── schemas.py     # Pydantic models
│   ├── services/
│   │   ├── __init__.py
│   │   └── # Business logic (future phases)
│   └── utils/
│       ├── __init__.py
│       └── # Utility functions
├── tests/
│   ├── __init__.py
│   ├── conftest.py        # Pytest fixtures
│   └── api/
│       └── test_health.py
├── data/
│   └── samples/           # Sample datasets
├── planning/              # This folder
├── .env.example           # Environment variables template
├── .env                   # Environment variables (gitignored)
├── .gitignore
├── docker-compose.yml
├── Dockerfile
├── requirements.txt
├── requirements-dev.txt
├── pyproject.toml         # Project metadata
├── pytest.ini
└── README.md
```

**Action Items**:
- [ ] Create directory structure above
- [ ] Initialize Python package in `app/`
- [ ] Create `__init__.py` files in all packages
- [ ] Set up `.gitignore` for Python, Docker, env files

---

### Task 2: Environment Configuration

**Goal**: Manage configuration across environments (dev, prod)

**Files to Create**:

**`.env.example`**:
```bash
# Application
APP_NAME=Echo
ENVIRONMENT=development
DEBUG=True
LOG_LEVEL=INFO

# API
API_V1_PREFIX=/api/v1
HOST=0.0.0.0
PORT=8000

# Database (Supabase)
DATABASE_URL=postgresql://user:password@localhost:5432/echo_db
DB_POOL_SIZE=10
DB_MAX_OVERFLOW=20

# Redis
REDIS_URL=redis://localhost:6379/0
REDIS_PASSWORD=

# LLM API Keys
OPENAI_API_KEY=your_openai_key_here
# ANTHROPIC_API_KEY=your_anthropic_key_here

# Security
SECRET_KEY=your-secret-key-here-change-in-production
ACCESS_TOKEN_EXPIRE_MINUTES=30

# CORS
CORS_ORIGINS=http://localhost:3000,http://localhost:8000
```

**`app/config.py`**:
```python
from pydantic_settings import BaseSettings
from functools import lru_cache
from typing import List


class Settings(BaseSettings):
    # Application
    APP_NAME: str = "Echo"
    ENVIRONMENT: str = "development"
    DEBUG: bool = True
    LOG_LEVEL: str = "INFO"

    # API
    API_V1_PREFIX: str = "/api/v1"
    HOST: str = "0.0.0.0"
    PORT: int = 8000

    # Database
    DATABASE_URL: str
    DB_POOL_SIZE: int = 10
    DB_MAX_OVERFLOW: int = 20

    # Redis
    REDIS_URL: str
    REDIS_PASSWORD: str = ""

    # LLM
    OPENAI_API_KEY: str = ""
    ANTHROPIC_API_KEY: str = ""

    # Security
    SECRET_KEY: str
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30

    # CORS
    CORS_ORIGINS: List[str] = []

    class Config:
        env_file = ".env"
        case_sensitive = True


@lru_cache()
def get_settings() -> Settings:
    return Settings()
```

**Action Items**:
- [ ] Create `.env.example`
- [ ] Create `.env` (copy from example)
- [ ] Implement `app/config.py`
- [ ] Add `.env` to `.gitignore`

---

### Task 3: Docker Setup

**Goal**: Containerize application for consistent development

**`Dockerfile`**:
```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY requirements.txt requirements-dev.txt ./

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt
RUN pip install --no-cache-dir -r requirements-dev.txt

# Copy application
COPY . .

# Expose port
EXPOSE 8000

# Run application
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
```

**`docker-compose.yml`**:
```yaml
version: '3.8'

services:
  app:
    build: .
    ports:
      - "8000:8000"
    volumes:
      - .:/app
    env_file:
      - .env
    depends_on:
      - db
      - redis
    command: uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

  db:
    image: postgres:15-alpine
    environment:
      POSTGRES_USER: echo_user
      POSTGRES_PASSWORD: echo_password
      POSTGRES_DB: echo_db
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

volumes:
  postgres_data:
  redis_data:
```

**Action Items**:
- [ ] Create `Dockerfile`
- [ ] Create `docker-compose.yml`
- [ ] Test Docker build: `docker-compose build`
- [ ] Test Docker run: `docker-compose up`

---

### Task 4: Dependencies Management

**Goal**: Define and manage project dependencies

**`requirements.txt`** (Core dependencies):
```
# Web Framework
fastapi==0.104.1
uvicorn[standard]==0.24.0
pydantic==2.5.0
pydantic-settings==2.1.0

# Database
asyncpg==0.29.0
sqlalchemy==2.0.23
alembic==1.12.1

# Supabase
supabase==2.3.0

# Redis
redis==5.0.1
hiredis==2.2.3

# LLM
openai==1.3.7
anthropic==0.7.7

# Data Processing
pandas==2.1.3
numpy==1.26.2

# Utilities
python-dotenv==1.0.0
python-multipart==0.0.6
httpx==0.25.2
```

**`requirements-dev.txt`** (Development dependencies):
```
# Testing
pytest==7.4.3
pytest-asyncio==0.21.1
pytest-cov==4.1.0
pytest-mock==3.12.0

# Code Quality
black==23.11.0
flake8==6.1.0
isort==5.12.0
mypy==1.7.1

# Documentation
mkdocs==1.5.3
mkdocs-material==9.4.14
```

**Action Items**:
- [ ] Create `requirements.txt`
- [ ] Create `requirements-dev.txt`
- [ ] Install dependencies: `pip install -r requirements.txt -r requirements-dev.txt`

---

### Task 5: Database Setup (Supabase)

**Goal**: Configure PostgreSQL database connection

**`app/core/database.py`**:
```python
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker, declarative_base
from app.config import get_settings

settings = get_settings()

# Create async engine
engine = create_async_engine(
    settings.DATABASE_URL,
    echo=settings.DEBUG,
    pool_size=settings.DB_POOL_SIZE,
    max_overflow=settings.DB_MAX_OVERFLOW,
)

# Create session factory
async_session_maker = sessionmaker(
    engine, class_=AsyncSession, expire_on_commit=False
)

# Base class for models
Base = declarative_base()


async def get_db() -> AsyncSession:
    """Dependency for getting async database session"""
    async with async_session_maker() as session:
        try:
            yield session
        finally:
            await session.close()


async def init_db():
    """Initialize database (create tables)"""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
```

**Action Items**:
- [ ] Create `app/core/database.py`
- [ ] Set up Supabase account (or use local PostgreSQL)
- [ ] Update `DATABASE_URL` in `.env`
- [ ] Test connection

---

### Task 6: Redis Cache Setup

**Goal**: Configure Redis for caching and session management

**`app/core/cache.py`**:
```python
from redis import asyncio as aioredis
from app.config import get_settings
from typing import Optional

settings = get_settings()

redis_client: Optional[aioredis.Redis] = None


async def get_redis() -> aioredis.Redis:
    """Get Redis client"""
    global redis_client
    if redis_client is None:
        redis_client = await aioredis.from_url(
            settings.REDIS_URL,
            password=settings.REDIS_PASSWORD if settings.REDIS_PASSWORD else None,
            encoding="utf-8",
            decode_responses=True,
        )
    return redis_client


async def close_redis():
    """Close Redis connection"""
    global redis_client
    if redis_client:
        await redis_client.close()
```

**Action Items**:
- [ ] Create `app/core/cache.py`
- [ ] Update `REDIS_URL` in `.env`
- [ ] Test Redis connection

---

### Task 7: FastAPI Application Setup

**Goal**: Create basic FastAPI app with health endpoints

**`app/main.py`**:
```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from app.config import get_settings
from app.api.v1.router import api_router
from app.core.database import init_db
from app.core.cache import close_redis

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    await init_db()
    yield
    # Shutdown
    await close_redis()


app = FastAPI(
    title=settings.APP_NAME,
    description="AI Data Scientist for SMB Analytics",
    version="0.1.0",
    docs_url=f"{settings.API_V1_PREFIX}/docs",
    redoc_url=f"{settings.API_V1_PREFIX}/redoc",
    lifespan=lifespan,
)

# CORS middleware
if settings.CORS_ORIGINS:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.CORS_ORIGINS,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

# Include routers
app.include_router(api_router, prefix=settings.API_V1_PREFIX)


@app.get("/")
async def root():
    return {
        "app": settings.APP_NAME,
        "version": "0.1.0",
        "environment": settings.ENVIRONMENT,
    }
```

**`app/api/v1/health.py`**:
```python
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from redis import asyncio as aioredis

from app.core.database import get_db
from app.core.cache import get_redis

router = APIRouter()


@router.get("/health")
async def health_check():
    """Basic health check"""
    return {
        "status": "healthy",
        "service": "echo-api"
    }


@router.get("/health/db")
async def health_check_db(db: AsyncSession = Depends(get_db)):
    """Database health check"""
    try:
        await db.execute("SELECT 1")
        return {"status": "healthy", "database": "connected"}
    except Exception as e:
        return {"status": "unhealthy", "database": "disconnected", "error": str(e)}


@router.get("/health/redis")
async def health_check_redis(redis: aioredis.Redis = Depends(get_redis)):
    """Redis health check"""
    try:
        await redis.ping()
        return {"status": "healthy", "redis": "connected"}
    except Exception as e:
        return {"status": "unhealthy", "redis": "disconnected", "error": str(e)}
```

**`app/api/v1/router.py`**:
```python
from fastapi import APIRouter
from app.api.v1 import health

api_router = APIRouter()

api_router.include_router(health.router, tags=["health"])
```

**Action Items**:
- [ ] Create `app/main.py`
- [ ] Create `app/api/v1/health.py`
- [ ] Create `app/api/v1/router.py`
- [ ] Create `app/api/v1/__init__.py`
- [ ] Test application: `uvicorn app.main:app --reload`
- [ ] Test health endpoints:
  - `curl http://localhost:8000/`
  - `curl http://localhost:8000/api/v1/health`
  - `curl http://localhost:8000/api/v1/health/db`
  - `curl http://localhost:8000/api/v1/health/redis`

---

### Task 8: Basic Testing Setup

**Goal**: Set up pytest framework

**`pytest.ini`**:
```ini
[pytest]
testpaths = tests
python_files = test_*.py
python_classes = Test*
python_functions = test_*
asyncio_mode = auto
addopts = -v --cov=app --cov-report=term-missing
```

**`tests/conftest.py`**:
```python
import pytest
from fastapi.testclient import TestClient
from app.main import app


@pytest.fixture
def client():
    return TestClient(app)
```

**`tests/api/test_health.py`**:
```python
def test_root_endpoint(client):
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert data["app"] == "Echo"


def test_health_endpoint(client):
    response = client.get("/api/v1/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"
```

**Action Items**:
- [ ] Create `pytest.ini`
- [ ] Create `tests/conftest.py`
- [ ] Create `tests/api/test_health.py`
- [ ] Run tests: `pytest`
- [ ] Verify tests pass

---

## Acceptance Criteria

### Phase 0 is complete when:

1. **Environment**:
   - [ ] Can run `docker-compose up` successfully
   - [ ] All services start without errors (app, db, redis)

2. **API**:
   - [ ] Can access FastAPI docs at `http://localhost:8000/api/v1/docs`
   - [ ] Root endpoint (`/`) returns app info
   - [ ] Health endpoint (`/api/v1/health`) returns healthy status
   - [ ] Database health check passes
   - [ ] Redis health check passes

3. **Configuration**:
   - [ ] `.env` file exists with all required variables
   - [ ] Settings load correctly from environment

4. **Testing**:
   - [ ] Can run `pytest` successfully
   - [ ] All tests pass
   - [ ] Test coverage is generated

5. **Code Quality**:
   - [ ] Project structure follows best practices
   - [ ] Code is properly formatted
   - [ ] No linting errors

---

## Common Issues & Solutions

### Issue: Docker build fails
**Solution**: Ensure Docker daemon is running; check Dockerfile syntax

### Issue: Database connection fails
**Solution**: Verify DATABASE_URL format; check if PostgreSQL is running

### Issue: Redis connection fails
**Solution**: Verify REDIS_URL; check if Redis container is running

### Issue: Import errors in Python
**Solution**: Ensure `__init__.py` files exist in all packages

---

## Next Steps

After completing Phase 0, proceed to:
- **Phase 1**: Ingestion & Schema Handling

---

## Resources

- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [SQLAlchemy Async](https://docs.sqlalchemy.org/en/20/orm/extensions/asyncio.html)
- [Redis Python](https://redis-py.readthedocs.io/)
- [Supabase Python Client](https://supabase.com/docs/reference/python/introduction)
- [Docker Compose](https://docs.docker.com/compose/)

---

*Last Updated: 2025-11-19*
