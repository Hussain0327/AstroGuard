# Phase 5: Engineering Excellence

**Duration**: 5-7 days
**Goal**: Production-ready infrastructure and code quality

---

## Overview

This phase elevates Echo from a working prototype to production-grade software. We'll add comprehensive testing, CI/CD pipelines, monitoring, proper error handling, and security best practices.

**Key Principle**: "Production-ready code demonstrates professional engineering skills"

---

## Objectives

1. Achieve >80% test coverage
2. Set up CI/CD pipeline
3. Implement proper error handling
4. Add monitoring and observability
5. Implement rate limiting and security
6. Configure environments (dev, staging, prod)
7. Add performance optimizations

---

## Detailed Tasks

### Task 1: Comprehensive Testing

**Goal**: Achieve >80% test coverage across all components

**Test Structure**:
```
tests/
├── unit/
│   ├── services/
│   │   ├── test_ingestion.py
│   │   ├── test_metrics/
│   │   │   ├── test_revenue_metrics.py
│   │   │   ├── test_financial_metrics.py
│   │   │   └── test_marketing_metrics.py
│   │   └── test_validation.py
│   ├── api/
│   │   ├── test_health.py
│   │   ├── test_ingestion_endpoints.py
│   │   └── test_reports_endpoints.py
│   └── utils/
│       └── test_timeseries.py
├── integration/
│   ├── test_report_generation.py
│   ├── test_stripe_integration.py
│   └── test_feedback_flow.py
└── conftest.py
```

**Enhanced Conftest** (`tests/conftest.py`):
```python
import pytest
import pytest_asyncio
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from fastapi.testclient import TestClient
import pandas as pd

from app.main import app
from app.core.database import Base, get_db
from app.config import get_settings


# Test database URL
TEST_DATABASE_URL = "postgresql+asyncpg://test:test@localhost:5432/echo_test"


@pytest_asyncio.fixture
async def test_engine():
    """Create test database engine"""
    engine = create_async_engine(TEST_DATABASE_URL, echo=False)

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)

    yield engine

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)

    await engine.dispose()


@pytest_asyncio.fixture
async def test_db(test_engine):
    """Create test database session"""
    async_session = sessionmaker(
        test_engine, class_=AsyncSession, expire_on_commit=False
    )

    async with async_session() as session:
        yield session


@pytest.fixture
def client(test_db):
    """Create test client with database override"""
    async def override_get_db():
        yield test_db

    app.dependency_overrides[get_db] = override_get_db
    yield TestClient(app)
    app.dependency_overrides.clear()


@pytest.fixture
def sample_revenue_df():
    """Sample revenue DataFrame for testing"""
    return pd.DataFrame({
        'date': pd.date_range('2024-01-01', periods=30, freq='D'),
        'amount': [100 + i * 10 for i in range(30)],
        'customer_id': [f'CUST{i % 10}' for i in range(30)],
        'status': ['paid'] * 30
    })


@pytest.fixture
def sample_marketing_df():
    """Sample marketing DataFrame for testing"""
    return pd.DataFrame({
        'source': ['Google'] * 10 + ['Facebook'] * 10,
        'status': ['converted'] * 5 + ['lead'] * 5 + ['converted'] * 3 + ['lead'] * 7,
        'date': pd.date_range('2024-01-01', periods=20, freq='D')
    })
```

**Integration Test Example** (`tests/integration/test_report_generation.py`):
```python
import pytest
from app.services.agents.orchestrator import ReportOrchestrator
from app.services.reports.templates import get_template, TemplateType


@pytest.mark.asyncio
async def test_full_report_generation(sample_revenue_df, test_db):
    """Test complete report generation pipeline"""

    template = get_template(TemplateType.REVENUE_HEALTH)

    context = {
        'dataframe': sample_revenue_df,
        'template': template,
        'data_source_id': 'test_source'
    }

    orchestrator = ReportOrchestrator(context)
    result = await orchestrator.execute_pipeline()

    # Assert success
    assert result['success'] is True

    # Assert metrics were calculated
    assert 'metrics' in result['report']
    assert 'total_revenue' in result['report']['metrics']

    # Assert narratives were generated
    assert 'narratives' in result['report']
    assert 'executive_summary' in result['report']['narratives']

    # Assert narrative is not empty
    assert len(result['report']['narratives']['executive_summary']) > 0
```

**Test Commands** (`Makefile`):
```makefile
.PHONY: test test-unit test-integration test-coverage

test:
	pytest

test-unit:
	pytest tests/unit -v

test-integration:
	pytest tests/integration -v

test-coverage:
	pytest --cov=app --cov-report=html --cov-report=term-missing

test-fast:
	pytest -x --ff
```

**Action Items**:
- [ ] Write unit tests for all services
- [ ] Write unit tests for all API endpoints
- [ ] Write integration tests for key workflows
- [ ] Achieve >80% coverage
- [ ] Add test documentation

---

### Task 2: CI/CD Pipeline

**Goal**: Automated testing and deployment

