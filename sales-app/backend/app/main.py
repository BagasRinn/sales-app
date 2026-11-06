import logging
import os
import sys
from contextlib import asynccontextmanager
from datetime import datetime
from zoneinfo import ZoneInfo
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware

class _TZFormatter(logging.Formatter):
    def converter(self, timestamp):
        return datetime.fromtimestamp(timestamp, tz=ZoneInfo("Asia/Makassar")).timetuple()

    def formatTime(self, record, datefmt=None):
        dt = datetime.fromtimestamp(record.created, tz=ZoneInfo("Asia/Makassar"))
        if datefmt:
            return dt.strftime(datefmt)
        return dt.isoformat()

_tz_formatter = _TZFormatter(
    fmt="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)

handler = logging.StreamHandler(sys.stdout)
handler.setFormatter(_tz_formatter)

logging.basicConfig(
    level=logging.INFO,
    handlers=[handler],
)
logger = logging.getLogger(__name__)

from app.models.database import engine
from app.models.models import Base
from app.api.endpoints import auth, products, orders, customers, customer_submissions, users, reports, sales_targets, bulletins, sales, branches, supplier_targets, suppliers, sales_imports
from app.api.endpoints.bulletins_scheduler import expire_bulletins, reset_all_bulletins

from apscheduler.schedulers.asyncio import AsyncIOScheduler
scheduler = AsyncIOScheduler()


def seed_initial_data():
    from sqlalchemy.orm import Session
    from app.models.models import User
    from app.core.security import get_password_hash

    db = Session(bind=engine)
    try:
        if db.query(User).filter(User.role == "ADMIN").count() == 0:
            admin = User(
                username="admin",
                password_hash=get_password_hash("admin"),
                role="ADMIN",
            )
            db.add(admin)
            db.commit()
            logger.info("[SEED] Admin user created: admin / admin")
        if db.query(User).filter(User.role == "SALES").count() == 0:
            sales = User(
                username="sales",
                password_hash=get_password_hash("sales"),
                role="SALES",
            )
            db.add(sales)
            db.commit()
            logger.info("[SEED] Sales user created: sales / sales")
    except Exception as e:
        db.rollback()
        logger.error(f"[SEED] Warning: {e}")
    finally:
        db.close()


def _ensure_imported_sales_index() -> None:
    """Create the (branch, sale_date) index on existing deployments.

    The project has no Alembic; ``Base.metadata.create_all()`` skips tables
    that already exist, so a newly declared index on ``imported_sales`` would
    never reach production. This idempotent DDL is cheap and safe to run on
    every startup.
    """
    from sqlalchemy import text

    try:
        with engine.begin() as conn:
            conn.execute(text(
                "CREATE INDEX IF NOT EXISTS ix_imported_sales_branch_sale_date "
                "ON imported_sales (branch, sale_date)"
            ))
    except Exception as e:  # pragma: no cover - startup must not fail hard
        logger.warning("[STARTUP] Could not ensure imported_sales index: %s", e)


def _ensure_imported_sales_dedupe_key() -> None:
    """Add the dedupe column + unique index on existing deployments.

    Same rationale as ``_ensure_imported_sales_index``: the project has no
    Alembic, so ``create_all`` will not alter an existing table. Both
    statements are idempotent and safe on every startup. Existing rows keep
    ``dedupe_key = NULL`` (allowed by the unique index) until the lazy
    migration or ``scripts/backfill_sales_dedupe_keys.py`` fills them.
    """
    from sqlalchemy import text

    try:
        with engine.begin() as conn:
            conn.execute(text(
                "ALTER TABLE imported_sales "
                "ADD COLUMN IF NOT EXISTS dedupe_key VARCHAR(64)"
            ))
            conn.execute(text(
                "CREATE UNIQUE INDEX IF NOT EXISTS "
                "uq_imported_sales_dedupe_key "
                "ON imported_sales (dedupe_key)"
            ))
    except Exception as e:  # pragma: no cover - startup must not fail hard
        logger.warning(
            "[STARTUP] Could not ensure imported_sales dedupe key: %s", e
        )


def _demo_seed_allowed() -> bool:
    """Demo user seeding hanya boleh jalan di lingkungan non-produksi.

    Dua syarat harus terpenuhi:
    1. SEED_DEMO_USERS=true (default false)
    2. ENVIRONMENT bukan 'production'/'prod' (kalau variabelnya diset)

    Tujuannya mencegah akun demo berpassword lemah (admin/admin) ikut
    terbuat kalau flag ini tidak sengaja diaktifkan di server produksi.
    """
    if os.getenv("SEED_DEMO_USERS", "false").lower() != "true":
        return False
    environment = (os.getenv("ENVIRONMENT") or "").strip().lower()
    if environment in ("production", "prod"):
        logger.error(
            "[SEED] SEED_DEMO_USERS=true diabaikan karena ENVIRONMENT=production. "
            "Akun demo tidak dibuat."
        )
        return False
    return True


@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(bind=engine)
    _ensure_imported_sales_index()
    _ensure_imported_sales_dedupe_key()
    # Load branch labels/names from DB into in-memory cache. Falls back to
    # hardcoded constants if the branches table doesn't exist yet (pre-migration).
    from app.core import branch as branch_constants
    branch_constants.load_branches_cache()
    if _demo_seed_allowed():
        seed_initial_data()
    else:
        logger.info("[STARTUP] SEED_DEMO_USERS not enabled — skipping demo user seeding.")

    run_scheduler = os.getenv("RUN_SCHEDULER", "true").lower() == "true"
    if run_scheduler:
        scheduler.add_job(expire_bulletins, "cron", hour=0, minute=5, timezone="Asia/Makassar", id="expire_bulletins")
        scheduler.add_job(reset_all_bulletins, "cron", day=1, hour=0, minute=10, timezone="Asia/Makassar", id="reset_all_bulletins")
        scheduler.start()
        logger.info("[STARTUP] Scheduler started.")
    else:
        logger.info("[STARTUP] RUN_SCHEDULER disabled — scheduler will not run in this process.")
    yield
    if run_scheduler:
        scheduler.shutdown()
        logger.info("[SHUTDOWN] Scheduler stopped.")


_environment = (os.getenv("ENVIRONMENT") or "").strip().lower()
_is_production = _environment in ("production", "prod")

app = FastAPI(
    title="API Manajemen Order Sales",
    version="1.1",
    lifespan=lifespan,
    # Interactive docs and the OpenAPI schema are development aids; keep them
    # off in production so the full API surface is not advertised.
    docs_url=None if _is_production else "/docs",
    redoc_url=None if _is_production else "/redoc",
    openapi_url=None if _is_production else "/openapi.json",
)

_allowed_origins = [
    origin.strip()
    for origin in os.getenv("CORS_ORIGINS", "").split(",")
    if origin.strip()
]
if not _allowed_origins:
    logger.warning(
        "[CORS] CORS_ORIGINS is unset — no origins allowed. "
        "Web app cannot reach the API until CORS_ORIGINS is set. "
        "Set CORS_ORIGINS env var to your web app origin(s) (comma-separated)."
    )
else:
    logger.info(f"[CORS] Allowed origins: {_allowed_origins}")

app.add_middleware(
    CORSMiddleware,
    allow_origins=_allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["X-Total-Count"],
)

app.add_middleware(GZipMiddleware, minimum_size=500)


@app.middleware("http")
async def add_security_headers(request, call_next):
    """Baseline security headers for every response."""
    response = await call_next(request)
    response.headers.setdefault("X-Content-Type-Options", "nosniff")
    response.headers.setdefault("X-Frame-Options", "DENY")
    response.headers.setdefault("Referrer-Policy", "no-referrer")
    response.headers.setdefault(
        "Permissions-Policy", "geolocation=(), microphone=(), camera=()"
    )
    if _is_production:
        response.headers.setdefault(
            "Strict-Transport-Security", "max-age=31536000; includeSubDomains"
        )
    return response


app.include_router(auth.router, prefix="/api/v1")
app.include_router(products.router, prefix="/api/v1")
app.include_router(orders.router, prefix="/api/v1")
app.include_router(customers.router, prefix="/api/v1")
app.include_router(customer_submissions.router, prefix="/api/v1")
app.include_router(users.router, prefix="/api/v1")
app.include_router(reports.router, prefix="/api/v1")
app.include_router(sales_targets.router, prefix="/api/v1")
app.include_router(bulletins.router, prefix="/api/v1")
app.include_router(sales.router, prefix="/api/v1")
app.include_router(branches.router, prefix="/api/v1")
app.include_router(supplier_targets.router, prefix="/api/v1")
app.include_router(suppliers.router, prefix="/api/v1")
app.include_router(sales_imports.router, prefix="/api/v1")


@app.get("/")
def read_root():
    return {"message": "API Manajemen Order Sales berjalan normal", "version": "1.1"}


@app.get("/health")
def health_check():
    return {"status": "healthy"}


@app.get("/v1/models")
def list_models():
    return {"models": []}
