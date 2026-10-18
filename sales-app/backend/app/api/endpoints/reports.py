"""Daily and period order reports - Excel export untuk admin & manager."""
from datetime import datetime, timedelta, timezone
from io import BytesIO
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import StreamingResponse
from openpyxl import Workbook
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.utils import get_column_letter
from sqlalchemy import case, cast, func
from sqlalchemy.types import Integer
from sqlalchemy.orm import Session, joinedload
from sqlalchemy.orm import aliased

from app.models.database import get_db
from app.models.models import Order, OrderItem, Product, Customer, User, CustomerRegistrationSubmission, SupplierTarget
from app.core.security import require_admin_or_supervisor, require_manager_global, require_auth, apply_branch_filter
from app.core import branch as branch_constants
from app.schemas.schemas import (
    SalesPerformanceResponse,
    SalesPerformanceItem,
    SalesPerformanceDashboardItem,
    SalesPerformanceDashboardResponse,
    SupplierPerformanceRow,
    ReportSummaryResponse,
    ReportSummaryByStatus,
    ReportSummaryByProduct,
    ReportSummaryBySales,
    ReportSummaryByBranch,
)

router = APIRouter(prefix="/reports", tags=["Reports"])


def _layer_cut_value(type_val: str, percent: int, nominal: int, running: int) -> int:
    """Potongan untuk 1 layer (sequential). NOMINAL di-cap ke running; PERCENT dari running."""
    if (type_val or "PERCENT").upper() == "NOMINAL":
        return min(max(0, nominal or 0), running)
    return int(round(running * max(0, min(100, percent or 0)) / 100))


def _three_layer_subtotal_expr():
    """SQL expression untuk hitung subtotal akhir setelah 3-layer diskon.
    Return (final_subtotal_expr, raw_subtotal_expr) sebagai SQLAlchemy expressions.
    Up Price ditambahkan ke base sebelum 3 layer berjalan (mirror Python calc)."""
    from sqlalchemy import case

    def _cut_expr(type_col, percent_col, nominal_col, running):
        return case(
            ((type_col.is_(None) | (type_col == 'PERCENT')),
             cast(running * func.coalesce(percent_col, 0) / 100, Integer)),
            else_=func.coalesce(func.least(func.coalesce(nominal_col, 0), running), 0),
        )

    harga_qty = OrderItem.qty * Product.harga
    raw = func.coalesce(harga_qty, 0)

    up_per_piece = case(
        (
            (OrderItem.up_price_type.is_(None) | (OrderItem.up_price_type == 'PERCENT')),
            cast(func.coalesce(Product.harga, 0) * func.coalesce(OrderItem.up_price_percent, 0) / 100, Integer),
        ),
        else_=func.coalesce(OrderItem.up_price_nominal, 0),
    )
    base = raw + up_per_piece * func.coalesce(OrderItem.qty, 0)

    d1 = _cut_expr(OrderItem.discount_type, OrderItem.discount_percent,
                    OrderItem.discount_nominal, base)
    after1 = base - d1

    d2 = _cut_expr(OrderItem.discount2_type, OrderItem.discount2_percent,
                    OrderItem.discount2_nominal, after1)
    after2 = after1 - d2

    d3 = _cut_expr(OrderItem.discount3_type, OrderItem.discount3_percent,
                    OrderItem.discount3_nominal, after2)
    final = after2 - d3

    return final, raw


def _three_layer_breakdown(item) -> tuple[int, int, int, int, int, int]:
    """Hitung chain 3 layers sequential. Return (total_sebelum, layer1_cut, layer2_cut, layer3_cut, total_setelah, up_price_total)."""
    harga_satuan = item.product.harga if item.product else 0
    qty = item.qty or 0
    raw = harga_satuan * qty
    up_t = (item.up_price_type or 'NOMINAL').upper()
    if up_t == 'PERCENT':
        up_per_piece = int(round(max(0, harga_satuan) * max(0, float(item.up_price_percent or 0)) / 100))
    else:
        up_per_piece = int(max(0, item.up_price_nominal or 0))
    up_total = up_per_piece * qty
    base = raw + up_total
    s = max(0, base)
    d1 = _layer_cut_value(item.discount_type, item.discount_percent, item.discount_nominal, s)
    s -= d1
    d2 = _layer_cut_value(item.discount2_type, item.discount2_percent, item.discount2_nominal, s)
    s -= d2
    d3 = _layer_cut_value(item.discount3_type, item.discount3_percent, item.discount3_nominal, s)
    s -= d3
    return raw, d1, d2, d3, s, up_total


