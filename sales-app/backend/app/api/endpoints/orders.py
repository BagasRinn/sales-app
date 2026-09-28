from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks, Query, Response
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import text, func, case
from uuid import UUID
from datetime import datetime, timedelta, timezone
from uuid import uuid4
from typing import List, Optional
import logging

from app.models.database import get_db
from app.models.models import Order, OrderItem, Product, Customer
from app.schemas.schemas import (
    OrderCreate,
    OrderResponse,
    OrderListWithItemsResponse,
    OrderDiscountUpdate,
)
from app.core.security import require_admin, require_manager, require_auth, CurrentUser
from app.services.stock_logger import log_stock_change

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/orders", tags=["Orders"])


def _get_customer(customer_id, db):
    customer = db.query(Customer).filter(
        Customer.id == customer_id,
        Customer.deleted_at.is_(None),
    ).first()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer tidak ditemukan")
    return customer


def _build_order_response(order: Order) -> dict:
    items_data = []
    total_amount = 0
    total_discount = 0

    for item in order.items:
        harga_satuan = item.product.harga if item.product else 0
        qty = item.qty or 0
        raw_subtotal = harga_satuan * qty

        discount_type = (item.discount_type or 'PERCENT').upper()
        discount_percent = item.discount_percent or 0
        discount_nominal = item.discount_nominal or 0

        if discount_type == 'NOMINAL':
            # Diskon nominal (IDR) per-subtotal: potong sekali di akhir.
            # Nominal di-cap supaya tidak melebihi raw_subtotal (tidak boleh minus).
            nominal_diskon = min(discount_nominal, raw_subtotal)
            subtotal = raw_subtotal - nominal_diskon
            harga_setelah = subtotal / qty if qty > 0 else 0
        else:
            # Diskon persen — % dari subtotal, baru dikali qty
            nominal_diskon = int(round(raw_subtotal * discount_percent / 100))
            subtotal = raw_subtotal - nominal_diskon
            harga_setelah = subtotal / qty if qty > 0 else 0

        items_data.append({
            "id": item.id,
            "product_id": item.product_id,
            "qty": qty,
            "harga_satuan": harga_satuan,
            "nama_barang": item.product.nama_barang if item.product else "",
            "discount_type": discount_type,
            "discount_percent": discount_percent if discount_type == 'PERCENT' else 0,
            "discount_nominal": discount_nominal if discount_type == 'NOMINAL' else 0,
            "harga_setelah_diskon": int(harga_setelah),
            "subtotal": subtotal,
        })
        total_amount += subtotal
        total_discount += nominal_diskon

    return {
        "id": order.id,
        "sales_id": order.sales_id,
        "sales_username": order.sales.username if order.sales else None,
        "sales_nama": order.sales.nama if order.sales else None,
        "customer_id": order.customer_id,
        "customer_name": order.customer.nama_toko if order.customer else None,
        "status": order.status,
        "notes": order.notes,
        "created_at": order.created_at,
        "expired_at": order.expired_at,
        "items": items_data,
        "store_name": order.store_name,
        "store_contact": order.store_contact,
        "store_address": order.store_address,
        "total_amount": int(total_amount),
        "total_discount": int(total_discount),
    }


def _sync_order_to_sheets(order_id: str):
    logger.info(f"[SHEETS SYNC] Order {order_id} submitted (sheets sync disabled)")


def _book_items(items, db, sales_id, order_id_for_log):
    """Apply stok_booking for given items. Raises 409 if insufficient."""
    for item in items:
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
                actor_id=sales_id,
                order_id=order_id_for_log,
            )


# ==================== SALES ENDPOINTS ====================

