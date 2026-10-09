"""Daily and period order reports — Excel export untuk admin & manager."""
from datetime import datetime, timedelta, timezone
from io import BytesIO
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import StreamingResponse
from openpyxl import Workbook
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.utils import get_column_letter
from sqlalchemy.orm import Session, joinedload

from app.models.database import get_db
from app.models.models import Order, OrderItem, Product, Customer, User, CustomerRegistrationSubmission
from app.core.security import require_admin_or_supervisor, require_manager_global, apply_branch_filter
from app.schemas.schemas import (
    SalesPerformanceResponse,
    SalesPerformanceItem,
    SalesPerformanceDashboardItem,
    SalesPerformanceDashboardResponse,
)

router = APIRouter(prefix="/reports", tags=["Reports"])


def _layer_cut_value(type_val: str, percent: int, nominal: int, running: int) -> int:
    """Potongan untuk 1 layer (sequential). NOMINAL di-cap ke running; PERCENT dari running."""
    if (type_val or "PERCENT").upper() == "NOMINAL":
        return min(max(0, nominal or 0), running)
    return int(round(running * max(0, min(100, percent or 0)) / 100))


def _three_layer_breakdown(item) -> tuple[int, int, int, int, int]:
    """Hitung chain 3 layers sequential. Return (total_sebelum, layer1_cut, layer2_cut, layer3_cut, total_setelah)."""
    harga_satuan = item.product.harga if item.product else 0
    qty = item.qty or 0
    raw = harga_satuan * qty
    s = max(0, raw)
    d1 = _layer_cut_value(item.discount_type, item.discount_percent, item.discount_nominal, s)
    s -= d1
    d2 = _layer_cut_value(item.discount2_type, item.discount2_percent, item.discount2_nominal, s)
    s -= d2
    d3 = _layer_cut_value(item.discount3_type, item.discount3_percent, item.discount3_nominal, s)
    s -= d3
    return raw, d1, d2, d3, s


def _build_report(
    orders,
    ws: Workbook.active,
    title: str,
) -> int:
    """Generate report rows dengan breakdown 3-layer discount. Returns row count."""
    ws.title = title

    headers = [
        "Kode Pelanggan",
        "Nama Pelanggan",
        "Kode Item",
        "Nama Item",
        "Qty",
        "Satuan",
        "Harga Satuan",
        "Total Harga Sebelum Diskon",
        "Diskon Layer 1",
        "Diskon Layer 2",
        "Diskon Layer 3",
        "Total Diskon",
        "Total Harga Setelah Diskon",
        "Tipe Order",
        "Nama Sales",
        "Supplier",
    ]
    ws.append(headers)

    header_font = Font(bold=True, color="FFFFFF")
    header_fill = PatternFill(start_color="1976D2", end_color="1976D2", fill_type="solid")
    for cell in ws[1]:
        cell.font = header_font
        cell.fill = header_fill
        cell.alignment = Alignment(horizontal="center", vertical="center")

    total_rows = 0
    for order in orders:
        customer = order.customer
        sales = order.sales
        sales_name = ""
        if sales:
            sales_name = sales.nama if (sales.nama and sales.nama.strip()) else (sales.username or "")
        for item in order.items:
            product = item.product
            harga_satuan = product.harga if product else 0
            qty = item.qty

            raw, d1, d2, d3, after = _three_layer_breakdown(item)
            total_diskon = d1 + d2 + d3

            ws.append([
                customer.kode if customer else "",
                customer.nama_toko if customer else "",
                item.product_id or "",
                product.nama_barang if product else "",
                qty,
                product.satuan if product else "",
                harga_satuan,
                raw,
                d1,
                d2,
                d3,
                total_diskon,
                after,
                order.order_type or 'REGULER',
                sales_name,
                product.nama_supplier if product else "",
            ])
            total_rows += 1

    # Auto-width columns
    widths = [16, 28, 14, 32, 6, 8, 14, 20, 14, 14, 14, 14, 20, 12, 20, 28]
    for i, w in enumerate(widths, 1):
        ws.column_dimensions[get_column_letter(i)].width = w

    return total_rows