def _build_report(
    orders,
    ws: Workbook.active,
    title: str,
) -> int:
    """Generate report rows dengan breakdown 3-layer discount. Returns row count."""
    ws.title = title

    headers = [
        "Tanggal",
        "Cabang",
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
        "Up Price",
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
        order_date = order.created_at.astimezone(timezone(timedelta(hours=8))).strftime("%Y-%m-%d") if order.created_at else ""
        for item in order.items:
            product = item.product
            harga_satuan = product.harga if product else 0
            qty = item.qty

            raw, d1, d2, d3, after, up_total = _three_layer_breakdown(item)
            total_diskon = d1 + d2 + d3

            ws.append([
                order_date,
                order.branch or "",
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
                up_total,
                after,
                order.order_type or 'REGULER',
                sales_name,
                product.nama_supplier if product else "",
            ])
            total_rows += 1

    # Auto-width columns
    widths = [14, 10, 16, 28, 14, 32, 6, 8, 14, 20, 14, 14, 14, 14, 14, 20, 12, 20, 28]
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
    detail: bool = Query(
        False,
        description="Jika true, return Excel XLSX (per-row). Default: return JSON summary (agregat).",
    ),
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_auth),
):
    """Generate laporan harian. Timezone mengikuti sales app (WITA/UTC+8).

    Default: return JSON summary (agregat via SQL).
    Opt-in `?detail=true`: return Excel XLSX dengan 17 kolom per row.
    """
    try:
        target_date = datetime.strptime(date, "%Y-%m-%d").date()
    except ValueError:
        raise HTTPException(status_code=400, detail="Format tanggal harus YYYY-MM-DD")

    # Validasi range untuk konsistensi (daily selalu 1 hari, jadi selalu <= 365)
    if detail:
        return _build_daily_xlsx(target_date, status, db, current_user)
    else:
        return report_summary(
            start_date=date,
            end_date=date,
            db=db,
            current_user=current_user,
        )


def _build_daily_xlsx(target_date, statuses, db, current_user):
    """Build XLSX binary untuk 1 hari (legacy behavior, dipanggil kalau ?detail=true)."""
    statuses = statuses if isinstance(statuses, list) else [s.strip().upper() for s in statuses.split(",") if s.strip()]
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
    detail: bool = Query(
        False,
        description="Jika true, return Excel XLSX (per-row). Default: return JSON summary (agregat).",
    ),
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_auth),
):
    """Generate laporan berdasarkan rentang tanggal. Timezone WITA/UTC+8.

    Default: return JSON summary (agregat via SQL).
    Opt-in `?detail=true`: return Excel XLSX per row.
    """
    # Validasi format & range — sama untuk kedua mode
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
    if (end - start).days > 365:
        raise HTTPException(status_code=400, detail="Rentang tanggal maksimal 365 hari")

    if detail:
        return _build_period_xlsx(start, end, status, db, current_user)
    else:
        return report_summary(
            start_date=start_date,
            end_date=end_date,
            db=db,
            current_user=current_user,
        )