@router.post("", response_model=OrderResponse)
def create_order(
    order_req: OrderCreate,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_auth),
):
    if not order_req.items:
        raise HTTPException(status_code=400, detail="Pesanan harus memiliki minimal 1 item")

    sales_id = UUID(current_user["user_id"])
    customer = _get_customer(order_req.customer_id, db)

    # DRAFT tidak booking stok. Validasi stok saja (cek tersedia), tapi tidak kurangi stok_booking.
    # Booking baru dilakukan saat submit_draft_order.
    for item in order_req.items:
        product = db.query(Product).filter(Product.id == item.product_id).first()
        if not product:
            raise HTTPException(
                status_code=404,
                detail=f"Produk '{item.product_id}' tidak ditemukan",
            )
        available = max(0, (product.stok_sistem or 0) - (product.stok_booking or 0))
        if item.qty > available:
            raise HTTPException(
                status_code=409,
                detail=(
                    f"Stok tidak cukup untuk '{product.nama_barang}'. "
                    f"Tersedia: {available}, Diminta: {item.qty}"
                ),
            )

    order = Order(
        id=uuid4(),
        sales_id=sales_id,
        customer_id=customer.id,
        status="DRAFT",
        created_at=datetime.now(timezone.utc),
        notes=order_req.notes,
        store_name=customer.nama_toko,
        store_contact=None,
        store_address=customer.alamat,
    )
    db.add(order)

    for item in order_req.items:
        discount_type = (item.discount_type or 'PERCENT').upper()
        if discount_type not in ('PERCENT', 'NOMINAL'):
            raise HTTPException(status_code=400, detail="discount_type tidak valid")

        if discount_type == 'NOMINAL':
            product = db.query(Product).filter(Product.id == item.product_id).first()
            harga_satuan = (product.harga or 0) if product else 0
            max_nominal = harga_satuan * item.qty
            if item.discount_nominal > max_nominal:
                raise HTTPException(
                    status_code=400,
                    detail=f"Diskon nominal untuk produk '{product.nama_barang if product else item.product_id}' "
                           f"melebihi subtotal ({max_nominal})",
                )

        db.add(OrderItem(
            id=uuid4(),
            order_id=order.id,
            product_id=item.product_id,
            qty=item.qty,
            discount_type=discount_type,
            discount_percent=item.discount_percent if discount_type == 'PERCENT' else 0,
            discount_nominal=item.discount_nominal if discount_type == 'NOMINAL' else 0,
        ))

    db.commit()
    db.refresh(order)

    # DRAFT tidak di-sync ke sheets. Sync hanya saat submit.
    return _build_order_response(order)


@router.get("/my", response_model=List[OrderListWithItemsResponse])
def get_my_orders(
    status_filter: Optional[str] = Query(None, alias="status"),
    skip: int = 0,
    limit: int = 50,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_auth),
):
    query = db.query(Order).options(
        joinedload(Order.items).joinedload(OrderItem.product),
        joinedload(Order.customer),
    ).filter(
        Order.sales_id == UUID(current_user["user_id"])
    )
    if status_filter:
        query = query.filter(Order.status == status_filter.upper())

    orders = query.order_by(Order.created_at.desc()).offset(skip).limit(limit).all()
    return [_build_order_response(o) for o in orders]


