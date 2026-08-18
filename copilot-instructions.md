# Healthcare Patient Management System - AI Agent Instructions

## Project Overview

4-student academic distributed system project implementing FHIR-compatible microservices for healthcare management. Current branch: `billing-service` (student 4). **Core principle**: Demonstrate architectural trade-offs over perfect implementation.

This is a **microservices-based healthcare system** with 4 independent services implementing a database-per-service pattern. The project follows a phased deployment strategy: local development → docker-compose → Kubernetes with monitoring.

## Architecture

### Microservices (Database-per-Service Pattern)

- **Patient Service** (8001): PostgreSQL - Demographics, medical history
- **Appointment Service** (8002): PostgreSQL - Scheduling, availability
- **Prescription Service** (8003): MongoDB - Clinical records (flexible schema)
- **Billing Service** (8004): PostgreSQL - Invoicing, payments, claims

**Reference implementation**: `services/billing-service/` - use as template for consistency.

Each service owns its database. Cross-service data access via REST APIs (sync) or RabbitMQ events (async). See `docs/adr/ADR-001-database-per-service.md` for trade-offs.

### Communication Patterns (Hybrid)

- **Synchronous REST**: User-facing queries, data validation (e.g., verify patient exists before appointment). Example: `services/billing-service/service.py:verify_patient_exists()`

- **Asynchronous RabbitMQ**: Event notifications, background tasks (e.g., appointment.created → billing generates invoice). Publisher: `common/messaging/rabbitmq_publisher.py`. Consumer: `common/messaging/rabbitmq_consumer.py`

Key insight: Use sync for immediate responses, async for decoupled workflows. See `docs/adr/ADR-002-communication-patterns.md`.

### Authentication (ADR-003)

- **JWT tokens** validated at Kong API Gateway (centralized)
- Patient Service acts as authentication service
- Services trust pre-validated tokens from gateway
- Token structure in `common/auth/jwt_handler.py`

### Shared Components (`common/`)

- `auth/jwt_handler.py`: JWT validation (no API gateway during local dev)
- `logging/logger_config.py`: structlog with JSON output (no emojis, minimal logging)
- `messaging/`: RabbitMQ publisher/consumer with aio-pika
- `exceptions/custom_exceptions.py`: Domain-specific errors (e.g., `InvoiceNotFoundError`)
- `middleware/error_handler.py`: Global FastAPI exception handlers
- `models/shared_types.py`: FHIR-compatible Pydantic types (e.g., `Money`)
- `utils/retry.py`: Tenacity decorators for DB/API retries

## Tech Stack & Standards

**Core**: Python 3.11, FastAPI, SQLAlchemy, aio-pika, structlog, Tenacity
**Infra**: Docker (python:3.11-slim), Kubernetes (planned), RabbitMQ (4.0-management-alpine), PostgreSQL (17-alpine), Redis (8-alpine)
**Tools**: pipenv (Pipfile/Pipfile.lock), pytest, pylint, black
**No emojis, no ELK stack, no external payment gateways** (keep scope manageable)

### File Patterns

- `services/<service>/main.py`: FastAPI app with lifespan, middleware, Prometheus metrics
- `services/<service>/api.py`: Route handlers
- `services/<service>/service.py`: Business logic
- `services/<service>/models.py`: SQLAlchemy ORM (PostgreSQL) or PyMongo (MongoDB)
- `services/<service>/schemas.py`: Pydantic models (FHIR R4 compatible, see `FHIRIntegration.md`)
- `services/<service>/config.py`: pydantic-settings with `.env` support
- `services/<service>/database.py`: DB connection/session management
- `services/<service>/dependencies.py`: FastAPI dependencies (e.g., `get_db`, JWT)

**Shared code**: `common/` directory (auth, logging, messaging, exceptions, utils)

### Docstring Format

reStructuredText (Sphinx-style):

```python
def create_invoice(data: InvoiceCreate) -> Invoice:
    """
    Create new invoice from appointment.

    :param data: Invoice creation payload
    :return: Created invoice with generated UUID
    :raises AppointmentNotFoundError: If appointment doesn't exist
    """
```

### Error Handling

- Raise custom exceptions from `common/exceptions` (e.g., `InvoiceNotFoundError`)
- Global handlers in `common/middleware/error_handler.py` convert to JSON responses
- Use Tenacity retry decorators for transient failures (DB, API calls)