**GitHub Actions** (`.github/workflows/ci.yml`):
```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'

      - name: Install dependencies
        run: |
          pip install black flake8 isort mypy
          pip install -r requirements.txt

      - name: Run Black
        run: black --check app tests

      - name: Run isort
        run: isort --check-only app tests

      - name: Run Flake8
        run: flake8 app tests --max-line-length=100

      - name: Run mypy
        run: mypy app --ignore-missing-imports

  test:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_USER: test
          POSTGRES_PASSWORD: test
          POSTGRES_DB: echo_test
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 5432:5432

      redis:
        image: redis:7-alpine
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
        ports:
          - 6379:6379

    steps:
      - uses: actions/checkout@v3

      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.11'

      - name: Install dependencies
        run: |
          pip install -r requirements.txt -r requirements-dev.txt

      - name: Run tests
        env:
          DATABASE_URL: postgresql+asyncpg://test:test@localhost:5432/echo_test
          REDIS_URL: redis://localhost:6379/0
        run: |
          pytest --cov=app --cov-report=xml --cov-report=term-missing

      - name: Upload coverage
        uses: codecov/codecov-action@v3
        with:
          file: ./coverage.xml
          fail_ci_if_error: true

  build:
    runs-on: ubuntu-latest
    needs: [lint, test]

    steps:
      - uses: actions/checkout@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2

      - name: Login to Docker Hub
        uses: docker/login-action@v2
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}

      - name: Build and push
        uses: docker/build-push-action@v4
        with:
          context: .
          push: ${{ github.ref == 'refs/heads/main' }}
          tags: |
            your-username/echo:latest
            your-username/echo:${{ github.sha }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

**Pre-commit Hooks** (`.pre-commit-config.yaml`):
```yaml
repos:
  - repo: https://github.com/psf/black
    rev: 23.11.0
    hooks:
      - id: black
        language_version: python3.11

  - repo: https://github.com/pycqa/isort
    rev: 5.12.0
    hooks:
      - id: isort

  - repo: https://github.com/pycqa/flake8
    rev: 6.1.0
    hooks:
      - id: flake8
        args: [--max-line-length=100]
```

**Action Items**:
- [ ] Create CI/CD workflow
- [ ] Set up GitHub Actions
- [ ] Configure pre-commit hooks
- [ ] Add code coverage reporting
- [ ] Set up Docker build/push

---

### Task 3: Error Handling

**Goal**: Graceful error handling and user-friendly messages

**Custom Exceptions** (`app/core/exceptions.py`):
```python
class EchoException(Exception):
    """Base exception for Echo"""
    def __init__(self, message: str, details: dict = None):
        self.message = message
        self.details = details or {}
        super().__init__(self.message)


class ValidationError(EchoException):
    """Data validation error"""
    pass


class MetricCalculationError(EchoException):
    """Error calculating metrics"""
    pass


class DataSourceNotFoundError(EchoException):
    """Data source not found"""
    pass


class ExternalAPIError(EchoException):
    """External API error (Stripe, etc.)"""
    pass
```

**Exception Handler** (`app/api/middleware/error_handler.py`):
```python
from fastapi import Request, status
from fastapi.responses import JSONResponse
from app.core.exceptions import EchoException, ValidationError
from app.core.logging import get_logger

logger = get_logger(__name__)


async def echo_exception_handler(request: Request, exc: EchoException):
    """Handle Echo exceptions"""
    logger.error(
        "echo_exception",
        exception_type=type(exc).__name__,
        message=exc.message,
        details=exc.details,
        path=request.url.path
    )

    status_code = status.HTTP_400_BAD_REQUEST
    if isinstance(exc, ValidationError):
        status_code = status.HTTP_422_UNPROCESSABLE_ENTITY

    return JSONResponse(
        status_code=status_code,
        content={
            "error": type(exc).__name__,
            "message": exc.message,
            "details": exc.details
        }
    )


async def general_exception_handler(request: Request, exc: Exception):
    """Handle unexpected exceptions"""
    logger.error(
        "unexpected_exception",
        exception_type=type(exc).__name__,
        message=str(exc),
        path=request.url.path,
        exc_info=True
    )

    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "error": "InternalServerError",
            "message": "An unexpected error occurred. Please try again later."
        }
    )
```

**Action Items**:
- [ ] Define custom exceptions
- [ ] Add exception handlers
- [ ] Use exceptions throughout codebase
- [ ] Add retry logic for external APIs
- [ ] Test error scenarios

---

### Task 4: Monitoring & Observability

**Goal**: Track system health and performance

**Metrics Endpoint** (`app/api/v1/monitoring.py`):
```python
from fastapi import APIRouter
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from fastapi.responses import Response
import psutil
import time

router = APIRouter()

# Prometheus metrics
report_generation_counter = Counter(
    'echo_reports_generated_total',
    'Total number of reports generated'
)

report_generation_duration = Histogram(
    'echo_report_generation_duration_seconds',
    'Report generation duration in seconds'
)

api_request_duration = Histogram(
    'echo_api_request_duration_seconds',
    'API request duration in seconds',
    ['method', 'endpoint']
)


@router.get("/metrics")
async def metrics():
    """Prometheus metrics endpoint"""
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)


