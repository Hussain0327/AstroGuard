# Phase 1: Ingestion & Schema Handling

**Duration**: 5-7 days
**Goal**: Build robust data ingestion with validation and error handling

---

## Overview

This phase focuses on building the data ingestion pipeline for Echo. We'll support CSV/Excel uploads with automatic schema detection, implement comprehensive validation, provide helpful error messages, and create at least one SaaS connector (Stripe or HubSpot).

---

## Objectives

1. Build file upload endpoints (CSV/Excel)
2. Implement automatic schema detection and analysis
3. Create comprehensive data validation engine
4. Design user-friendly error messages and feedback
5. Build one SaaS connector (Stripe recommended)
6. Create sample datasets for testing
7. Store ingested data in database

---

## Detailed Tasks

### Task 1: File Upload Endpoints

**Goal**: Accept CSV and Excel file uploads via API

**Database Model** (`app/models/data_source.py`):
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
    user_id = Column(String, nullable=False)  # For future auth
    source_type = Column(Enum(SourceType), nullable=False)
    file_name = Column(String)
    file_size = Column(Integer)
    upload_timestamp = Column(DateTime(timezone=True), server_default=func.now())
    schema_info = Column(JSON)  # Detected schema
    validation_status = Column(String)  # "pending", "valid", "invalid"
    validation_errors = Column(JSON)
    row_count = Column(Integer)
    metadata = Column(JSON)  # Additional info
```

**Pydantic Schemas** (`app/models/schemas.py`):
```python
from pydantic import BaseModel, Field
from typing import Optional, Dict, List, Any
from datetime import datetime
from enum import Enum


class SourceTypeEnum(str, Enum):
    CSV = "csv"
    EXCEL = "excel"
    STRIPE = "stripe"
    HUBSPOT = "hubspot"


class ColumnInfo(BaseModel):
    name: str
    data_type: str
    nullable: bool
    sample_values: List[Any]
    null_count: int
    unique_count: int


class SchemaInfo(BaseModel):
    columns: Dict[str, ColumnInfo]
    total_rows: int
    total_columns: int


class UploadResponse(BaseModel):
    id: str
    source_type: SourceTypeEnum
    file_name: str
    status: str
    message: str
    schema_info: Optional[SchemaInfo] = None
    validation_errors: Optional[List[str]] = None


class DataSourceResponse(BaseModel):
    id: str
    user_id: str
    source_type: SourceTypeEnum
    file_name: Optional[str]
    upload_timestamp: datetime
    validation_status: str
    row_count: Optional[int]
```

**Upload Endpoint** (`app/api/v1/ingestion.py`):
```python
from fastapi import APIRouter, UploadFile, File, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.database import get_db
from app.services.ingestion import IngestionService
from app.models.schemas import UploadResponse
import uuid

router = APIRouter()


@router.post("/upload/csv", response_model=UploadResponse)
async def upload_csv(
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db)
):
    """Upload and validate CSV file"""
    if not file.filename.endswith('.csv'):
        raise HTTPException(status_code=400, detail="File must be a CSV")

    service = IngestionService(db)
    result = await service.ingest_csv(file)
    return result


@router.post("/upload/excel", response_model=UploadResponse)
async def upload_excel(
    file: UploadFile = File(...),
    db: AsyncSession = Depends(get_db)
):
    """Upload and validate Excel file"""
    if not file.filename.endswith(('.xlsx', '.xls')):
        raise HTTPException(status_code=400, detail="File must be an Excel file")

    service = IngestionService(db)
    result = await service.ingest_excel(file)
    return result


@router.get("/sources", response_model=List[DataSourceResponse])
async def list_sources(
    db: AsyncSession = Depends(get_db),
    limit: int = 10
):
    """List uploaded data sources"""
    service = IngestionService(db)
    return await service.list_sources(limit)


@router.get("/sources/{source_id}", response_model=DataSourceResponse)
async def get_source(
    source_id: str,
    db: AsyncSession = Depends(get_db)
):
    """Get data source details"""
    service = IngestionService(db)
    source = await service.get_source(source_id)
    if not source:
        raise HTTPException(status_code=404, detail="Source not found")
    return source
```

**Action Items**:
- [ ] Create database model for `DataSource`
- [ ] Create Pydantic schemas
- [ ] Create ingestion endpoints
- [ ] Add router to main app
- [ ] Create Alembic migration for database

---

### Task 2: Schema Detection Engine

**Goal**: Automatically detect and analyze data schema

**Schema Detector** (`app/services/schema_detector.py`):
```python
import pandas as pd
from typing import Dict, Any, List
from app.models.schemas import SchemaInfo, ColumnInfo