@router.get("/my/stats")
def get_my_stats(
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_auth),
):
    """Sales dashboard stats — computed in WITA (UTC+8) timezone."""
    sales_id = UUID(current_user["user_id"])
    WITA = timezone(timedelta(hours=8))
    now_wita = datetime.now(WITA)
    start_of_day_wita = now_wita.replace(hour=0, minute=0, second=0, microsecond=0)
    end_of_day_wita = start_of_day_wita + timedelta(days=1)
    start_of_month_wita = now_wita.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
    start_of_day_utc = start_of_day_wita.astimezone(timezone.utc)
    end_of_day_utc = end_of_day_wita.astimezone(timezone.utc)
    start_of_month_utc = start_of_month_wita.astimezone(timezone.utc)

    omset_today = (
        db.query(func.coalesce(func.sum(
            # Untuk PERCENT: harga * (100-pct)/100. Untuk NOMINAL: (harga - nom)*qty.
            # SQLite tidak punya CASE WHEN yang sama persis di semua backend — kita pakai
            # ekspresi generatif via func.ifnull + case.
            func.coalesce(OrderItem.qty, 0) * func.coalesce(Product.harga, 0)
            - func.coalesce(
                case(
                    (OrderItem.discount_type == 'NOMINAL',
                     func.coalesce(OrderItem.discount_nominal, 0) * func.coalesce(OrderItem.qty, 0)),
                    else_=func.coalesce(OrderItem.qty, 0) * func.coalesce(Product.harga, 0)
                         * func.coalesce(OrderItem.discount_percent, 0) / 100,
                ), 0
            )
        ), 0))
        .join(Order, Order.id == OrderItem.order_id)
        .join(Product, Product.id == OrderItem.product_id)
        .filter(
            Order.sales_id == sales_id,
            Order.status == "APPROVED",
            Order.created_at >= start_of_day_utc,
            Order.created_at < end_of_day_utc,
        )
        .scalar()
    )

    pending_count = db.query(func.count(Order.id)).filter(
        Order.sales_id == sales_id,
        Order.status == "PENDING",
    ).scalar() or 0

    selesai_count = db.query(func.count(Order.id)).filter(
        Order.sales_id == sales_id,
        Order.status == "APPROVED",
        Order.created_at >= start_of_month_utc,
    ).scalar() or 0

    selesai_total = (
        db.query(func.coalesce(func.sum(
            func.coalesce(OrderItem.qty, 0) * func.coalesce(Product.harga, 0)
            - func.coalesce(
                case(
                    (OrderItem.discount_type == 'NOMINAL',
                     func.coalesce(OrderItem.discount_nominal, 0) * func.coalesce(OrderItem.qty, 0)),
                    else_=func.coalesce(OrderItem.qty, 0) * func.coalesce(Product.harga, 0)
                         * func.coalesce(OrderItem.discount_percent, 0) / 100,
                ), 0
            )
        ), 0))
        .join(Order, Order.id == OrderItem.order_id)
        .join(Product, Product.id == OrderItem.product_id)
        .filter(
            Order.sales_id == sales_id,
            Order.status == "APPROVED",
            Order.created_at >= start_of_month_utc,
        )
        .scalar()
    )

    return {
        "omset_hari_ini": int(omset_today or 0),
        "pending_count": int(pending_count),
        "selesai_bulan_ini_count": int(selesai_count),
        "selesai_bulan_ini_total": int(selesai_total or 0),
    }


