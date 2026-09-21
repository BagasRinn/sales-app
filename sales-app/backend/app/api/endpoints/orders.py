from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks, Query
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import text
from uuid import UUID
from datetime import datetime, timedelta, timezone
from uuid import uuid4
from typing import List, Optional

from app.models.database import get_db
from app.models.models import Order, OrderItem, Product, User
from app.schemas.schemas import (
    OrderCreate,
    OrderResponse,
    OrderListWithItemsResponse,
)
from app.core.security import require_admin, require_auth, CurrentUser
from app.services.stock_logger import log_stock_change

router = APIRouter(prefix="/orders", tags=["Orders"])


# ==================== SALES ENDPOINTS ====================

@router.post("", response_model=OrderResponse)
def create_order(
    order_req: OrderCreate,
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_auth),
):
    if not order_req.items:
        raise HTTPException(status_code=400, detail="Pesanan harus memiliki minimal 1 item")

    pending_bookings = []
    for item in order_req.items:
        result = db.execute(
            text(
                "UPDATE products "
                "SET stok_booking = stok_booking + :qty "
                "WHERE id = :product_id AND (stok_sistem - stok_booking) >= :qty "
                "RETURNING id"
            ),
            {"product_id": item.product_id, "qty": item.qty},
        ).first()

        if result is None:
            db.rollback()
            product = db.query(Product).filter(Product.id == item.product_id).first()
            if not product:
                detail = f"Produk '{item.product_id}' tidak ditemukan"
            else:
                available = max(0, (product.stok_sistem or 0) - (product.stok_booking or 0))
                detail = (
                    f"Stok tidak mencukupi untuk produk '{item.product_id}'. "
                    f"Tersedia: {available}, Diminta: {item.qty}"
                )
            raise HTTPException(status_code=409, detail=detail)

        product = db.query(Product).filter(Product.id == item.product_id).first()
        if product:
            old_booking = (product.stok_booking or 0) - item.qty
            log_stock_change(
                db=db,
                product_id=item.product_id,
                sumber="CHECKOUT",
                field_terdampak="stok_booking",
                delta=item.qty,
                nilai_sebelum=old_booking,
                nilai_sesudah=product.stok_booking,
                actor_id=UUID(current_user["user_id"]),
                order_id=None,
            )
        pending_bookings.append(item)

    order = Order(
        id=uuid4(),
        sales_id=UUID(current_user["user_id"]),
        status="PENDING",
        created_at=datetime.now(timezone.utc),
        expired_at=datetime.now(timezone.utc) + timedelta(hours=24),
        store_name=order_req.store_name,
        store_contact=order_req.store_contact,
        store_address=order_req.store_address,
    )
    db.add(order)

    for item in pending_bookings:
        order_item = OrderItem(
            id=uuid4(),
            order_id=order.id,
            product_id=item.product_id,
            qty=item.qty,
        )
        db.add(order_item)

    db.commit()
    db.refresh(order)

    background_tasks.add_task(_sync_order_to_sheets, str(order.id))

    return OrderResponse.model_validate(order)


def _sync_order_to_sheets(order_id: str):
    from app.services.sheets_sync import append_new_order_to_sheets
    from app.models.database import SessionLocal

    session = SessionLocal()
    try:
        append_new_order_to_sheets(order_id, session)
    except Exception as e:
        print(f"[SHEETS SYNC ERROR] Order {order_id}: {e}")
    finally:
        session.close()


@router.get("/my", response_model=List[OrderListWithItemsResponse])
def get_my_orders(
    status_filter: Optional[str] = Query(None, alias="status"),
    skip: int = 0,
    limit: int = 50,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_auth),
):
    query = db.query(Order).filter(
        Order.sales_id == UUID(current_user["user_id"])
    )
    if status_filter:
        query = query.filter(Order.status == status_filter.upper())

    orders = query.order_by(Order.created_at.desc()).offset(skip).limit(limit).all()
    return [OrderListWithItemsResponse.model_validate(o) for o in orders]


@router.post("/{order_id}/cancel")
def cancel_order(
    order_id: UUID,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_auth),
):
    order = (
        db.query(Order)
        .filter(
            Order.id == order_id,
            Order.sales_id == UUID(current_user["user_id"]),
        )
        .with_for_update()
        .first()
    )

    if not order:
        raise HTTPException(status_code=404, detail="Pesanan tidak ditemukan")

    if order.status != "PENDING":
        raise HTTPException(
            status_code=400,
            detail=(
                f"Tidak dapat membatalkan pesanan dengan status '{order.status}'. "
                "Hanya pesanan berstatus PENDING yang dapat dibatalkan."
            ),
        )

    try:
        items = db.query(OrderItem).filter(OrderItem.order_id == order_id).all()
        for item in items:
            product = (
                db.query(Product)
                .filter(Product.id == item.product_id)
                .with_for_update()
                .first()
            )
            if product:
                old_booking = product.stok_booking or 0
                product.stok_booking = max(0, old_booking - item.qty)

                log_stock_change(
                    db=db,
                    product_id=item.product_id,
                    sumber="CANCEL",
                    field_terdampak="stok_booking",
                    delta=-item.qty,
                    nilai_sebelum=old_booking,
                    nilai_sesudah=product.stok_booking,
                    actor_id=UUID(current_user["user_id"]),
                    order_id=order.id,
                )

        order.status = "CANCELLED"
        db.commit()
    except Exception:
        db.rollback()
        raise

    return {
        "message": "Pesanan berhasil dibatalkan",
        "order_id": str(order.id),
        "status": "CANCELLED",
    }