class SchemaDetector:
    """Detects and analyzes data schema"""

    def __init__(self, df: pd.DataFrame):
        self.df = df

    def detect_schema(self) -> SchemaInfo:
        """Detect schema from DataFrame"""
        columns_info = {}

        for col in self.df.columns:
            columns_info[col] = self._analyze_column(col)

        return SchemaInfo(
            columns=columns_info,
            total_rows=len(self.df),
            total_columns=len(self.df.columns)
        )

    def _analyze_column(self, col: str) -> ColumnInfo:
        """Analyze a single column"""
        series = self.df[col]

        # Detect data type
        data_type = self._detect_data_type(series)

        # Get sample values (non-null)
        sample_values = series.dropna().head(5).tolist()

        return ColumnInfo(
            name=col,
            data_type=data_type,
            nullable=series.isnull().any(),
            sample_values=sample_values,
            null_count=int(series.isnull().sum()),
            unique_count=int(series.nunique())
        )

    def _detect_data_type(self, series: pd.Series) -> str:
        """Detect the semantic data type of a column"""
        # Remove nulls for type detection
        non_null = series.dropna()

        if len(non_null) == 0:
            return "unknown"

        # Check for numeric types
        if pd.api.types.is_numeric_dtype(series):
            # Check if it's currency
            if self._is_currency(non_null):
                return "currency"
            # Check if it's integer
            if pd.api.types.is_integer_dtype(series):
                return "integer"
            return "numeric"

        # Check for datetime
        if pd.api.types.is_datetime64_any_dtype(series):
            return "datetime"

        # Try to parse as datetime
        if self._is_date(non_null):
            return "date"

        # Check for boolean
        if self._is_boolean(non_null):
            return "boolean"

        # Check for email
        if self._is_email(non_null):
            return "email"

        # Check for URL
        if self._is_url(non_null):
            return "url"

        # Default to string
        return "string"

    def _is_currency(self, series: pd.Series) -> bool:
        """Check if column contains currency values"""
        sample = series.head(10).astype(str)
        return any(s.startswith('$') or s.startswith('€') for s in sample)

    def _is_date(self, series: pd.Series) -> bool:
        """Check if column can be parsed as dates"""
        try:
            pd.to_datetime(series.head(10), errors='coerce')
            return True
        except:
            return False

    def _is_boolean(self, series: pd.Series) -> bool:
        """Check if column contains boolean values"""
        unique_values = set(series.astype(str).str.lower().unique())
        bool_values = {'true', 'false', 't', 'f', 'yes', 'no', 'y', 'n', '1', '0'}
        return unique_values.issubset(bool_values)

    def _is_email(self, series: pd.Series) -> bool:
        """Check if column contains emails"""
        sample = series.head(10).astype(str)
        return all('@' in s and '.' in s for s in sample)

    def _is_url(self, series: pd.Series) -> bool:
        """Check if column contains URLs"""
        sample = series.head(10).astype(str)
        return all(s.startswith(('http://', 'https://')) for s in sample)
```

**Action Items**:
- [ ] Create `SchemaDetector` class
- [ ] Implement data type detection logic
- [ ] Add semantic type detection (currency, email, etc.)
- [ ] Test with various datasets

---

### Task 3: Data Validation Engine

**Goal**: Validate data quality and provide actionable feedback

**Validator** (`app/services/data_validator.py`):
```python
from typing import List, Dict, Any
import pandas as pd
from dataclasses import dataclass


@dataclass
class ValidationError:
    severity: str  # "error", "warning", "info"
    field: str
    message: str
    suggestion: str


