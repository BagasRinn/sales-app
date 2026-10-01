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


# ==================== 3-LAYER DISCOUNT HELPERS ====================

# Tiap layer = (type, percent, nominal). Type 'PERCENT' | 'NOMINAL'.
# Kalkulasi sequential: tiap layer dipotong dari sisa running subtotal.

def _layer_cut(type_val: str, percent: int, nominal: int, running: int) -> int:
    """Potongan untuk 1 layer. NOMINAL di-cap ke running; PERCENT dari running."""
    if type_val == "NOMINAL":
        return min(max(0, nominal), running)
    # PERCENT
    return int(round(running * max(0, percent) / 100))


def _apply_3_layers(
    raw_subtotal: int,
    layer1_type: str, layer1_percent: int, layer1_nominal: int,
    layer2_type: str, layer2_percent: int, layer2_nominal: int,
    layer3_type: str, layer3_percent: int, layer3_nominal: int,
):
    """Chain 3 layers sequential. Return (final_subtotal, layer1_cut, layer2_cut, layer3_cut, total_cut)."""
    s = max(0, raw_subtotal)
    d1 = _layer_cut(layer1_type, layer1_percent, layer1_nominal, s)
    s -= d1
    d2 = _layer_cut(layer2_type, layer2_percent, layer2_nominal, s)
    s -= d2
    d3 = _layer_cut(layer3_type, layer3_percent, layer3_nominal, s)
    s -= d3
    return s, d1, d2, d3, d1 + d2 + d3


def _normalize_layer(type_val: str | None, percent: int | None, nominal: int | None):
    """Coerce nullable inputs from DB rows to a clean (type, percent, nominal) tuple."""
    t = (type_val or "PERCENT").upper()
    return t, percent or 0, nominal or 0


def _layer_cut_sql(type_col, percent_col, nominal_col, base):
    """SQLAlchemy case expression: cut amount untuk 1 layer, di-clamp ke base.
    NOMINAL: min(nominal, base). PERCENT: round(base * percent / 100)."""
    nominal_cut = case(
        (func.coalesce(nominal_col, 0) <= base, func.coalesce(nominal_col, 0)),
        else_=base,
    )
    percent_cut = func.round(base * func.coalesce(percent_col, 0) / 100)
    return case((type_col == "NOMINAL", nominal_cut), else_=percent_cut)


def _build_order_response(order: Order) -> dict:
    items_data = []
    total_amount = 0
    total_discount = 0

    for item in order.items:
        harga_satuan = item.product.harga if item.product else 0
        qty = item.qty or 0
        raw_subtotal = harga_satuan * qty

        l1 = _normalize_layer(item.discount_type, item.discount_percent, item.discount_nominal)
        l2 = _normalize_layer(item.discount2_type, item.discount2_percent, item.discount2_nominal)
        l3 = _normalize_layer(item.discount3_type, item.discount3_percent, item.discount3_nominal)

        subtotal, d1, d2, d3, _ = _apply_3_layers(
            raw_subtotal,
            *l1, *l2, *l3,
        )
        harga_setelah = subtotal / qty if qty > 0 else 0

        items_data.append({
            "id": item.id,
            "product_id": item.product_id,
            "qty": qty,
            "harga_satuan": harga_satuan,
            "nama_barang": item.product.nama_barang if item.product else "",
            # Layer 1
            "discount_type": l1[0],
            "discount_percent": l1[1] if l1[0] == "PERCENT" else 0,
            "discount_nominal": l1[2] if l1[0] == "NOMINAL" else 0,
            # Layer 2
            "discount2_type": l2[0],
            "discount2_percent": l2[1] if l2[0] == "PERCENT" else 0,
            "discount2_nominal": l2[2] if l2[0] == "NOMINAL" else 0,
            # Layer 3
            "discount3_type": l3[0],
            "discount3_percent": l3[1] if l3[0] == "PERCENT" else 0,
            "discount3_nominal": l3[2] if l3[0] == "NOMINAL" else 0,
            # Derived
            "harga_setelah_diskon": int(harga_setelah),
            "subtotal": subtotal,
        })
        total_amount += subtotal
        total_discount += d1 + d2 + d3

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
        "order_type": order.order_type or 'REGULER',
    }