## Development Workflow

### Independent Service Development (CRITICAL)

**Each student works on their own branch** and must be able to build/run their service independently:

1. **Leverage shared infrastructure**: Use `common/` (auth, logging, messaging, exceptions), `kong/`, `monitoring/` without modification
2. **No cross-branch dependencies**: Service must run standalone with only its database + RabbitMQ/Redis
3. **Follow billing-service pattern**: Use `services/billing-service/` as reference implementation
4. **Test isolation**: Each service has `tests/<service>/` with own fixtures and test DB

### Running Locally (Before Docker)

```bash
# Setup environment (from repo root)
pipenv install --dev
pipenv shell

# Configure service
cd services/<your-service>
cp .env.example .env  # Edit database URLs, JWT_SECRET, service port

# Run migrations (if using Alembic)
alembic upgrade head

# Start service (runs independently)
python main.py  # or: uvicorn main:app --host 0.0.0.0 --port 800X --reload
```

**Service must start without errors even if other services are offline** (graceful degradation for external API calls).

### Docker Compose (Phase 2 - Current)

```bash
# Start infrastructure + billing service
docker-compose up -d rabbitmq redis billing-db billing-service

# View logs
docker-compose logs -f billing-service

# Test health
curl http://localhost:8004/health

# Access docs
open http://localhost:8004/docs
```

### Testing

```bash
# Unit tests (services/<service>/ level)
pytest tests/billing/test_service.py -v

# Integration tests (mock external services)
pytest tests/billing/test_integration.py -v

# With coverage
pytest --cov=services/billing-service --cov-report=html
```

Test fixtures in `tests/billing/conftest.py` provide:

- Test DB engine (separate `billing_test_db`)
- FastAPI TestClient with dependency overrides
- Sample data factories (invoices, payments)

- **Unit tests**: Business logic in `service.py` (mock external calls)
- **Integration tests**: API endpoints with TestClient (mock DB)
- **E2E tests**: Docker Compose with real infrastructure

## FHIR Compatibility

Models align with FHIR R4 resources (Invoice, Patient, Appointment, Claim). Key fields:

- `resource_type`: Always set (e.g., "Invoice")
- `status`: Use enums (e.g., `InvoiceStatusEnum.ISSUED`)
- `subject`: Patient reference (patient_id)
- `meta`: JSONB column for FHIR metadata

See `FHIRIntegration.md` for complete schemas. **Slight deviations acceptable** if justified in ADR.

- Patient: HumanName, ContactPoint, Address
- Appointment: status, participant, serviceType
- Invoice: status, lineItem, totalNet/totalGross
- MedicationRequest: medication, dosageInstruction

**Note**: Not full FHIR compliance, but compatible schema structure for future extension.

## Critical Conventions

1. **No code comments unless essential** - Remove existing comments during edits unless they explain complex logic
2. **Logging**: JSON format via structlog, log errors with full stack traces, use structured fields (no strings like "Error occurred")
3. **Minimal scope changes**: Edit only files directly related to feature/fix
4. **ADRs required**: Document significant decisions (database choice, communication patterns, etc.) in `docs/adr/`
5. **Non-root containers**: Dockerfile runs as `appuser:1000`, sets `runAsNonRoot: true` in Kubernetes
6. **Multi-stage builds**: Separate builder (gcc, build deps) from production (libpq5, curl only)
7. **Health checks**: `/health` endpoint queries DB connection, used by Docker healthcheck and Kubernetes probes

## Common Commands

```bash
# Add package to all services
pipenv install <package>

# Format code
black services/billing-service/

# Lint
pylint services/billing-service/*.py

# Reset Docker volumes (WARNING: destroys data)
docker-compose down -v

# Init database
docker exec -it healthcare-billing-db psql -U postgres -d billing_db

# Publish RabbitMQ event (Python)
from common.messaging.rabbitmq_publisher import publish_event
await publish_event("billing.invoice.created", {"invoice_id": "..."})
```

## Phase Context

**Phase 1** ✅: Local dev, core features, unit tests
**Phase 2** ✅: Dockerization, docker-compose integration
**Phase 3** ✅: Kubernetes manifests, Prometheus/Grafana (Billing service deployed)