class DataValidator:
    """Validates data quality and structure"""

    def __init__(self, df: pd.DataFrame, use_case: str = None):
        self.df = df
        self.use_case = use_case
        self.errors: List[ValidationError] = []

    def validate(self) -> List[ValidationError]:
        """Run all validation checks"""
        self._check_empty_file()
        self._check_required_columns()
        self._check_data_quality()
        self._check_date_columns()
        self._check_numeric_columns()
        self._check_use_case_requirements()

        return self.errors

    def _check_empty_file(self):
        """Check if file is empty"""
        if len(self.df) == 0:
            self.errors.append(ValidationError(
                severity="error",
                field="file",
                message="File is empty",
                suggestion="Please upload a file with at least one row of data"
            ))

    def _check_required_columns(self):
        """Check for minimum required columns"""
        if len(self.df.columns) < 2:
            self.errors.append(ValidationError(
                severity="error",
                field="columns",
                message="File must have at least 2 columns",
                suggestion="Add more columns with relevant data"
            ))

    def _check_data_quality(self):
        """Check overall data quality"""
        total_cells = len(self.df) * len(self.df.columns)
        null_cells = self.df.isnull().sum().sum()
        null_percentage = (null_cells / total_cells) * 100

        if null_percentage > 50:
            self.errors.append(ValidationError(
                severity="warning",
                field="data_quality",
                message=f"File has {null_percentage:.1f}% missing values",
                suggestion="Consider cleaning your data or filling missing values"
            ))

    def _check_date_columns(self):
        """Check for date/timestamp columns"""
        date_cols = [col for col in self.df.columns
                     if 'date' in col.lower() or 'time' in col.lower()]

        if not date_cols:
            self.errors.append(ValidationError(
                severity="warning",
                field="dates",
                message="No date columns detected",
                suggestion="Time-based analysis requires a date/timestamp column"
            ))

        # Validate date format
        for col in date_cols:
            try:
                pd.to_datetime(self.df[col])
            except:
                self.errors.append(ValidationError(
                    severity="error",
                    field=col,
                    message=f"Column '{col}' cannot be parsed as dates",
                    suggestion=f"Ensure '{col}' has valid date format (YYYY-MM-DD, MM/DD/YYYY, etc.)"
                ))

    def _check_numeric_columns(self):
        """Check for numeric columns"""
        numeric_cols = self.df.select_dtypes(include=['number']).columns

        if len(numeric_cols) == 0:
            self.errors.append(ValidationError(
                severity="error",
                field="metrics",
                message="No numeric columns detected",
                suggestion="Add at least one numeric column for metrics (revenue, quantity, etc.)"
            ))

    def _check_use_case_requirements(self):
        """Check requirements based on use case"""
        if self.use_case == "revenue":
            self._validate_revenue_use_case()
        elif self.use_case == "marketing":
            self._validate_marketing_use_case()

    def _validate_revenue_use_case(self):
        """Validate revenue-specific requirements"""
        required_fields = {
            'amount': ['amount', 'revenue', 'total', 'price'],
            'date': ['date', 'timestamp', 'created_at', 'order_date']
        }

        for field_type, possible_names in required_fields.items():
            found = any(
                any(name in col.lower() for name in possible_names)
                for col in self.df.columns
            )

            if not found:
                self.errors.append(ValidationError(
                    severity="error",
                    field=field_type,
                    message=f"Missing {field_type} column for revenue analysis",
                    suggestion=f"Add a column with one of these names: {', '.join(possible_names)}"
                ))

    def _validate_marketing_use_case(self):
        """Validate marketing-specific requirements"""
        required_fields = {
            'source': ['source', 'campaign', 'channel', 'utm_source'],
            'conversion': ['conversion', 'converted', 'status', 'stage']
        }

        for field_type, possible_names in required_fields.items():
            found = any(
                any(name in col.lower() for name in possible_names)
                for col in self.df.columns
            )

            if not found:
                self.errors.append(ValidationError(
                    severity="warning",
                    field=field_type,
                    message=f"Missing {field_type} column for marketing analysis",
                    suggestion=f"Consider adding: {', '.join(possible_names)}"
                ))
```

**Action Items**:
- [ ] Create `DataValidator` class
- [ ] Implement validation rules
- [ ] Add use-case specific validation
- [ ] Design helpful error messages

---

### Task 4: Ingestion Service

**Goal**: Orchestrate the complete ingestion process

**Service** (`app/services/ingestion.py`):
```python
import pandas as pd
import uuid
from io import BytesIO
from fastapi import UploadFile
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.models.data_source import DataSource, SourceType
from app.models.schemas import UploadResponse
from app.services.schema_detector import SchemaDetector
from app.services.data_validator import DataValidator


