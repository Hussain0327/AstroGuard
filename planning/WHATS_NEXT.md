# What's Next? 🚀

**Current Status**: Phase 0 Complete ✅  
**Next Phase**: Phase 1 - Ingestion & Schema Handling  
**Estimated Duration**: 5-7 days

---

## Quick Start for Phase 1

### Step 1: Read the Plan
📖 Open: `/workspaces/AstroGuard/planning/02_PHASE_1_INGESTION_AND_SCHEMA.md`

This document contains:
- Detailed task breakdown
- Complete code examples
- Database models
- API endpoints
- Test strategies

### Step 2: First Task - Database Models

Create the `DataSource` model to track uploaded files:

**File**: `app/models/data_source.py`

```python
from sqlalchemy import Column, String, DateTime, JSON, Integer, Enum
from sqlalchemy.sql import func
from app.core.database import Base
import enum

class SourceType(str, enum.Enum):
    CSV = "csv"
    EXCEL = "excel"
    STRIPE = "stripe"
    HUBSPOT = "hubspot"

class DataSource(Base):
    __tablename__ = "data_sources"
    
    id = Column(String, primary_key=True)
    user_id = Column(String, nullable=False)
    source_type = Column(Enum(SourceType), nullable=False)
    file_name = Column(String)
    upload_timestamp = Column(DateTime(timezone=True), server_default=func.now())
    schema_info = Column(JSON)
    validation_status = Column(String)
    validation_errors = Column(JSON)
    row_count = Column(Integer)
```

### Step 3: Create First Endpoint

**File**: `app/api/v1/ingestion.py`

Start with a simple CSV upload endpoint:

```python
from fastapi import APIRouter, UploadFile, File

router = APIRouter()

@router.post("/upload/csv")
async def upload_csv(file: UploadFile = File(...)):
    """Upload and validate CSV file"""
    content = await file.read()
    # Process CSV...
    return {"message": "File uploaded", "filename": file.filename}
```

### Step 4: Test It!

```bash
# Create a test CSV
echo "date,amount,customer_id
2024-01-01,100,CUST001
2024-01-02,200,CUST002" > test.csv

# Upload it
curl -X POST "http://localhost:8000/api/v1/ingestion/upload/csv" \
  -F "file=@test.csv"
```

---

## Phase 1 Task Checklist

Use this as your todo list:

### Task 1: File Upload Endpoints (Day 1)
- [ ] Create `app/models/data_source.py`
- [ ] Create `app/models/schemas.py` (Pydantic models)
- [ ] Create `app/api/v1/ingestion.py`
- [ ] Add ingestion router to main app
- [ ] Test CSV upload endpoint
- [ ] Test Excel upload endpoint

### Task 2: Schema Detection (Day 1-2)
- [ ] Create `app/services/schema_detector.py`
- [ ] Implement `detect_schema()` method
- [ ] Implement column type detection
- [ ] Add semantic type detection (currency, email, URL, etc.)
- [ ] Test with various CSV files

### Task 3: Data Validation (Day 2-3)
- [ ] Create `app/services/data_validator.py`
- [ ] Implement basic validation rules
- [ ] Add use-case specific validation
- [ ] Design helpful error messages
- [ ] Test with messy data

### Task 4: Ingestion Service (Day 3-4)
- [ ] Create `app/services/ingestion.py`
- [ ] Integrate schema detection
- [ ] Integrate validation
- [ ] Save to database
- [ ] Return structured response

### Task 5: Stripe Connector (Day 4-5)
- [ ] Create `app/services/connectors/stripe_connector.py`
- [ ] Implement charge fetching
- [ ] Implement invoice fetching
- [ ] Create connector endpoint
- [ ] Test with Stripe test API key

### Task 6: Sample Data & Testing (Day 5-7)
- [ ] Create sample revenue CSV (100+ rows)
- [ ] Create sample marketing CSV (100+ rows)
- [ ] Create sample with errors
- [ ] Write unit tests for schema detection
- [ ] Write unit tests for validation
- [ ] Write integration test for upload flow

---

## Development Workflow

### Daily Routine

1. **Morning**: Pick 1-2 tasks from checklist
2. **Code**: Implement features
3. **Test**: Write and run tests
4. **Commit**: Git commit with clear message
5. **Document**: Update progress

### Testing as You Go

```bash
# Run specific test file
docker-compose exec app pytest tests/unit/test_schema_detector.py -v

# Run all tests
docker-compose exec app pytest

# Run with coverage
docker-compose exec app pytest --cov=app --cov-report=html

# View coverage report
open htmlcov/index.html
```

### Useful Commands

```bash
# View API docs (always up-to-date)
open http://localhost:8000/api/v1/docs

# Check logs
docker-compose logs app -f

# Restart after changes
docker-compose restart app

# Access Python shell to test code
docker-compose exec app python
>>> from app.services.schema_detector import SchemaDetector
>>> import pandas as pd
>>> df = pd.read_csv('test.csv')
>>> detector = SchemaDetector(df)
>>> detector.detect_schema()
```

---

## MVP Approach (Faster Path)

If you want to move faster, focus on the essential features first:

### Week 1 MVP:
1. ✅ CSV upload endpoint (basic)
2. ✅ Simple schema detection (just column types)
3. ✅ Basic validation (empty file, missing columns)
4. ✅ Save to database
5. ✅ Return results

**Skip for MVP**:
- Excel support (add later)
- Stripe connector (add later)
- Advanced validation (add later)

### Then Iterate:
Once MVP works end-to-end, add:
- Better error messages
- Excel support
- More validation rules
- Stripe connector

---

## Key Principles for Phase 1

1. **Start Simple**: Get CSV upload working first, then enhance
2. **Test Early**: Write tests as you build features
3. **User-Friendly Errors**: Focus on helpful validation messages
4. **Real Data**: Use realistic sample datasets for testing
5. **Commit Often**: Small, focused commits

---

## Expected Timeline

### Week 1 (Phase 1)
- **Mon-Tue**: File upload + schema detection
- **Wed-Thu**: Validation engine + ingestion service
- **Fri**: Stripe connector (optional)

### Weekend
- Polish, test, document
- Create sample datasets
- Write comprehensive tests

### Week 2 Start
- Begin Phase 2: Deterministic Analytics Layer

---

## Success Criteria

Phase 1 is done when you can:

1. Upload a CSV file via API
2. Get automatic schema detection back
3. See helpful validation messages for bad data
4. Query the database to see stored metadata
5. (Optional) Connect to Stripe and ingest data

---

## Resources

### Phase 1 Documentation
- Full plan: `/workspaces/AstroGuard/planning/02_PHASE_1_INGESTION_AND_SCHEMA.md`
- Code examples included in plan
- Acceptance criteria at end of document

### Helpful Links
- FastAPI File Uploads: https://fastapi.tiangolo.com/tutorial/request-files/
- Pandas Type Detection: https://pandas.pydata.org/docs/reference/api/pandas.api.types.html
- SQLAlchemy Models: https://docs.sqlalchemy.org/en/20/orm/declarative_tables.html
- Stripe Python: https://stripe.com/docs/api/python

---

## Get Started Now!

```bash
# 1. Make sure everything is running
docker-compose ps

# 2. Open the Phase 1 plan
code /workspaces/AstroGuard/planning/02_PHASE_1_INGESTION_AND_SCHEMA.md

# 3. Create first file
mkdir -p app/models
touch app/models/data_source.py

# 4. Start coding!
```

---

**Ready?** Let's build the data ingestion layer! 🚀

Remember: **Progress over perfection**. Get something working, then make it better.

Good luck! You've got this! 💪
