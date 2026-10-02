import logging
import os
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)

from app.models.database import engine
from app.models.models import Base
from app.api.endpoints import auth, products, orders, customers, customer_submissions, users, reports, sales_targets, bulletins
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


@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(bind=engine)
    if os.getenv("SEED_DEMO_USERS", "false").lower() == "true":
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


app = FastAPI(
    title="API Manajemen Order Sales",
    version="1.1",
    lifespan=lifespan,
)

_allowed_origins = os.getenv("CORS_ORIGINS", "").split(",")
if not _allowed_origins or _allowed_origins == [""]:
    _allowed_origins = ["*"]  # dev fallback — set CORS_ORIGINS in production

app.add_middleware(
    CORSMiddleware,
    allow_origins=_allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix="/api/v1")
app.include_router(products.router, prefix="/api/v1")
app.include_router(orders.router, prefix="/api/v1")
app.include_router(customers.router, prefix="/api/v1")
app.include_router(customer_submissions.router, prefix="/api/v1")
app.include_router(users.router, prefix="/api/v1")
app.include_router(reports.router, prefix="/api/v1")
app.include_router(sales_targets.router, prefix="/api/v1")
app.include_router(bulletins.router, prefix="/api/v1")


@app.get("/")
def read_root():
    return {"message": "Sistem Offline-Sync Sales Berjalan Normal", "version": "1.1"}


@app.get("/health")
def health_check():
    return {"status": "healthy"}