@router.get("/daily")
def daily_report(
    date: str = Query(..., description="Tanggal laporan, format YYYY-MM-DD (WITA)"),
    status: str = Query(
        "APPROVED",
        description="Status filter, comma-separated. Default APPROVED.",
    ),
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_admin_or_supervisor),
):
    """Generate Excel laporan harian. Timezone mengikuti sales app (WITA/UTC+8).

    15 kolom: Kode/Nama Pelanggan, Kode/Nama Item, Qty, Satuan,
    Harga Satuan, Total Sebelum Diskon, Diskon Layer 1/2/3, Total Diskon,
    Total Setelah Diskon, Nama Sales, Supplier.
    """
    try:
        target_date = datetime.strptime(date, "%Y-%m-%d").date()
    except ValueError:
        raise HTTPException(status_code=400, detail="Format tanggal harus YYYY-MM-DD")

    statuses = [s.strip().upper() for s in status.split(",") if s.strip()]
    if not statuses:
        statuses = ["APPROVED"]

    wita = timezone(timedelta(hours=8))
    start_of_day = datetime.combine(target_date, datetime.min.time()).replace(tzinfo=wita)
    end_of_day = start_of_day + timedelta(days=1)
    start_utc = start_of_day.astimezone(timezone.utc)
    end_utc = end_of_day.astimezone(timezone.utc)

    orders = (
        db.query(Order)
        .options(
            joinedload(Order.items).joinedload(OrderItem.product),
            joinedload(Order.customer),
            joinedload(Order.sales),
        )
        .filter(
            Order.status.in_(statuses),
            Order.created_at >= start_utc,
            Order.created_at < end_utc,
        )
    )
    orders = apply_branch_filter(orders, Order, current_user)
    orders = orders.order_by(Order.created_at.asc()).all()

    wb = Workbook()
    ws = wb.active
    _build_report(orders, ws, f"Laporan {target_date.isoformat()}")

    buffer = BytesIO()
    wb.save(buffer)
    buffer.seek(0)

    filename = f"laporan-harian-{target_date.isoformat()}.xlsx"
    return StreamingResponse(
        buffer,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@router.get("/period")
def period_report(
    start_date: str = Query(..., description="Tanggal mulai, YYYY-MM-DD (WITA)"),
    end_date: str = Query(..., description="Tanggal akhir, YYYY-MM-DD (WITA)"),
    status: str = Query(
        "APPROVED",
        description="Status filter, comma-separated. Default APPROVED.",
    ),
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_admin_or_supervisor),
):
    """Generate Excel laporan berdasarkan rentang tanggal. Timezone WITA/UTC+8.

    15 kolom sama dengan laporan harian.
    """
    try:
        start = datetime.strptime(start_date, "%Y-%m-%d").date()
    except ValueError:
        raise HTTPException(status_code=400, detail="Format tanggal mulai harus YYYY-MM-DD")
    try:
        end = datetime.strptime(end_date, "%Y-%m-%d").date()
    except ValueError:
        raise HTTPException(status_code=400, detail="Format tanggal akhir harus YYYY-MM-DD")

    if end < start:
        raise HTTPException(status_code=400, detail="Tanggal akhir tidak boleh sebelum tanggal mulai")

    statuses = [s.strip().upper() for s in status.split(",") if s.strip()]
    if not statuses:
        statuses = ["APPROVED"]

    wita = timezone(timedelta(hours=8))
    start_of_day = datetime.combine(start, datetime.min.time()).replace(tzinfo=wita)
    end_of_day = datetime.combine(end + timedelta(days=1), datetime.min.time()).replace(tzinfo=wita)
    start_utc = start_of_day.astimezone(timezone.utc)
    end_utc = end_of_day.astimezone(timezone.utc)

    orders = (
        db.query(Order)
        .options(
            joinedload(Order.items).joinedload(OrderItem.product),
            joinedload(Order.customer),
            joinedload(Order.sales),
        )
        .filter(
            Order.status.in_(statuses),
            Order.created_at >= start_utc,
            Order.created_at < end_utc,
        )
    )
    orders = apply_branch_filter(orders, Order, current_user)
    orders = orders.order_by(Order.created_at.asc()).all()

    wb = Workbook()
    ws = wb.active
    _build_report(orders, ws, f"Laporan {start_date} sd {end_date}")

    buffer = BytesIO()
    wb.save(buffer)
    buffer.seek(0)

    filename = f"laporan-periode-{start_date}-sd-{end_date}.xlsx"
    return StreamingResponse(
        buffer,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@router.get("/sales-performance", response_model=SalesPerformanceResponse)
def sales_performance_report(
    from_date: str = Query(..., description="Tanggal mulai, YYYY-MM-DD (WITA)"),
    to_date: str = Query(..., description="Tanggal akhir, YYYY-MM-DD (WITA)"),
    status: Optional[str] = Query(
        None,
        description="Filter order by status: PENDING, APPROVED, REJECTED. "
                   "Defaults to APPROVED for backward compatibility.",
    ),
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_admin_or_supervisor),
):
    """KPI performa per sales dalam rentang tanggal:
    order count, revenue (total setelah diskon), customer submission count.
    Manager only."""
    try:
        start = datetime.strptime(from_date, "%Y-%m-%d").date()
    except ValueError:
        raise HTTPException(status_code=400, detail="Format tanggal mulai harus YYYY-MM-DD")
    try:
        end = datetime.strptime(to_date, "%Y-%m-%d").date()
    except ValueError:
        raise HTTPException(status_code=400, detail="Format tanggal akhir harus YYYY-MM-DD")

    if end < start:
        raise HTTPException(status_code=400, detail="Tanggal akhir tidak boleh sebelum tanggal mulai")

    # Default to APPROVED for backward compat
    order_status = status.upper() if status else "APPROVED"
    if order_status not in ("PENDING", "APPROVED", "REJECTED"):
        raise HTTPException(
            status_code=400,
            detail=f"status tidak valid: {status}. Gunakan PENDING, APPROVED, atau REJECTED.",
        )

    wita = timezone(timedelta(hours=8))
    start_dt = datetime.combine(start, datetime.min.time()).replace(tzinfo=wita).astimezone(timezone.utc)
    end_dt = datetime.combine(end + timedelta(days=1), datetime.min.time()).replace(tzinfo=wita).astimezone(timezone.utc)

    # Get all sales users (filtered by branch)
    sales_users_q = (
        db.query(User)
        .filter(User.role == "SALES", User.is_active.is_(True), User.deleted_at.is_(None))
    )
    sales_users_q = apply_branch_filter(sales_users_q, User, current_user)
    sales_users = sales_users_q.all()

    # Get order counts + revenue per sales (APPROVED orders only)
    from sqlalchemy import func

    order_stats = (
        db.query(
            Order.sales_id,
            func.count(Order.id).label("order_count"),
        )
        .filter(
            Order.sales_id.isnot(None),
            Order.status == order_status,
            Order.created_at >= start_dt,
            Order.created_at < end_dt,
        )
    )
    order_stats = apply_branch_filter(order_stats, Order, current_user)
    order_stats = order_stats.group_by(Order.sales_id).all()
    order_count_map = {s.sales_id: s.order_count for s in order_stats}

    # Revenue per sales: fetch items via Python (uses existing _three_layer_breakdown
    # which correctly computes sequential 3-layer discounts). This is clean and
    # avoids complex SQL expressions.
    from sqlalchemy.orm import joinedload
    orders_with_items = (
        db.query(Order)
        .options(joinedload(Order.items).joinedload(OrderItem.product))
        .filter(
            Order.sales_id.isnot(None),
            Order.status == order_status,
            Order.created_at >= start_dt,
            Order.created_at < end_dt,
        )
    )
    orders_with_items = apply_branch_filter(orders_with_items, Order, current_user)
    orders_with_items = orders_with_items.all()
    revenue_map: dict = {}
    for order in orders_with_items:
        sid = order.sales_id
        order_revenue = 0
        for item in order.items:
            raw, d1, d2, d3, after = _three_layer_breakdown(item)
            order_revenue += after
        revenue_map[sid] = revenue_map.get(sid, 0) + max(0, order_revenue)

    # Submission counts
    submission_stats = (
        db.query(
            CustomerRegistrationSubmission.sales_id,
            func.count(CustomerRegistrationSubmission.id).label("submission_count"),
        )
        .filter(
            CustomerRegistrationSubmission.sales_id.isnot(None),
            CustomerRegistrationSubmission.created_at >= start_dt,
            CustomerRegistrationSubmission.created_at < end_dt,
        )
    )
    submission_stats = apply_branch_filter(submission_stats, CustomerRegistrationSubmission, current_user)
    submission_stats = submission_stats.group_by(CustomerRegistrationSubmission.sales_id).all()
    submission_map = {s.sales_id: s.submission_count for s in submission_stats}

    items = []
    for u in sales_users:
        uid = u.id
        items.append(SalesPerformanceItem(
            user_id=uid,
            username=u.username or "",
            nama=u.nama,
            order_count=order_count_map.get(uid, 0),
            revenue=revenue_map.get(uid, 0),
            submission_count=submission_map.get(uid, 0),
        ))

    return SalesPerformanceResponse(sales=items)


