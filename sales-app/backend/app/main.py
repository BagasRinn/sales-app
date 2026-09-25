import logging
import os
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from apscheduler.schedulers.asyncio import AsyncIOScheduler

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger(__name__)

from app.models.database import engine
from app.models.models import Base
from app.api.endpoints import auth, products, orders, customers, users, reports


scheduler = AsyncIOScheduler()


def expire_pending_orders():
    from sqlalchemy.orm import Session
    from app.models.models import Order, OrderItem, Product
    from app.services.stock_logger import log_stock_change
    from datetime import datetime, timezone
    from uuid import UUID

    db = Session(bind=engine)
    try:
        expired = (
            db.query(Order)
            .filter(Order.status == "PENDING", Order.expired_at < datetime.now(timezone.utc))
            .with_for_update(skip_locked=True, of=Order)
            .all()
        )

        if not expired:
            return

        # Batch-fetch all items and products to eliminate N+1
        order_ids = [o.id for o in expired]
        all_items = db.query(OrderItem).filter(OrderItem.order_id.in_(order_ids)).all()
        items_by_order = {}
        for item in all_items:
            items_by_order.setdefault(item.order_id, []).append(item)

        all_product_ids = [item.product_id for item in all_items]
        products = {
            p.id: p for p in
            db.query(Product).filter(Product.id.in_(all_product_ids)).with_for_update().all()
        }

        for order in expired:
            try:
                items = items_by_order.get(order.id, [])
                for item in items:
                    product = products.get(item.product_id)
                    if product:
                        old_booking = product.stok_booking or 0
                        product.stok_booking = max(0, old_booking - item.qty)
                        log_stock_change(
                            db=db,
                            product_id=item.product_id,
                            sumber="EXPIRE",
                            field_terdampak="stok_booking",
                            delta=-item.qty,
                            nilai_sebelum=old_booking,
                            nilai_sesudah=product.stok_booking,
                            actor_id=None,
                            order_id=order.id,
                        )
                order.status = "EXPIRED"
                db.commit()
                logger.info(f"[AUTO-EXPIRE] Order {order.id} expired and booking released.")
            except Exception as inner_e:
                db.rollback()
                logger.error(f"[AUTO-EXPIRE] Failed to expire order {order.id}: {inner_e}")

        logger.info(f"[AUTO-EXPIRE] Processed {len(expired)} expired orders.")
    except Exception as e:
        db.rollback()
        print(f"[AUTO-EXPIRE] Error: {e}")
    finally:
        db.close()


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
        scheduler.add_job(expire_pending_orders, "interval", minutes=5, id="auto_expire")
        scheduler.start()
        logger.info("[STARTUP] Auto-expire scheduler started.")
    else:
        logger.info("[STARTUP] RUN_SCHEDULER disabled — auto-expire will not run in this process.")
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
app.include_router(users.router, prefix="/api/v1")
app.include_router(reports.router, prefix="/api/v1")


@app.get("/")
def read_root():
    return {"message": "Sistem Offline-Sync Sales Berjalan Normal", "version": "1.1"}


@app.get("/health")
def health_check():
    return {"status": "healthy"}