**Current Phase (Post-Implementation Fixes & Finalization)**:

The project is successfully implemented and working. We're now completing final fixes and deployment:

1. **Circuit Breaker Pattern** ✅ - Add resilience/fault tolerance to inter-service communication
2. **Client UI Fixes** ✅ - Fix prescription creation form in Next.js client
3. **Sample Data Generation** ✅ - Update init\_\*\_db.sh scripts to load realistic test data from Mockaroo
4. **MongoDB Migration** ✅ - Migrate prescription-service from Mongo 6 to Mongo 8.2
5. **CI/CD & Deployment** ✅ - GitHub Actions for unit tests, SonarCloud analysis, Azure AKS deployment
6. **Unit Test Fixes** 🔄 - Fix Pydantic validation errors in test suite (current)
7. **Frontend Deployment** 📋 - Deploy Next.js client to Azure App Service
8. **Full CI/CD Pipeline** 📋 - Complete GitHub Actions for all services + frontend

**Working Approach**: Tackle each task step-by-step with actionable sub-tasks. Break complex items into smaller changes.

## Key Files for Context

- `DraftImplementation.md`: Billing service implementation plan (3 phases)
- `FHIRIntegration.md`: FHIR schemas for all services
- `HealthcareSystemRoadmap.md`: 3-week project timeline
- `docker-compose.yml`: Full infrastructure setup (8 databases, 4 services, RabbitMQ, Redis)
- `docs/adr/*.md`: Architectural decisions with trade-off analysis
- `docs/PHASE3_IMPLEMENTATION_SUMMARY.md`: Kubernetes deployment (Billing service)
- `COMP41720 Group Project Rubric.txt`: Assessment criteria (40% justification, 40% correctness)

## Post-Implementation Enhancement Tasks

### Task 1: Circuit Breaker Pattern (Resilience) ✅

**Status**: Complete - Circuit breaker implemented using `pybreaker` library

### Task 2: Client UI - Prescription Form Fix ✅

**Status**: Complete - Fixed decimal handling and form validation

### Task 3: Sample Data Generation ✅

**Status**: Complete - Mockaroo CSV data integrated into init scripts

### Task 4: MongoDB Migration (Mongo 6 → 8.2) ✅

**Status**: Complete - All services using MongoDB 8.2

### Task 5: CI/CD & Azure AKS Deployment ✅

**Status**: Complete - GitHub Actions workflows operational

### Task 6: Unit Test Fixes ✅

**Status**: Core issue resolved - Tests now connect to databases successfully

**Problem**: Pydantic validation errors due to environment variable mismatch between root `.env` (docker-compose/K8s variables) and service `config.py` files

**Solution Implemented**:

1. ✅ Added `extra='ignore'` to all service `config.py` Pydantic Config classes
2. ✅ Updated `scripts/run_local_tests.sh` to use correct Docker database credentials
3. ✅ Modified test `conftest.py` files to read `DATABASE_URL` from environment
4. ✅ Automatic test database creation in Docker containers

**Results**: Patient service - 15/42 tests passing, 90% coverage

**Remaining Work**:

- Fix test data isolation (DuplicateResourceError)
- Mock async `publish_event()` calls in sync tests
- Apply fixes to appointment, prescription, billing services

**Documentation**: See `docs/UNIT_TEST_FIXES_SUMMARY.md` for complete details

**Files Changed**:

- `services/*/config.py` (all 4 services)
- `tests/*/conftest.py` (all 4 services)
- `scripts/run_local_tests.sh`

### Task 7: Frontend Deployment (Azure App Service)

**Goal**: Deploy Next.js client to Azure App Service with GitHub Actions

**Requirements**:

- Build Next.js app for production
- Deploy to Azure App Service (Linux, Node.js 20)
- Environment variables for backend API URLs
- GitHub Actions workflow for CD

**Configuration**:

- Service: Azure App Service (Free/Basic tier)
- Runtime: Node.js 20 LTS
- Environment: `NEXT_PUBLIC_API_URL` pointing to Kong gateway
- Build command: `npm run build`
- Start command: `npm run start`

**Deliverables**:

- `.github/workflows/deploy-frontend.yml`
- Azure App Service configuration
- Documentation in `docs/FRONTEND_DEPLOYMENT.md`