@router.get("/sales-performance/dashboard", response_model=SalesPerformanceDashboardResponse)
def sales_performance_dashboard(
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_admin_or_supervisor),
):
    """Per-sales breakdown by status (APPROVED / PENDING / REJECTED) for MTD and Today.
    Admin/Supervisor access. Single call — no date params needed."""
    wita = timezone(timedelta(hours=8))
    now_wita = datetime.now(wita)
    today = now_wita.date()
    month_start = today.replace(day=1)

    def to_utc(dt: datetime) -> datetime:
        return dt.replace(tzinfo=wita).astimezone(timezone.utc)

    today_start = to_utc(datetime.combine(today, datetime.min.time()))
    today_end = to_utc(datetime.combine(today + timedelta(days=1), datetime.min.time()))
    month_start_dt = to_utc(datetime.combine(month_start, datetime.min.time()))

    def _revenue_for_order(order: Order) -> int:
        total = 0
        for item in order.items:
            _, _, _, _, after = _three_layer_breakdown(item)
            total += after
        return max(0, total)

    def _aggregate(orders: list[Order]) -> tuple[dict, dict]:
        """Return (count_map, revenue_map) keyed by sales_id."""
        count_map: dict = {}
        revenue_map: dict = {}
        for o in orders:
            sid = o.sales_id
            if sid is None:
                continue
            count_map[sid] = count_map.get(sid, 0) + 1
            revenue_map[sid] = revenue_map.get(sid, 0) + _revenue_for_order(o)
        return count_map, revenue_map

    # Load ALL orders (all statuses) for MTD and Today — single query each.
    # Date filter di SQL, bukan Python. joinedload(items.product) menghindari N+1.
    mtd_orders_q = (
        db.query(Order)
        .options(joinedload(Order.items).joinedload(OrderItem.product))
        .filter(
            Order.sales_id.isnot(None),
            Order.created_at >= month_start_dt,
            Order.created_at < today_end,
        )
    )
    mtd_orders = apply_branch_filter(mtd_orders_q, Order, current_user).all()
    today_orders_q = (
        db.query(Order)
        .options(joinedload(Order.items).joinedload(OrderItem.product))
        .filter(
            Order.sales_id.isnot(None),
            Order.created_at >= today_start,
            Order.created_at < today_end,
        )
    )
    today_orders = apply_branch_filter(today_orders_q, Order, current_user).all()

    # Get all active sales users (for building response list, filtered by branch)
    sales_users_q = (
        db.query(User)
        .filter(User.role == "SALES", User.is_active.is_(True), User.deleted_at.is_(None))
    )
    sales_users_q = apply_branch_filter(sales_users_q, User, current_user)
    sales_users = sales_users_q.all()

    # Split by status in Python — fast since data already loaded.
    def _split_by_status(orders: list[Order], status: str) -> list[Order]:
        return [o for o in orders if o.status == status]

    # MTD aggregates
    approved_mtd_count, approved_mtd_rev = _aggregate(
        _split_by_status(mtd_orders, "APPROVED"))
    pending_mtd_count, pending_mtd_rev = _aggregate(
        _split_by_status(mtd_orders, "PENDING"))
    rejected_mtd_count, rejected_mtd_rev = _aggregate(
        _split_by_status(mtd_orders, "REJECTED"))
    # Today aggregates
    approved_today_count, approved_today_rev = _aggregate(
        _split_by_status(today_orders, "APPROVED"))
    pending_today_count, pending_today_rev = _aggregate(
        _split_by_status(today_orders, "PENDING"))
    rejected_today_count, rejected_today_rev = _aggregate(
        _split_by_status(today_orders, "REJECTED"))

    items = []
    for u in sales_users:
        uid = u.id
        items.append(SalesPerformanceDashboardItem(
            user_id=uid,
            username=u.username or "",
            nama=u.nama,
            approved_mtd_count=approved_mtd_count.get(uid, 0),
            approved_mtd_revenue=approved_mtd_rev.get(uid, 0),
            approved_today_count=approved_today_count.get(uid, 0),
            approved_today_revenue=approved_today_rev.get(uid, 0),
            pending_mtd_count=pending_mtd_count.get(uid, 0),
            pending_mtd_revenue=pending_mtd_rev.get(uid, 0),
            pending_today_count=pending_today_count.get(uid, 0),
            pending_today_revenue=pending_today_rev.get(uid, 0),
            rejected_mtd_count=rejected_mtd_count.get(uid, 0),
            rejected_mtd_revenue=rejected_mtd_rev.get(uid, 0),
            rejected_today_count=rejected_today_count.get(uid, 0),
            rejected_today_revenue=rejected_today_rev.get(uid, 0),
        ))

    return SalesPerformanceDashboardResponse(sales=items)


