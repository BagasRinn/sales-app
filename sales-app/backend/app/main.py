import os
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from apscheduler.schedulers.asyncio import AsyncIOScheduler

from app.models.database import engine
from app.models.models import Base
from app.api.endpoints import auth, products, orders


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
            .all()
        )

        if not expired:
            return

        for order in expired:
            items = db.query(OrderItem).filter(OrderItem.order_id == order.id).all()
            for item in items:
                product = db.query(Product).filter(Product.id == item.product_id).first()
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
            print(f"[AUTO-EXPIRE] Order {order.id} expired and booking released.")

        print(f"[AUTO-EXPIRE] Processed {len(expired)} expired orders.")
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
            print("[SEED] Admin user created: admin / admin")
        if db.query(User).filter(User.role == "SALES").count() == 0:
            sales = User(
                username="sales",
                password_hash=get_password_hash("sales"),
                role="SALES",
            )
            db.add(sales)
            db.commit()
            print("[SEED] Sales user created: sales / sales")
    except Exception as e:
        db.rollback()
        print(f"[SEED] Warning: {e}")
    finally:
        db.close()


@asynccontextmanager
async def lifespan(app: FastAPI):
    Base.metadata.create_all(bind=engine)
    seed_initial_data()
    scheduler.add_job(expire_pending_orders, "interval", minutes=5, id="auto_expire")
    scheduler.start()
    print("[STARTUP] Auto-expire scheduler started.")
    yield
    scheduler.shutdown()
    print("[SHUTDOWN] Scheduler stopped.")


app = FastAPI(
    title="API Manajemen Order Sales",
    version="1.1",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix="/api/v1")
app.include_router(products.router, prefix="/api/v1")
app.include_router(orders.router, prefix="/api/v1")


@app.get("/")
def read_root():
    return {"message": "Sistem Offline-Sync Sales Berjalan Normal", "version": "1.1"}


@app.get("/health")
def health_check():
    return {"status": "healthy"}