class IngestionService:
    """Service for data ingestion"""

    def __init__(self, db: AsyncSession):
        self.db = db

    async def ingest_csv(self, file: UploadFile) -> UploadResponse:
        """Ingest CSV file"""
        # Read file content
        content = await file.read()

        # Parse CSV
        try:
            df = pd.read_csv(BytesIO(content))
        except Exception as e:
            return UploadResponse(
                id=str(uuid.uuid4()),
                source_type=SourceType.CSV,
                file_name=file.filename,
                status="error",
                message=f"Failed to parse CSV: {str(e)}",
                validation_errors=[str(e)]
            )

        return await self._process_dataframe(
            df=df,
            source_type=SourceType.CSV,
            file_name=file.filename,
            file_size=len(content)
        )

    async def ingest_excel(self, file: UploadFile) -> UploadResponse:
        """Ingest Excel file"""
        content = await file.read()

        try:
            df = pd.read_excel(BytesIO(content))
        except Exception as e:
            return UploadResponse(
                id=str(uuid.uuid4()),
                source_type=SourceType.EXCEL,
                file_name=file.filename,
                status="error",
                message=f"Failed to parse Excel: {str(e)}",
                validation_errors=[str(e)]
            )

        return await self._process_dataframe(
            df=df,
            source_type=SourceType.EXCEL,
            file_name=file.filename,
            file_size=len(content)
        )

    async def _process_dataframe(
        self,
        df: pd.DataFrame,
        source_type: SourceType,
        file_name: str,
        file_size: int
    ) -> UploadResponse:
        """Process and validate DataFrame"""
        source_id = str(uuid.uuid4())

        # Detect schema
        detector = SchemaDetector(df)
        schema_info = detector.detect_schema()

        # Validate data
        validator = DataValidator(df)
        validation_errors = validator.validate()

        # Determine status
        has_errors = any(e.severity == "error" for e in validation_errors)
        status = "invalid" if has_errors else "valid"

        # Save to database
        data_source = DataSource(
            id=source_id,
            user_id="default",  # TODO: Get from auth
            source_type=source_type,
            file_name=file_name,
            file_size=file_size,
            schema_info=schema_info.dict(),
            validation_status=status,
            validation_errors=[
                {
                    "severity": e.severity,
                    "field": e.field,
                    "message": e.message,
                    "suggestion": e.suggestion
                }
                for e in validation_errors
            ],
            row_count=len(df)
        )

        self.db.add(data_source)
        await self.db.commit()

        # Prepare response
        message = "File uploaded and validated successfully"
        if has_errors:
            message = "File uploaded but has validation errors"
        elif validation_errors:
            message = "File uploaded with warnings"

        return UploadResponse(
            id=source_id,
            source_type=source_type,
            file_name=file_name,
            status=status,
            message=message,
            schema_info=schema_info,
            validation_errors=[
                f"{e.severity.upper()}: {e.message} - {e.suggestion}"
                for e in validation_errors
            ]
        )

    async def list_sources(self, limit: int = 10):
        """List data sources"""
        result = await self.db.execute(
            select(DataSource)
            .order_by(DataSource.upload_timestamp.desc())
            .limit(limit)
        )
        return result.scalars().all()

    async def get_source(self, source_id: str):
        """Get data source by ID"""
        result = await self.db.execute(
            select(DataSource).where(DataSource.id == source_id)
        )
        return result.scalar_one_or_none()
```

**Action Items**:
- [ ] Create `IngestionService`
- [ ] Implement CSV/Excel processing
- [ ] Integrate schema detection
- [ ] Integrate validation
- [ ] Save results to database

---

### Task 5: SaaS Connector (Stripe)

**Goal**: Connect to Stripe API and ingest transaction data

**Stripe Connector** (`app/services/connectors/stripe_connector.py`):
```python
import stripe
from typing import List, Dict, Any
import pandas as pd
from datetime import datetime, timedelta
from app.config import get_settings

settings = get_settings()


class StripeConnector:
    """Connector for Stripe API"""

    def __init__(self, api_key: str = None):
        self.api_key = api_key or settings.STRIPE_API_KEY
        stripe.api_key = self.api_key

    async def fetch_charges(
        self,
        days: int = 30,
        limit: int = 100
    ) -> pd.DataFrame:
        """Fetch charges from Stripe"""
        # Calculate date range
        start_date = datetime.now() - timedelta(days=days)

        # Fetch charges
        charges = stripe.Charge.list(
            limit=limit,
            created={'gte': int(start_date.timestamp())}
        )

        # Convert to DataFrame
        data = []
        for charge in charges.auto_paging_iter():
            data.append({
                'charge_id': charge.id,
                'amount': charge.amount / 100,  # Convert cents to dollars
                'currency': charge.currency,
                'status': charge.status,
                'created_at': datetime.fromtimestamp(charge.created),
                'customer_id': charge.customer,
                'description': charge.description,
                'paid': charge.paid,
                'refunded': charge.refunded,
                'metadata': charge.metadata
            })

        return pd.DataFrame(data)

    async def fetch_invoices(self, days: int = 30) -> pd.DataFrame:
        """Fetch invoices from Stripe"""
        start_date = datetime.now() - timedelta(days=days)

        invoices = stripe.Invoice.list(
            limit=100,
            created={'gte': int(start_date.timestamp())}
        )

        data = []
        for invoice in invoices.auto_paging_iter():
            data.append({
                'invoice_id': invoice.id,
                'amount_due': invoice.amount_due / 100,
                'amount_paid': invoice.amount_paid / 100,
                'currency': invoice.currency,
                'status': invoice.status,
                'created_at': datetime.fromtimestamp(invoice.created),
                'customer_id': invoice.customer,
                'subscription_id': invoice.subscription
            })

        return pd.DataFrame(data)