def _build_period_xlsx(start, end, statuses, db, current_user):
    """Build XLSX binary untuk rentang tanggal (legacy behavior, dipanggil kalau ?detail=true)."""
    statuses = statuses if isinstance(statuses, list) else [s.strip().upper() for s in statuses.split(",") if s.strip()]
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
    _build_report(orders, ws, f"Laporan {start.isoformat()} sd {end.isoformat()}")

    buffer = BytesIO()
    wb.save(buffer)
    buffer.seek(0)

    filename = f"laporan-periode-{start.isoformat()}-sd-{end.isoformat()}.xlsx"
    return StreamingResponse(
        buffer,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@router.get("/summary", response_model=ReportSummaryResponse)
def report_summary(
    start_date: str = Query(..., description="Tanggal mulai, YYYY-MM-DD (WITA)"),
    end_date: str = Query(..., description="Tanggal akhir, YYYY-MM-DD (WITA)"),
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_auth),
):
    """Agregat laporan per rentang tanggal. Pure SQL aggregation — TIDAK load row order.
    Response: total counts + by_status, by_product (top 20), by_sales (top 20), by_branch.
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
    if (end - start).days > 365:
        raise HTTPException(status_code=400, detail="Rentang tanggal maksimal 365 hari")

    wita = timezone(timedelta(hours=8))
    start_utc = datetime.combine(start, datetime.min.time()).replace(tzinfo=wita).astimezone(timezone.utc)
    end_utc = datetime.combine(end + timedelta(days=1), datetime.min.time()).replace(tzinfo=wita).astimezone(timezone.utc)

    # Base query untuk orders dalam rentang + branch filter
    base_orders = db.query(Order).filter(
        Order.created_at >= start_utc,
        Order.created_at < end_utc,
    )
    base_orders = apply_branch_filter(base_orders, Order, current_user)

    # 1. Total orders
    total_orders = base_orders.with_entities(func.count(Order.id)).scalar() or 0

    # 2. by_status
    by_status_rows = (
        base_orders.with_entities(Order.status, func.count(Order.id).label("c"))
        .group_by(Order.status).all()
    )
    by_status = [ReportSummaryByStatus(status=row[0] or "UNKNOWN", count=row[1]) for row in by_status_rows]

    # 3. Total items sold + raw_revenue (qty * harga) via OrderItem join
    item_agg = (
        base_orders.join(OrderItem, OrderItem.order_id == Order.id)
        .join(Product, Product.id == OrderItem.product_id)
        .with_entities(
            func.coalesce(func.sum(OrderItem.qty), 0).label("total_qty"),
            func.coalesce(func.sum(OrderItem.qty * Product.harga), 0).label("raw_rev"),
        )
        .first()
    )
    total_items_sold = int(item_agg.total_qty or 0)
    raw_revenue = int(item_agg.raw_rev or 0)

    # 4. by_product (top 20 by raw_revenue)
    by_product_rows = (
        base_orders.join(OrderItem, OrderItem.order_id == Order.id)
        .join(Product, Product.id == OrderItem.product_id)
        .with_entities(
            Product.id.label("product_id"),
            Product.nama_barang.label("product_name"),
            func.coalesce(func.sum(OrderItem.qty), 0).label("qty_sold"),
            func.coalesce(func.sum(OrderItem.qty * Product.harga), 0).label("raw_revenue"),
        )
        .group_by(Product.id, Product.nama_barang)
        .order_by(func.coalesce(func.sum(OrderItem.qty * Product.harga), 0).desc())
        .limit(20).all()
    )
    by_product = [
        ReportSummaryByProduct(
            product_id=r.product_id,
            product_name=r.product_name or "",
            qty_sold=int(r.qty_sold or 0),
            raw_revenue=int(r.raw_revenue or 0),
        )
        for r in by_product_rows
    ]

    # 5. by_sales (top 20 by order_count) — pakai distinct Order.id supaya
    # order dengan multiple items tidak dihitung beberapa kali
    UserAlias = aliased(User)
    by_sales_rows = (
        base_orders.join(UserAlias, UserAlias.id == Order.sales_id)
        .with_entities(
            UserAlias.id.label("user_id"),
            UserAlias.username.label("username"),
            UserAlias.nama.label("nama"),
            func.count(func.distinct(Order.id)).label("order_count"),
            func.coalesce(func.sum(OrderItem.qty * Product.harga), 0).label("raw_revenue"),
        )
        .outerjoin(OrderItem, OrderItem.order_id == Order.id)
        .outerjoin(Product, Product.id == OrderItem.product_id)
        .group_by(UserAlias.id, UserAlias.username, UserAlias.nama)
        .order_by(func.count(func.distinct(Order.id)).desc())
        .limit(20).all()
    )
    by_sales = [
        ReportSummaryBySales(
            user_id=r.user_id,
            username=r.username or "",
            nama=r.nama,
            order_count=int(r.order_count or 0),
            raw_revenue=int(r.raw_revenue or 0),
        )
        for r in by_sales_rows
    ]

    # 6. by_branch
    by_branch_rows = (
        base_orders.outerjoin(OrderItem, OrderItem.order_id == Order.id)
        .outerjoin(Product, Product.id == OrderItem.product_id)
        .with_entities(
            Order.branch.label("branch"),
            func.count(func.distinct(Order.id)).label("order_count"),
            func.coalesce(func.sum(OrderItem.qty), 0).label("item_count"),
            func.coalesce(func.sum(OrderItem.qty * Product.harga), 0).label("raw_revenue"),
        )
        .group_by(Order.branch)
        .order_by(Order.branch.asc())
        .all()
    )
    by_branch = [
        ReportSummaryByBranch(
            branch=r.branch or "",
            order_count=int(r.order_count or 0),
            item_count=int(r.item_count or 0),
            raw_revenue=int(r.raw_revenue or 0),
        )
        for r in by_branch_rows
    ]

    return ReportSummaryResponse(
        period_start=start,
        period_end=end,
        total_orders=total_orders,
        total_items_sold=total_items_sold,
        raw_revenue=raw_revenue,
        by_status=by_status,
        by_product=by_product,
        by_sales=by_sales,
        by_branch=by_branch,
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
    current_user: dict = Depends(require_auth),
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
            raw, d1, d2, d3, after, _ = _three_layer_breakdown(item)
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
    current_user: dict = Depends(require_auth),
):
    """Per-sales breakdown by status (APPROVED / PENDING / REJECTED) for MTD and Today.
    Admin/Supervisor access. Single call - no date params needed."""
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
            _, _, _, _, after, _ = _three_layer_breakdown(item)
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

    # Load ALL orders (all statuses) for MTD and Today - single query each.
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

    # Split by status in Python - fast since data already loaded.
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
            branch=u.branch,
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
    Global MANAGER only.

    4 query fixed (bukan 5×N): order counts, revenue, customer count, sales
    count — masing-masing di-GROUP BY branch dalam 1 query.
    """
    from app.core import branch as branch_constants

    # Query 1: order counts (approved + pending) per branch
    order_stats = (
        db.query(
            Order.branch.label("branch"),
            func.sum(case((Order.status == "APPROVED", 1), else_=0)).label("approved_count"),
            func.sum(case((Order.status == "PENDING", 1), else_=0)).label("pending_count"),
        )
        .group_by(Order.branch)
        .all()
    )
    stats_by_branch = {r.branch: r for r in order_stats}

    # Query 2: revenue per branch (approved only, subtotal setelah 3-layer diskon)
    final_subtotal_expr, _ = _three_layer_subtotal_expr()
    revenue_rows = (
        db.query(
            Order.branch.label("branch"),
            func.coalesce(func.sum(final_subtotal_expr), 0).label("revenue"),
        )
        .join(OrderItem, OrderItem.order_id == Order.id)
        .join(Product, Product.id == OrderItem.product_id)
        .filter(Order.status == "APPROVED")
        .group_by(Order.branch)
        .all()
    )
    revenue_by_branch = {r.branch: r.revenue for r in revenue_rows}

    # Query 3: customer count per branch
    customer_counts = {
        branch: count
        for branch, count in (
            db.query(Customer.branch, func.count(Customer.id))
            .filter(Customer.deleted_at.is_(None))
            .group_by(Customer.branch)
            .all()
        )
    }

    # Query 4: sales count per branch
    sales_counts = {
        branch: count
        for branch, count in (
            db.query(User.branch, func.count(User.id))
            .filter(
                User.role == "SALES",
                User.is_active.is_(True),
                User.deleted_at.is_(None),
            )
            .group_by(User.branch)
            .all()
        )
    }

    summary = []
    for code in branch_constants.get_valid_branch_codes():
        row = stats_by_branch.get(code)
        summary.append({
            "branch": code,
            "branch_nama": branch_constants.get_branch_nama(code),
            "approved_count": int(row.approved_count or 0) if row else 0,
            "approved_revenue": int(revenue_by_branch.get(code) or 0),
            "pending_count": int(row.pending_count or 0) if row else 0,
            "customer_count": int(customer_counts.get(code) or 0),
            "sales_count": int(sales_counts.get(code) or 0),
        })

    return {"branches": summary}