### Task 8: Complete CI/CD Pipeline

**Goal**: Unified pipeline for testing, building, and deploying all components

**Components**:

1. **Unit Tests** - Run on PR/push for all services
2. **SonarCloud** - Code quality gates
3. **Security Scans** - Snyk/Trivy for vulnerabilities
4. **Docker Builds** - Multi-arch images to GHCR
5. **Backend Deploy** - Azure AKS (4 microservices)
6. **Frontend Deploy** - Azure App Service
7. **E2E Tests** - Post-deployment smoke tests

**Workflows**:

- `test.yml` - PR validation (unit tests, linting)
- `sonarcloud.yml` - Code quality analysis
- `build.yml` - Docker image builds
- `deploy-aks.yml` - Backend deployment to AKS
- `deploy-frontend.yml` - Frontend deployment to App Service
- `e2e.yml` - End-to-end testing

**Success Criteria**:

- All tests pass on every PR
- Automated deployment on merge to main
- Rollback capability for failed deployments
- Monitoring and alerting configured

## Implementation Notes

**Circuit Breaker Context**:

- Current retry logic: `common/utils/retry.py:retry_on_api_error()` - 3 attempts, exponential backoff
- Used in: `services/*/service.py:verify_patient_exists()`, `get_appointment_details()`
- ADR-002 mentions circuit breakers as best practice but not yet implemented
- Need to track circuit state across requests (in-memory or Redis)

**MongoDB 8.2 Features**:

- Improved time-series collections (relevant for prescription history)
- Enhanced aggregation pipeline
- Better queryable encryption (HIPAA compliance consideration)

**Client Stack**:

- Next.js 14 (App Router)
- TypeScript
- React Hook Form + Zod validation
- TanStack Query (React Query) for API calls
- Tailwind CSS for styling

## Building a New Service (Step-by-Step)

1. **Create branch**: `git checkout -b <service-name>-service` from main
2. **Copy billing-service structure**: Use as template for file organization
3. **Reuse shared code**: Import from `common/` (auth, logging, messaging, exceptions, middleware, utils)
4. **Configure independently**:
   - Unique port (8001/8002/8003/8004)
   - Own database (see `docker-compose.yml` for DB naming)
   - Own `.env` file with service-specific config
5. **Implement core files**:
   - `main.py`: FastAPI app with lifespan, middleware, Prometheus metrics
   - `api.py`: Route handlers with OpenAPI docs
   - `service.py`: Business logic (NOT in routes)
   - `models.py`: SQLAlchemy/PyMongo models
   - `schemas.py`: Pydantic request/response schemas
   - `config.py`: pydantic-settings configuration
   - `database.py`: DB connection management
   - `dependencies.py`: FastAPI dependencies
   - `Dockerfile`: Multi-stage build (copy from billing-service, update paths)
6. **Test independently**: Create `tests/<service>/conftest.py` with test DB fixtures
7. **Document decisions**: Add ADR in `docs/adr/` if making architectural choices
8. **Verify isolation**: Service runs with only its DB + RabbitMQ/Redis (no other services needed)

## Bash Scripts for Reusability

All database initialization and management scripts in `scripts/` must work across:

1. Local development (direct postgres connection)
2. Docker Compose (via docker-entrypoint-initdb.d)
3. Kubernetes (via init containers or Jobs)

Use environment variables for portability: `${POSTGRES_USER:-postgres}`, `${POSTGRES_DB:-billing_db}`

## Gotchas

- **Independent service requirement**: Each student must be able to run their service standalone without other services running (only DB + RabbitMQ/Redis needed)
- **Common directory usage**: Import from `common/` but never modify shared code without team consensus
- **JWT validation**: Currently in each service, will move to Kong API Gateway (Phase 3)
- **Eventual consistency**: RabbitMQ events may arrive out-of-order, design idempotent consumers
- **Docker context**: Dockerfile builds from repo root (needs `common/` directory accessible)
- **Database ports**: Each service DB on unique port (5432-5435, 27017) - see `docker-compose.yml`
- **Pipenv in Docker**: Install system-wide (`pipenv install --system`) to avoid virtualenv overhead
- **Service ports**: 8001 (patient), 8002 (appointment), 8003 (prescription), 8004 (billing) - hardcoded in config