# ==================== ADMIN ENDPOINTS ====================

def _build_order_response(order: Order) -> dict:
    items_data = []
    for item in order.items:
        harga_satuan = 0
        nama_barang = ""
        if item.product:
            harga_satuan = item.product.harga or 0
            nama_barang = item.product.nama_barang or ""
        items_data.append({
            "id": item.id,
            "product_id": item.product_id,
            "qty": item.qty,
            "harga_satuan": harga_satuan,
            "nama_barang": nama_barang,
        })
    return {
        "id": order.id,
        "sales_id": order.sales_id,
        "sales_username": order.sales.username if order.sales else None,
        "status": order.status,
        "created_at": order.created_at,
        "expired_at": order.expired_at,
        "items": items_data,
        "store_name": order.store_name,
        "store_contact": order.store_contact,
        "store_address": order.store_address,
    }


@router.get("/pending")
def list_pending_orders(
    skip: int = 0,
    limit: int = 50,
    db: Session = Depends(get_db),
    _current_user: CurrentUser = Depends(require_admin),
):
    orders = (
        db.query(Order)
        .options(
            joinedload(Order.items).joinedload(OrderItem.product),
            joinedload(Order.sales),
        )
        .filter(Order.status == "PENDING")
        .order_by(Order.created_at.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )
    return [_build_order_response(o) for o in orders]


@router.get("")
def list_all_orders(
    status_filter: Optional[str] = Query(None, alias="status"),
    skip: int = 0,
    limit: int = 50,
    db: Session = Depends(get_db),
    _current_user: CurrentUser = Depends(require_admin),
):
    query = db.query(Order).options(
        joinedload(Order.items).joinedload(OrderItem.product),
        joinedload(Order.sales),
    )
    if status_filter:
        query = query.filter(Order.status == status_filter.upper())

    orders = query.order_by(Order.created_at.desc()).offset(skip).limit(limit).all()
    return [_build_order_response(o) for o in orders]


@router.get("/{order_id}", response_model=OrderResponse)
def get_order_detail(
    order_id: UUID,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_auth),
):
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Pesanan tidak ditemukan")

    if current_user["role"] != "ADMIN":
        if str(order.sales_id) != current_user["user_id"]:
            raise HTTPException(status_code=403, detail="Tidak memiliki akses ke pesanan ini")

    return OrderResponse.model_validate(order)


@router.post("/{order_id}/approve")
def approve_order(
    order_id: UUID,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_admin),
):
    order = db.query(Order).filter(Order.id == order_id).with_for_update(of=[Order]).first()
    if not order:
        raise HTTPException(status_code=404, detail="Pesanan tidak ditemukan")

    if order.status != "PENDING":
        raise HTTPException(
            status_code=400,
            detail=f"Pesanan sudah berstatus '{order.status}', tidak dapat di-approve",
        )

    items = db.query(OrderItem).filter(OrderItem.order_id == order_id).all()

    for item in items:
        product = db.query(Product).filter(Product.id == item.product_id).with_for_update().first()
        if not product:
            raise HTTPException(
                status_code=404,
                detail=f"Produk '{item.product_id}' tidak ditemukan",
            )

        old_sistem = product.stok_sistem or 0
        old_booking = product.stok_booking or 0

        product.stok_sistem = max(0, old_sistem - item.qty)
        product.stok_booking = max(0, old_booking - item.qty)

        log_stock_change(
            db=db,
            product_id=item.product_id,
            sumber="APPROVE",
            field_terdampak="stok_sistem",
            delta=-item.qty,
            nilai_sebelum=old_sistem,
            nilai_sesudah=product.stok_sistem,
            actor_id=UUID(current_user["user_id"]),
            order_id=order.id,
        )
        log_stock_change(
            db=db,
            product_id=item.product_id,
            sumber="APPROVE",
            field_terdampak="stok_booking",
            delta=-item.qty,
            nilai_sebelum=old_booking,
            nilai_sesudah=product.stok_booking,
            actor_id=UUID(current_user["user_id"]),
            order_id=order.id,
        )

    order.status = "APPROVED"
    db.commit()

    return {
        "message": "Pesanan berhasil di-approve",
        "order_id": str(order.id),
        "status": "APPROVED",
    }


@router.post("/{order_id}/reject")
def reject_order(
    order_id: UUID,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_admin),
):
    order = db.query(Order).filter(Order.id == order_id).with_for_update(of=[Order]).first()
    if not order:
        raise HTTPException(status_code=404, detail="Pesanan tidak ditemukan")

    if order.status != "PENDING":
        raise HTTPException(
            status_code=400,
            detail=f"Pesanan sudah berstatus '{order.status}', tidak dapat di-reject",
        )

    items = db.query(OrderItem).filter(OrderItem.order_id == order_id).all()

    for item in items:
        product = db.query(Product).filter(Product.id == item.product_id).with_for_update().first()
        if product:
            old_booking = product.stok_booking or 0
            product.stok_booking = max(0, old_booking - item.qty)

            log_stock_change(
                db=db,
                product_id=item.product_id,
                sumber="REJECT",
                field_terdampak="stok_booking",
                delta=-item.qty,
                nilai_sebelum=old_booking,
                nilai_sesudah=product.stok_booking,
                actor_id=UUID(current_user["user_id"]),
                order_id=order.id,
            )

    order.status = "REJECTED"
    db.commit()

    return {
        "message": "Pesanan berhasil di-reject",
        "order_id": str(order.id),
        "status": "REJECTED",
    }