@router.get("/cross-branch/stock-summary")
def cross_branch_stock_summary(
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_manager_global),
):
    """Per-branch stock value, SKU count, low-stock flags. Global MANAGER only.

    1 query GROUP BY branch (sebelumnya 4×N query, satu scalar per branch).
    """
    from app.core import branch as branch_constants

    stok_expr = (
        func.coalesce(Product.stok_sistem, 0)
        - func.coalesce(Product.stok_booking, 0)
        - func.coalesce(Product.stok_diterima, 0)
    )
    rows = (
        db.query(
            Product.branch.label("branch"),
            func.count(Product.id).label("sku_count"),
            func.coalesce(func.sum(Product.stok_sistem * Product.harga), 0).label("stock_value"),
            func.sum(
                case(((stok_expr > 0) & (stok_expr <= 5), 1), else_=0)
            ).label("low_stock_count"),
        )
        .group_by(Product.branch)
        .all()
    )
    stats_by_branch = {r.branch: r for r in rows}

    summary = []
    for code in branch_constants.get_valid_branch_codes():
        row = stats_by_branch.get(code)
        summary.append({
            "branch": code,
            "branch_nama": branch_constants.get_branch_nama(code),
            "sku_count": int(row.sku_count or 0) if row else 0,
            "total_stock_value": int(row.stock_value or 0) if row else 0,
            "low_stock_count": int(row.low_stock_count or 0) if row else 0,
        })

    return {"branches": summary}