**Stripe Ingestion Endpoint** (`app/api/v1/connectors.py`):
```python
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel

from app.core.database import get_db
from app.services.connectors.stripe_connector import StripeConnector
from app.services.ingestion import IngestionService
from app.models.schemas import UploadResponse
from app.models.data_source import SourceType

router = APIRouter()


class StripeConnectRequest(BaseModel):
    api_key: str
    days: int = 30
    data_type: str = "charges"  # "charges" or "invoices"


@router.post("/stripe/connect", response_model=UploadResponse)
async def connect_stripe(
    request: StripeConnectRequest,
    db: AsyncSession = Depends(get_db)
):
    """Connect to Stripe and ingest data"""
    try:
        connector = StripeConnector(api_key=request.api_key)

        # Fetch data
        if request.data_type == "charges":
            df = await connector.fetch_charges(days=request.days)
        elif request.data_type == "invoices":
            df = await connector.fetch_invoices(days=request.days)
        else:
            raise HTTPException(status_code=400, detail="Invalid data_type")

        # Process through ingestion service
        service = IngestionService(db)
        result = await service._process_dataframe(
            df=df,
            source_type=SourceType.STRIPE,
            file_name=f"stripe_{request.data_type}_{request.days}days",
            file_size=len(df)
        )

        return result

    except stripe.error.AuthenticationError:
        raise HTTPException(status_code=401, detail="Invalid Stripe API key")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
```

**Action Items**:
- [ ] Create `StripeConnector` class
- [ ] Implement charge and invoice fetching
- [ ] Create connector endpoint
- [ ] Add Stripe API key to config
- [ ] Test with Stripe test API key

---

### Task 6: Sample Datasets

**Goal**: Create realistic sample datasets for testing

**Revenue Sample** (`data/samples/revenue_sample.csv`):
```csv
date,amount,customer_id,status,payment_method
2024-01-01,1500.00,CUST001,paid,credit_card
2024-01-02,2300.50,CUST002,paid,stripe
2024-01-03,890.00,CUST003,failed,credit_card
...
```

**Marketing Sample** (`data/samples/marketing_sample.csv`):
```csv
date,campaign,source,leads,conversions,spend
2024-01-01,Winter Sale,Google Ads,150,12,500.00
2024-01-02,Winter Sale,Facebook,200,18,450.00
...
```

**Action Items**:
- [ ] Create sample revenue CSV (100+ rows)
- [ ] Create sample marketing CSV (100+ rows)
- [ ] Create sample with missing data (for validation testing)
- [ ] Create sample with incorrect formats (for error testing)
- [ ] Document sample datasets in README

---

## Acceptance Criteria

### Phase 1 is complete when:

1. **File Upload**:
   - [ ] Can upload CSV files successfully
   - [ ] Can upload Excel files successfully
   - [ ] File size limits are enforced

2. **Schema Detection**:
   - [ ] Automatically detects column data types
   - [ ] Identifies numeric, date, string, boolean columns
   - [ ] Returns sample values for each column

3. **Validation**:
   - [ ] Catches empty files
   - [ ] Identifies missing required columns
   - [ ] Detects data quality issues
   - [ ] Provides helpful error messages
   - [ ] Suggests fixes for common issues

4. **SaaS Integration**:
   - [ ] Can connect to Stripe API
   - [ ] Fetches charges/invoices successfully
   - [ ] Handles API errors gracefully

5. **Data Storage**:
   - [ ] Saves data source metadata to database
   - [ ] Stores schema information
   - [ ] Stores validation results

6. **Testing**:
   - [ ] Unit tests for schema detection
   - [ ] Unit tests for validation
   - [ ] Integration test for full upload flow
   - [ ] Tests with sample datasets

---

## Next Steps

After completing Phase 1, proceed to:
- **Phase 2**: Deterministic Analytics Layer

---

*Last Updated: 2025-11-19*