# ==================== Cross-branch reports (global MANAGER only) ====================

@router.get("/cross-branch/sales-summary")
def cross_branch_sales_summary(
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_manager_global),
):
    """Per-branch approved count, revenue, pending count, customer count, sales count.
    Global MANAGER only."""
    from sqlalchemy import func, Integer, cast
    from app.core import branch as branch_constants

    summary = []
    for code in branch_constants.BRANCH_CODES:
        # Approved orders count + revenue
        approved_q = (
            db.query(func.count(Order.id))
            .filter(Order.status == "APPROVED", Order.branch == code)
        )
        approved_count = approved_q.scalar() or 0

        # Revenue
        final_subtotal_expr, _ = _three_layer_subtotal_expr()
        revenue_q = (
            db.query(func.coalesce(func.sum(final_subtotal_expr), 0))
            .join(Order, Order.id == OrderItem.order_id)
            .join(Product, Product.id == OrderItem.product_id)
            .filter(Order.status == "APPROVED", Order.branch == code)
        )
        revenue = revenue_q.scalar() or 0

        # Pending orders
        pending_count = (
            db.query(func.count(Order.id))
            .filter(Order.status == "PENDING", Order.branch == code)
            .scalar() or 0
        )

        # Customer count
        customer_count = (
            db.query(func.count(Customer.id))
            .filter(Customer.deleted_at.is_(None), Customer.branch == code)
            .scalar() or 0
        )

        # Sales count
        sales_count = (
            db.query(func.count(User.id))
            .filter(
                User.role == "SALES",
                User.is_active.is_(True),
                User.deleted_at.is_(None),
                User.branch == code,
            )
            .scalar() or 0
        )

        summary.append({
            "branch": code,
            "branch_nama": branch_constants.BRANCH_LABELS.get(code, code),
            "approved_count": approved_count,
            "approved_revenue": int(revenue),
            "pending_count": pending_count,
            "customer_count": customer_count,
            "sales_count": sales_count,
        })

    return {"branches": summary}