@router.put("/{order_id}")
def update_draft_order(
    order_id: UUID,
    order_update: OrderCreate,
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
    if order.status != "DRAFT":
        raise HTTPException(
            status_code=400,
            detail=f"Hanya pesanan berstatus DRAFT yang bisa diedit. Status saat ini: {order.status}",
        )

    if not order_update.items:
        raise HTTPException(status_code=400, detail="Pesanan harus memiliki minimal 1 item")

    sales_id = UUID(current_user["user_id"])
    customer = _get_customer(order_update.customer_id, db)

    # Hapus item lama, replace dengan item baru
    db.query(OrderItem).filter(OrderItem.order_id == order.id).delete()
    for item in order_update.items:
        discount_type = (item.discount_type or 'PERCENT').upper()
        if discount_type not in ('PERCENT', 'NOMINAL'):
            raise HTTPException(status_code=400, detail="discount_type tidak valid")
        if discount_type == 'NOMINAL':
            product = db.query(Product).filter(Product.id == item.product_id).first()
            harga_satuan = (product.harga or 0) if product else 0
            max_nominal = harga_satuan * item.qty
            if item.discount_nominal > max_nominal:
                raise HTTPException(
                    status_code=400,
                    detail=f"Diskon nominal untuk produk '{product.nama_barang if product else item.product_id}' "
                           f"melebihi subtotal ({max_nominal})",
                )
        db.add(OrderItem(
            id=uuid4(),
            order_id=order.id,
            product_id=item.product_id,
            qty=item.qty,
            discount_type=discount_type,
            discount_percent=item.discount_percent if discount_type == 'PERCENT' else 0,
            discount_nominal=item.discount_nominal if discount_type == 'NOMINAL' else 0,
        ))

    order.customer_id = customer.id
    order.notes = order_update.notes
    order.store_name = customer.nama_toko
    order.store_contact = None
    order.store_address = customer.alamat

    db.commit()
    db.refresh(order)
    return _build_order_response(order)


@router.post("/{order_id}/submit")
def submit_draft_order(
    order_id: UUID,
    background_tasks: BackgroundTasks,
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
    if order.status != "DRAFT":
        raise HTTPException(
            status_code=400,
            detail=f"Hanya pesanan DRAFT yang bisa di-submit. Status saat ini: {order.status}",
        )

    items = db.query(OrderItem).filter(OrderItem.order_id == order_id).all()
    if not items:
        raise HTTPException(status_code=400, detail="Pesanan harus memiliki minimal 1 item")

    # Apply stok booking
    _book_items(items, db, UUID(current_user["user_id"]), order.id)

    order.status = "PENDING"
    order.expired_at = datetime.now(timezone.utc) + timedelta(hours=24)
    db.commit()
    db.refresh(order)

    # Sync ke sheets
    background_tasks.add_task(_sync_order_to_sheets, str(order.id))

    return _build_order_response(order)


@router.delete("/{order_id}", status_code=204)
def delete_draft_order(
    order_id: UUID,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_auth),
):
    order = db.query(Order).filter(
        Order.id == order_id,
        Order.sales_id == UUID(current_user["user_id"]),
    ).first()
    if not order:
        raise HTTPException(status_code=404, detail="Pesanan tidak ditemukan")
    if order.status != "DRAFT":
        raise HTTPException(
            status_code=400,
            detail=f"Hanya pesanan DRAFT yang bisa dihapus. Status saat ini: {order.status}",
        )
    db.delete(order)
    db.commit()
    return None


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
        product_ids = [item.product_id for item in items]
        products = {
            p.id: p for p in
            db.query(Product).filter(Product.id.in_(product_ids)).with_for_update().all()
        }

        for item in items:
            product = products.get(item.product_id)
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

@router.get("/pending")
def list_pending_orders(
    skip: int = 0,
    limit: int = 50,
    db: Session = Depends(get_db),
    _current_user: CurrentUser = Depends(require_manager),
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
    response: Response,
    status_filter: Optional[str] = Query(None, alias="status"),
    date_from: Optional[str] = Query(
        None,
        description="Tanggal mulai (YYYY-MM-DD, WITA). Filter created_at >= date_from 00:00 WITA.",
    ),
    date_to: Optional[str] = Query(
        None,
        description="Tanggal akhir inklusif (YYYY-MM-DD, WITA). Filter created_at < (date_to+1) 00:00 WITA.",
    ),
    skip: int = 0,
    limit: int = 50,
    db: Session = Depends(get_db),
    _current_user: CurrentUser = Depends(require_manager),
):
    """List semua pesanan dengan filter status + rentang tanggal (WITA).
    date_from/date_to opsional — kalau dua-duanya kosong, semua pesanan.
    Set header X-Total-Count untuk pagination di client.
    """
    query = db.query(Order).options(
        joinedload(Order.items).joinedload(OrderItem.product),
        joinedload(Order.sales),
    )
    count_query = db.query(Order)
    if status_filter:
        query = query.filter(Order.status == status_filter.upper())
        count_query = count_query.filter(Order.status == status_filter.upper())

    if date_from or date_to:
        # WITA timezone biar konsisten dengan sales app
        wita = timezone(timedelta(hours=8))
        if date_from:
            try:
                from_date = datetime.strptime(date_from, "%Y-%m-%d").date()
            except ValueError:
                raise HTTPException(
                    status_code=400,
                    detail="date_from harus berformat YYYY-MM-DD",
                )
            start_wita = datetime.combine(from_date, datetime.min.time()).replace(tzinfo=wita)
            start_utc = start_wita.astimezone(timezone.utc)
            query = query.filter(Order.created_at >= start_utc)
            count_query = count_query.filter(Order.created_at >= start_utc)
        if date_to:
            try:
                to_date = datetime.strptime(date_to, "%Y-%m-%d").date()
            except ValueError:
                raise HTTPException(
                    status_code=400,
                    detail="date_to harus berformat YYYY-MM-DD",
                )
            end_wita_exclusive = datetime.combine(
                to_date + timedelta(days=1), datetime.min.time()
            ).replace(tzinfo=wita)
            end_utc = end_wita_exclusive.astimezone(timezone.utc)
            query = query.filter(Order.created_at < end_utc)
            count_query = count_query.filter(Order.created_at < end_utc)

    total = count_query.count()
    response.headers["X-Total-Count"] = str(total)
    orders = query.order_by(Order.created_at.desc()).offset(skip).limit(limit).all()
    return [_build_order_response(o) for o in orders]


@router.get("/{order_id}", response_model=OrderResponse)
def get_order_detail(
    order_id: UUID,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_auth),
):
    order = (
        db.query(Order)
        .options(
            joinedload(Order.items).joinedload(OrderItem.product),
            joinedload(Order.customer),
            joinedload(Order.sales),
        )
        .filter(Order.id == order_id)
        .first()
    )
    if not order:
        raise HTTPException(status_code=404, detail="Pesanan tidak ditemukan")

    if current_user["role"] not in ("ADMIN", "MANAGER"):
        if str(order.sales_id) != current_user["user_id"]:
            raise HTTPException(status_code=403, detail="Tidak memiliki akses ke pesanan ini")

    return _build_order_response(order)