@router.get("/health/detailed")
async def detailed_health():
    """Detailed health check with system metrics"""
    return {
        "status": "healthy",
        "timestamp": time.time(),
        "system": {
            "cpu_percent": psutil.cpu_percent(),
            "memory_percent": psutil.virtual_memory().percent,
            "disk_percent": psutil.disk_usage('/').percent
        }
    }
```

**Request Logging Middleware** (`app/api/middleware/logging.py`):
```python
from fastapi import Request
import time
from app.core.logging import get_logger

logger = get_logger(__name__)


async def log_requests(request: Request, call_next):
    """Log all API requests"""
    start_time = time.time()

    logger.info(
        "request_started",
        method=request.method,
        path=request.url.path,
        client_ip=request.client.host
    )

    response = await call_next(request)

    duration = time.time() - start_time

    logger.info(
        "request_completed",
        method=request.method,
        path=request.url.path,
        status_code=response.status_code,
        duration_seconds=duration
    )

    return response
```

**Action Items**:
- [ ] Add Prometheus metrics
- [ ] Create detailed health endpoints
- [ ] Add request logging middleware
- [ ] Monitor key metrics (latency, errors, etc.)
- [ ] Set up alerting (optional)

---

### Task 5: Security & Rate Limiting

**Goal**: Secure the application

**Rate Limiting** (`app/api/middleware/rate_limit.py`):
```python
from fastapi import Request, HTTPException
from app.core.cache import get_redis
import time


class RateLimiter:
    """Simple rate limiter using Redis"""

    def __init__(self, requests: int = 100, window: int = 60):
        self.requests = requests
        self.window = window

    async def check_rate_limit(self, request: Request):
        """Check if request exceeds rate limit"""
        redis = await get_redis()

        # Use IP address as identifier
        client_ip = request.client.host
        key = f"rate_limit:{client_ip}"

        # Get current count
        count = await redis.get(key)

        if count is None:
            # First request in window
            await redis.setex(key, self.window, 1)
        elif int(count) >= self.requests:
            # Rate limit exceeded
            raise HTTPException(
                status_code=429,
                detail="Rate limit exceeded. Please try again later."
            )
        else:
            # Increment count
            await redis.incr(key)


rate_limiter = RateLimiter(requests=100, window=60)
```

**Security Headers** (`app/main.py`):
```python
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.middleware.gzip import GZipMiddleware

# Add security middleware
app.add_middleware(
    TrustedHostMiddleware,
    allowed_hosts=["localhost", "*.yourdomain.com"]
)

app.add_middleware(GZipMiddleware, minimum_size=1000)


@app.middleware("http")
async def add_security_headers(request: Request, call_next):
    """Add security headers to responses"""
    response = await call_next(request)

    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"

    return response
```

**Input Validation**:
```python
from pydantic import BaseModel, validator, Field


class SecureUploadRequest(BaseModel):
    file_size: int = Field(le=10_000_000)  # Max 10MB

    @validator('file_size')
    def validate_file_size(cls, v):
        if v > 10_000_000:
            raise ValueError('File size exceeds maximum allowed size')
        return v
```

**Action Items**:
- [ ] Implement rate limiting
- [ ] Add security headers
- [ ] Validate all inputs
- [ ] Add file size limits
- [ ] Sanitize user inputs
- [ ] Add CORS properly

---

### Task 6: Environment Configuration

**Goal**: Proper environment separation

**Config Files**:
```
.env.development
.env.staging
.env.production
```

**Docker Compose for Different Environments**:
```yaml
# docker-compose.prod.yml
version: '3.8'

services:
  app:
    build: .
    env_file:
      - .env.production
    restart: always
    depends_on:
      - db
      - redis

  db:
    image: postgres:15-alpine
    env_file:
      - .env.production
    volumes:
      - postgres_data_prod:/var/lib/postgresql/data
    restart: always

  redis:
    image: redis:7-alpine
    restart: always
```

**Action Items**:
- [ ] Create environment-specific configs
- [ ] Set up staging environment
- [ ] Configure production settings
- [ ] Document deployment process

---

## Acceptance Criteria

### Phase 5 is complete when:

1. **Testing**:
   - [ ] Test coverage >80%
   - [ ] All critical paths tested
   - [ ] Integration tests pass

2. **CI/CD**:
   - [ ] GitHub Actions workflow runs on PR
   - [ ] Tests run automatically
   - [ ] Docker image builds successfully

3. **Error Handling**:
   - [ ] Custom exceptions defined
   - [ ] Error handlers registered
   - [ ] Errors return helpful messages

4. **Monitoring**:
   - [ ] Prometheus metrics exposed
   - [ ] Structured logging in place
   - [ ] Health endpoints working

5. **Security**:
   - [ ] Rate limiting active
   - [ ] Security headers added
   - [ ] Inputs validated
   - [ ] No secrets in code

6. **Production Ready**:
   - [ ] Can deploy to production
   - [ ] Environment configs separated
   - [ ] Documentation complete

---

## Next Steps

After completing Phase 5, proceed to:
- **Phase 6**: Documentation & Polish

---

*Last Updated: 2025-11-19*