@router.get("/cross-branch/stock-summary")
def cross_branch_stock_summary(
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_manager_global),
):
    """Per-branch stock value, SKU count, low-stock flags. Global MANAGER only."""
    from sqlalchemy import func, Integer, cast
    from app.core import branch as branch_constants

    summary = []
    for code in branch_constants.BRANCH_CODES:
        sku_count = (
            db.query(func.count(Product.id))
            .filter(Product.branch == code)
            .scalar() or 0
        )

        # Stock value = sum(stok_sistem * harga) per branch
        stock_value_q = (
            db.query(func.coalesce(func.sum(Product.stok_sistem * Product.harga), 0))
            .filter(Product.branch == code)
        )
        stock_value = stock_value_q.scalar() or 0

        # Low stock (stok_tersedia <= 5)
        stok_expr = (
            func.coalesce(Product.stok_sistem, 0)
            - func.coalesce(Product.stok_booking, 0)
            - func.coalesce(Product.stok_diterima, 0)
        )
        low_stock_count = (
            db.query(func.count(Product.id))
            .filter(
                Product.branch == code,
                stok_expr <= 5,
                stok_expr > 0,
            )
            .scalar() or 0
        )
        out_of_stock = (
            db.query(func.count(Product.id))
            .filter(Product.branch == code, stok_expr <= 0)
            .scalar() or 0
        )

        summary.append({
            "branch": code,
            "branch_nama": branch_constants.BRANCH_LABELS.get(code, code),
            "sku_count": sku_count,
            "total_stock_value": int(stock_value),
            "low_stock_count": low_stock_count,
        })

    return {"branches": summary}