@router.put("/{order_id}/discounts", response_model=OrderResponse)
def update_discounts(
    order_id: UUID,
    body: OrderDiscountUpdate,
    db: Session = Depends(get_db),
    _current_user: CurrentUser = Depends(require_admin),
):
    """Update diskon per item — admin only, hanya untuk pesanan PENDING."""
    order = (
        db.query(Order)
        .options(joinedload(Order.items).joinedload(OrderItem.product))
        .filter(Order.id == order_id)
        .with_for_update(of=[Order])
        .first()
    )
    if not order:
        raise HTTPException(status_code=404, detail="Pesanan tidak ditemukan")
    if order.status != "PENDING":
        raise HTTPException(
            status_code=400,
            detail=f"Diskon hanya bisa diedit saat status PENDING. Status saat ini: {order.status}",
        )

    # Map item_id -> OrderItem
    item_map = {str(item.id): item for item in order.items}

    for update_item in body.items:
        order_item = item_map.get(str(update_item.item_id))
        if not order_item:
            raise HTTPException(
                status_code=404,
                detail=f"Item '{update_item.item_id}' tidak ditemukan di pesanan ini",
            )

        discount_type = update_item.discount_type.upper()
        if discount_type not in ('PERCENT', 'NOMINAL'):
            raise HTTPException(status_code=400, detail="discount_type tidak valid")

        order_item.discount_type = discount_type
        if discount_type == 'NOMINAL':
            # Cap nominal at subtotal item (harga × qty) supaya tidak minus
            harga_satuan = order_item.product.harga if order_item.product else 0
            qty = order_item.qty or 0
            max_nominal = harga_satuan * qty
            order_item.discount_nominal = min(update_item.discount_nominal, max_nominal)
            order_item.discount_percent = 0
        else:
            order_item.discount_percent = min(update_item.discount_percent, 100)
            order_item.discount_nominal = 0

    db.commit()
    db.refresh(order)
    return _build_order_response(order)


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
    product_ids = [item.product_id for item in items]
    products = {
        p.id: p for p in
        db.query(Product).filter(Product.id.in_(product_ids)).with_for_update().all()
    }

    for item in items:
        product = products.get(item.product_id)
        if not product:
            raise HTTPException(
                status_code=404,
                detail=f"Produk '{item.product_id}' tidak ditemukan",
            )
        # Approve: stok_booking TIDAK disentuh — tetap sebagai record barang yang sudah
        # dibooking/terkirim. Stok_tersedia = stok_sistem - stok_booking tetap konsisten.

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
    product_ids = [item.product_id for item in items]
    products = {
        p.id: p for p in
        db.query(Product).filter(Product.id.in_(product_ids)).with_for_update().all()
    }

    for item in items:
        product = products.get(item.product_id)
        if product:
            old_booking = product.stok_booking or 0
            # Reject dari PENDING: booking dilepas (stok kembali tersedia).
            # Kalau approve sudah dipanggil duluan, stok_booking sudah 0
            # (approve memindahkan dari pending ke sent), reject tidak perlu ngapa-ngapain.
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