@router.get("/supplier-performance", response_model=List[SupplierPerformanceRow])
def get_supplier_performance(
    year_month: str = Query(..., description="YYYY-MM"),
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_auth),
):
    """Per-supplier monthly performance: revenue vs target (with auto-rollover).

    Revenue = sum of approved-order final subtotals (qty*harga + up_price - 3
    sequential discounts) for products with `nama_supplier` = the supplier,
    in the requested month, in the user's branch.

    Target resolution:
      1. Look up `supplier_targets` for (branch, supplier, year_month).
      2. If none, look up the most recent prior period for the same
         (branch, supplier) — this is the auto-rollover carry-over.
      3. If still none, has_target=false and pencapaian is null.
    """
    year, month = map(int, year_month.split("-"))
    month_start = datetime(year, month, 1)
    month_end = (month_start.replace(day=28) + timedelta(days=4)).replace(day=1)

    # 1. Distinct supplier names from products in user's branch.
    #    (Product table has no soft-delete column — products are hard-deleted
    #    on import or via admin tools. Filter empty/null suppliers only.)
    product_query = db.query(Product.nama_supplier).filter(
        Product.nama_supplier.isnot(None),
        Product.nama_supplier != "",
    )
    product_query = apply_branch_filter(product_query, Product, current_user)
    product_suppliers = {row[0] for row in product_query.distinct().all()}

    # 2. Distinct supplier names that have any target row in the user's branch.
    target_branch_q = db.query(SupplierTarget.supplier_name)
    if current_user.get("branch"):
        target_branch_q = target_branch_q.filter(
            SupplierTarget.branch == current_user["branch"]
        )
    target_suppliers = {row[0] for row in target_branch_q.distinct().all()}

    all_suppliers = sorted(product_suppliers | target_suppliers)

    # 3. Target resolution — batched to avoid N+1 queries. For each
    #    supplier, we want the most recent target with period <= year_month.
    #    One query returns all candidates; the per-supplier pick is in Python.
    target_by_supplier: dict = {}
    if all_suppliers:
        target_query = db.query(SupplierTarget).filter(
            SupplierTarget.supplier_name.in_(all_suppliers),
            SupplierTarget.period <= year_month,
        )
        if current_user.get("branch"):
            target_query = target_query.filter(
                SupplierTarget.branch == current_user["branch"]
            )
        for t in target_query.all():
            existing = target_by_supplier.get(t.supplier_name)
            if existing is None or t.period > existing.period:
                target_by_supplier[t.supplier_name] = t

    def resolve_target(name: str) -> tuple[int, bool]:
        t = target_by_supplier.get(name)
        if t is None:
            return 0, False
        return int(t.target_value), True

    # 4. Revenue per supplier using _three_layer_breakdown (Python iteration
    #    matches the rest of the app and avoids duplicating the SQL expression).
    orders_with_items = (
        db.query(Order)
        .options(joinedload(Order.items).joinedload(OrderItem.product))
        .filter(
            Order.status == "APPROVED",
            Order.created_at >= month_start,
            Order.created_at < month_end,
        )
    )
    orders_with_items = apply_branch_filter(orders_with_items, Order, current_user)
    orders_with_items = orders_with_items.all()

    revenue_map: dict = {}
    for order in orders_with_items:
        for item in order.items:
            sup = (item.product.nama_supplier or "").strip() if item.product else ""
            if not sup:
                continue
            raw, d1, d2, d3, after, _ = _three_layer_breakdown(item)
            revenue_map[sup] = revenue_map.get(sup, 0) + max(0, after)

    rows: list[SupplierPerformanceRow] = []
    for name in all_suppliers:
        value = revenue_map.get(name, 0)
        target, has_target = resolve_target(name)
        if has_target and target > 0:
            pencapaian = round((value / target) * 100, 1)
        else:
            # No target (or target=0) → no percentage to render.
            pencapaian = None
        rows.append(SupplierPerformanceRow(
            supplier_name=name,
            target=target,
            has_target=has_target,
            value=value,
            pencapaian=pencapaian,
        ))

    rows.sort(key=lambda r: (-r.value, r.supplier_name))
    return rows