def _sync_order_to_sheets(order_id: str):
    logger.info(f"[SHEETS SYNC] Order {order_id} submitted (sheets sync disabled)")


def _rebalance_booking(db, sales_id, order_id, old_items, new_items):
    """Adjust stok_booking untuk PENDING order setelah edit items.
    Hitung delta qty per produk antara old_items dan new_items (sum by product_id).
    Delta > 0: atomic add (perlu stock tersedia, raise 409 kalau tidak cukup).
    Delta < 0: release (tidak perlu check).
    Tulis StokLog dengan sumber "EDIT" untuk tiap delta yang bukan nol.
    """
    old_qty: dict[str, int] = {}
    for it in old_items:
        old_qty[it.product_id] = old_qty.get(it.product_id, 0) + (it.qty or 0)

    new_qty: dict[str, int] = {}
    for item in new_items:
        pid = item.product_id
        new_qty[pid] = new_qty.get(pid, 0) + item.qty

    all_pids = set(old_qty.keys()) | set(new_qty.keys())

    for pid in all_pids:
        delta = new_qty.get(pid, 0) - old_qty.get(pid, 0)
        if delta == 0:
            continue
        if delta > 0:
            # Tambah booking — perlu stock tersedia
            result = db.execute(
                text(
                    "UPDATE products "
                    "SET stok_booking = stok_booking + :delta "
                    "WHERE id = :pid AND (stok_sistem - stok_booking) >= :delta "
                    "RETURNING stok_booking"
                ),
                {"pid": pid, "delta": delta},
            ).first()
            if result is None:
                db.rollback()
                product = db.query(Product).filter(Product.id == pid).first()
                if not product:
                    raise HTTPException(
                        status_code=404,
                        detail=f"Produk '{pid}' tidak ditemukan",
                    )
                available = max(
                    0,
                    (product.stok_sistem or 0) - (product.stok_booking or 0),
                )
                raise HTTPException(
                    status_code=409,
                    detail=(
                        f"Stok tidak cukup untuk '{product.nama_barang}'. "
                        f"Tersedia: {available}, tambahan diminta: {delta}"
                    ),
                )
            new_booking = result[0]
            old_booking = new_booking - delta
            log_stock_change(
                db=db,
                product_id=pid,
                sumber="EDIT",
                field_terdampak="stok_booking",
                delta=delta,
                nilai_sebelum=old_booking,
                nilai_sesudah=new_booking,
                actor_id=sales_id,
                order_id=order_id,
            )
        else:
            # Kurangi booking (delta < 0, db akan auto-fail kalau stok_booking < abs_delta
            # karena ada CHECK constraint — seharusnya tidak terjadi karena kita kurangi
            # dari booking yang sebelumnya sudah kita tambahkan)
            abs_delta = -delta
            result = db.execute(
                text(
                    "UPDATE products "
                    "SET stok_booking = stok_booking - :delta "
                    "WHERE id = :pid "
                    "RETURNING stok_booking"
                ),
                {"pid": pid, "delta": abs_delta},
            ).first()
            new_booking = result[0]
            old_booking = new_booking + abs_delta
            log_stock_change(
                db=db,
                product_id=pid,
                sumber="EDIT",
                field_terdampak="stok_booking",
                delta=-abs_delta,
                nilai_sebelum=old_booking,
                nilai_sesudah=new_booking,
                actor_id=sales_id,
                order_id=order_id,
            )


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

    # Validasi order_type dulu sebelum loop items — gagal cepat kalau invalid.
    order_type = (order_req.order_type or 'REGULER').upper()
    if order_type not in ('REGULER', '4P'):
        raise HTTPException(
            status_code=400,
            detail=f"order_type tidak valid: {order_req.order_type}. Harus 'REGULER' atau '4P'.",
        )

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
        # Validasi tipe produk harus cocok dengan order_type.
        product_type = (product.order_type or 'REGULER').upper()
        if product_type != order_type:
            raise HTTPException(
                status_code=400,
                detail=(
                    f"Produk '{product.nama_barang}' bukan tipe {order_type} "
                    f"(tipe produk: {product_type})"
                ),
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
        order_type=order_type,
    )
    db.add(order)

    for item in order_req.items:
        layers = [
            (item.discount_type, item.discount_percent, item.discount_nominal),
            (item.discount2_type, item.discount2_percent, item.discount2_nominal),
            (item.discount3_type, item.discount3_percent, item.discount3_nominal),
        ]
        product = db.query(Product).filter(Product.id == item.product_id).first()
        harga_satuan = (product.harga or 0) if product else 0
        raw_subtotal = harga_satuan * item.qty

        for idx, (dt, dp, dn) in enumerate(layers, start=1):
            dt = (dt or "PERCENT").upper()
            if dt not in ("PERCENT", "NOMINAL"):
                raise HTTPException(status_code=400, detail=f"discount_type layer {idx} tidak valid")
            if dt == "NOMINAL" and dn and dn > raw_subtotal:
                raise HTTPException(
                    status_code=400,
                    detail=f"Diskon nominal layer {idx} untuk produk '{product.nama_barang if product else item.product_id}' "
                           f"melebihi subtotal ({raw_subtotal})",
                )

        l1, l2, l3 = layers
        db.add(OrderItem(
            id=uuid4(),
            order_id=order.id,
            product_id=item.product_id,
            qty=item.qty,
            # Layer 1
            discount_type=(l1[0] or "PERCENT").upper(),
            discount_percent=l1[1] if (l1[0] or "PERCENT").upper() == "PERCENT" else 0,
            discount_nominal=l1[2] if (l1[0] or "PERCENT").upper() == "NOMINAL" else 0,
            # Layer 2
            discount2_type=(l2[0] or "PERCENT").upper(),
            discount2_percent=l2[1] if (l2[0] or "PERCENT").upper() == "PERCENT" else 0,
            discount2_nominal=l2[2] if (l2[0] or "PERCENT").upper() == "NOMINAL" else 0,
            # Layer 3
            discount3_type=(l3[0] or "PERCENT").upper(),
            discount3_percent=l3[1] if (l3[0] or "PERCENT").upper() == "PERCENT" else 0,
            discount3_nominal=l3[2] if (l3[0] or "PERCENT").upper() == "NOMINAL" else 0,
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


def _three_layer_subtotal_expr():
    """SQL expression: (final_subtotal, total_discount) setelah chain 3 layer sequential.
    Dipakai di omset aggregation supaya SQL match Python calculation di _apply_3_layers."""
    raw = func.coalesce(OrderItem.qty, 0) * func.coalesce(Product.harga, 0)
    d1 = _layer_cut_sql(
        OrderItem.discount_type, OrderItem.discount_percent, OrderItem.discount_nominal, raw
    )
    after1 = raw - d1
    d2 = _layer_cut_sql(
        OrderItem.discount2_type, OrderItem.discount2_percent, OrderItem.discount2_nominal, after1
    )
    after2 = after1 - d2
    d3 = _layer_cut_sql(
        OrderItem.discount3_type, OrderItem.discount3_percent, OrderItem.discount3_nominal, after2
    )
    return after2 - d3, d1 + d2 + d3


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

    final_subtotal_expr, _ = _three_layer_subtotal_expr()

    omset_today = (
        db.query(func.coalesce(func.sum(final_subtotal_expr), 0))
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
        db.query(func.coalesce(func.sum(final_subtotal_expr), 0))
        .join(Order, Order.id == OrderItem.order_id)
        .join(Product, Product.id == OrderItem.product_id)
        .filter(
            Order.sales_id == sales_id,
            Order.status == "APPROVED",
            Order.created_at >= start_of_month_utc,
        )
        .scalar()
    )

    # Target untuk bulan ini
    current_period = f"{now_wita.year}-{now_wita.month:02d}"
    from app.models.models import SalesTarget
    target = (
        db.query(SalesTarget)
        .filter(SalesTarget.user_id == sales_id, SalesTarget.period == current_period)
        .first()
    )

    result = {
        "omset_hari_ini": int(omset_today or 0),
        "pending_count": int(pending_count),
        "selesai_bulan_ini_count": int(selesai_count),
        "selesai_bulan_ini_total": int(selesai_total or 0),
    }
    if target:
        result["target_type"] = target.target_type
        result["target_value"] = target.target_value
        result["incentive_amount"] = target.incentive_amount
        result["target_period"] = target.period
    return result


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
    if order.status not in ("DRAFT", "PENDING"):
        raise HTTPException(
            status_code=400,
            detail=(
                f"Pesanan hanya bisa diedit saat berstatus DRAFT atau PENDING. "
                f"Status saat ini: {order.status}"
            ),
        )

    if not order_update.items:
        raise HTTPException(status_code=400, detail="Pesanan harus memiliki minimal 1 item")

    # Validasi order_type (jika dikirim). Order existing mungkin punya tipe yg berbeda;
    # sales boleh ganti tipe, asal items baru cocok dgn tipe baru.
    new_order_type = (order_update.order_type or order.order_type or 'REGULER').upper()
    if new_order_type not in ('REGULER', '4P'):
        raise HTTPException(
            status_code=400,
            detail=f"order_type tidak valid: {order_update.order_type}. Harus 'REGULER' atau '4P'.",
        )

    sales_id = UUID(current_user["user_id"])

    # Lock OrderItem rows sebelum delete — defense against concurrent reads
    # yang tidak nge-lock Order. Order row sudah di-lock via with_for_update() di atas,
    # jadi approve/cancel/update_discounts dari concurrent caller akan blocking.
    old_items = (
        db.query(OrderItem)
        .filter(OrderItem.order_id == order.id)
        .with_for_update()
        .all()
    )

    customer = _get_customer(order_update.customer_id, db)

    # Validasi setiap item.product.order_type cocok dengan new_order_type.
    for item in order_update.items:
        product = db.query(Product).filter(Product.id == item.product_id).first()
        if not product:
            raise HTTPException(
                status_code=404,
                detail=f"Produk '{item.product_id}' tidak ditemukan",
            )
        product_type = (product.order_type or 'REGULER').upper()
        if product_type != new_order_type:
            raise HTTPException(
                status_code=400,
                detail=(
                    f"Produk '{product.nama_barang}' bukan tipe {new_order_type} "
                    f"(tipe produk: {product_type})"
                ),
            )

    # Hapus item lama, replace dengan item baru
    db.query(OrderItem).filter(OrderItem.order_id == order.id).delete()
    for item in order_update.items:
        layers = [
            (item.discount_type, item.discount_percent, item.discount_nominal),
            (item.discount2_type, item.discount2_percent, item.discount2_nominal),
            (item.discount3_type, item.discount3_percent, item.discount3_nominal),
        ]
        product = db.query(Product).filter(Product.id == item.product_id).first()
        harga_satuan = (product.harga or 0) if product else 0
        raw_subtotal = harga_satuan * item.qty

        for idx, (dt, dp, dn) in enumerate(layers, start=1):
            dt = (dt or "PERCENT").upper()
            if dt not in ("PERCENT", "NOMINAL"):
                raise HTTPException(status_code=400, detail=f"discount_type layer {idx} tidak valid")
            if dt == "NOMINAL" and dn and dn > raw_subtotal:
                raise HTTPException(
                    status_code=400,
                    detail=f"Diskon nominal layer {idx} untuk produk '{product.nama_barang if product else item.product_id}' "
                           f"melebihi subtotal ({raw_subtotal})",
                )

        l1, l2, l3 = layers
        db.add(OrderItem(
            id=uuid4(),
            order_id=order.id,
            product_id=item.product_id,
            qty=item.qty,
            discount_type=(l1[0] or "PERCENT").upper(),
            discount_percent=l1[1] if (l1[0] or "PERCENT").upper() == "PERCENT" else 0,
            discount_nominal=l1[2] if (l1[0] or "PERCENT").upper() == "NOMINAL" else 0,
            discount2_type=(l2[0] or "PERCENT").upper(),
            discount2_percent=l2[1] if (l2[0] or "PERCENT").upper() == "PERCENT" else 0,
            discount2_nominal=l2[2] if (l2[0] or "PERCENT").upper() == "NOMINAL" else 0,
            discount3_type=(l3[0] or "PERCENT").upper(),
            discount3_percent=l3[1] if (l3[0] or "PERCENT").upper() == "PERCENT" else 0,
            discount3_nominal=l3[2] if (l3[0] or "PERCENT").upper() == "NOMINAL" else 0,
        ))

    order.customer_id = customer.id
    order.notes = order_update.notes
    order.store_name = customer.nama_toko
    order.store_contact = None
    order.store_address = customer.alamat
    order.order_type = new_order_type

    # PENDING order sudah punya stok_booking terisi — rebalance setelah items berubah.
    # DRAFT ga punya booking, skip. Kalau rebalance raise 409, db.rollback() di helper
    # akan membatalkan semua perubahan (delete + insert + customer update) supaya
    # konsisten.
    if order.status == "PENDING":
        _rebalance_booking(
            db=db,
            sales_id=sales_id,
            order_id=order.id,
            old_items=old_items,
            new_items=order_update.items,
        )

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

        # Apply 3 layers sequential dengan cap di running residual.
        # Layer 1 NOMINAL di-cap ke raw_subtotal; layer 2/3 ke running residual setelah layer sebelumnya.
        harga_satuan = order_item.product.harga if order_item.product else 0
        qty = order_item.qty or 0
        raw_subtotal = harga_satuan * qty

        layers = [
            (update_item.discount_type, update_item.discount_percent, update_item.discount_nominal),
            (update_item.discount2_type, update_item.discount2_percent, update_item.discount2_nominal),
            (update_item.discount3_type, update_item.discount3_percent, update_item.discount3_nominal),
        ]
        running = raw_subtotal
        applied = []
        for dt, dp, dn in layers:
            dt = (dt or "PERCENT").upper()
            if dt not in ("PERCENT", "NOMINAL"):
                raise HTTPException(status_code=400, detail="discount_type tidak valid")
            if dt == "PERCENT":
                pct = min(max(0, dp), 100)
                applied.append((dt, pct, 0))
                running -= int(round(running * pct / 100))
            else:
                nom = min(max(0, dn), running)
                applied.append((dt, 0, nom))
                running -= nom

        # Setelah loop, `running` tidak dipakai lagi — yang penting applied list.
        # PERCENT percent column selalu berisi nilai percent (walau nominal yg aktif),
        # sesuai konvensi kolom.
        (t1, p1, n1), (t2, p2, n2), (t3, p3, n3) = applied
        order_item.discount_type = t1
        order_item.discount_percent = p1
        order_item.discount_nominal = n1
        order_item.discount2_type = t2
        order_item.discount2_percent = p2
        order_item.discount2_nominal = n2
        order_item.discount3_type = t3
        order_item.discount3_percent = p3
        order_item.discount3_nominal = n3

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
