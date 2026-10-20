from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy.orm import Session
from sqlalchemy import func, Integer, cast, Date, or_, select
from typing import List, Optional
from uuid import UUID
from datetime import datetime, timezone, timedelta
import os

from app.models.database import get_db
from app.models.models import Product, Order, ImportLog, SyncValidationError, Supplier
from app.core import branch as branch_constants
from app.schemas.schemas import (
    ProductResponse,
    ProductUpdateStock,
    ProductUpdate,
    SyncResultResponse,
    ImportLogResponse,
)
from app.core.security import require_admin, require_admin_or_supervisor, require_auth, require_write_access, apply_branch_filter, CurrentUser
from app.services.sheets_sync import sync_products_from_excel
from app.services.stock_logger import log_stock_change

router = APIRouter(prefix="/products", tags=["Products"])

WITA = timezone(timedelta(hours=8))


def _wita_str(dt: datetime) -> str:
    """Convert datetime to WITA ISO string with +08:00 suffix."""
    if dt is None:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(WITA).isoformat()


def _get_4p_suppliers(db: Optional[Session] = None) -> List[str]:
    """Return daftar supplier 4P.
    Primary source: database suppliers table (order_type = '4P' and is_active = true).
    Fallback source: env SUPPLIERS_4P if db is not provided or query fails."""
    if db is not None:
        try:
            rows = (
                db.query(Supplier.name)
                .filter(Supplier.order_type == "4P", Supplier.is_active == True)  # noqa: E712
                .order_by(Supplier.name)
                .all()
            )
            if rows:
                return [r[0] for r in rows]
        except Exception:
            pass

    raw = os.getenv("SUPPLIERS_4P", "").strip()
    if not raw:
        return []
    return [s.strip() for s in raw.split(",") if s.strip()]


@router.get("/suppliers/4p", response_model=List[str])
def get_suppliers_4p(
    db: Session = Depends(get_db),
    _current_user: CurrentUser = Depends(require_auth),
):
    """Return daftar supplier yang dikategorikan sebagai 4P (dari tabel suppliers DB, fallback env).
    Mobile fetch endpoint ini saat app init, lalu filter produk 4P berdasarkan daftar ini."""
    return _get_4p_suppliers(db=db)


@router.get("/sales-stats")
def get_product_sales_stats(
    year_month: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_auth),
):
    """Per-product monthly 'terjual' (= approved order qty) stats.

    'Terjual' = total qty yang masuk ke `stok_diterima` dalam bulan tertentu.
    Sumber: StokLog entries dengan `sumber` APPROVE/APPROVE_BACKFILL,
    `field_terdampak='stok_diterima'`, `delta > 0`. Import-reset di-log
    sebagai `sumber=SYNC, delta<0` dan otomatis di-exclude dari sum.

    Dengan begitu data historis (qty approved tiap bulan) tetap ada walau
    admin melakukan import produk (yang reset `stok_diterima=0` di product row).
    """
    from app.models.models import StokLog
    from datetime import datetime
    from sqlalchemy import and_

    if not year_month:
        now = datetime.utcnow()
        year_month = f"{now.year:04d}-{now.month:02d}"

    try:
        year, month = map(int, year_month.split("-"))
    except ValueError:
        raise HTTPException(
            status_code=400, detail="year_month must be YYYY-MM format"
        )

    month_start = datetime(year, month, 1)
    if month == 12:
        month_end = datetime(year + 1, 1, 1)
    else:
        month_end = datetime(year, month + 1, 1)

    # Subquery: sum positive stok_diterima deltas per (product, branch) in the month.
    log_subq = (
        db.query(
            StokLog.product_id,
            StokLog.branch,
            func.coalesce(func.sum(StokLog.delta), 0).label("terjual"),
        )
        .filter(
            StokLog.field_terdampak == "stok_diterima",
            StokLog.delta > 0,
            StokLog.created_at >= month_start,
            StokLog.created_at < month_end,
        )
        .group_by(StokLog.product_id, StokLog.branch)
        .subquery()
    )

    # Main query: products LEFT JOIN with log aggregation, branch-scoped.
    query = db.query(
        Product.id,
        Product.branch,
        Product.nama_barang,
        Product.stok_sistem,
        Product.nama_supplier,
        func.coalesce(log_subq.c.terjual, 0).label("terjual"),
    ).outerjoin(
        log_subq,
        and_(
            log_subq.c.product_id == Product.id,
            log_subq.c.branch == Product.branch,
        ),
    )
    query = apply_branch_filter(query, Product, current_user)

    rows = query.order_by(
        func.coalesce(log_subq.c.terjual, 0).desc(),
        Product.nama_barang.asc(),
    ).all()

    return [
        {
            "product_id": r.id,
            "branch": r.branch,
            "nama_barang": r.nama_barang,
            "stok_sistem": int(r.stok_sistem or 0),
            "nama_supplier": r.nama_supplier,
            "terjual": int(r.terjual or 0),
        }
        for r in rows
    ]


@router.get("", response_model=List[ProductResponse])
def list_products(
    skip: int = 0,
    limit: int = 20,
    search: Optional[str] = None,
    needs_review: Optional[bool] = None,
    kategori: Optional[str] = None,
    supplier: Optional[str] = None,
    status: Optional[str] = None,
    order_type: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_auth),
):
    # needs_review hanya boleh digunakan oleh ADMIN
    if needs_review is not None and current_user["role"] != "ADMIN":
        needs_review = None

    query = db.query(Product)
    # Branch filter applied first
    query = apply_branch_filter(query, Product, current_user)

    if current_user["role"] == "SALES":
        # Hide products whose supplier is inactive. Products with NULL or empty
        # nama_supplier remain visible (backward-compat for legacy products).
        active_suppliers_subq = (
            select(Supplier.name).where(Supplier.is_active == True).scalar_subquery()
        )
        query = query.filter(
            or_(
                Product.nama_supplier.is_(None),
                Product.nama_supplier == "",
                Product.nama_supplier.in_(active_suppliers_subq),
            )
        )

    if search:
        query = query.filter(
            (Product.id.ilike(f"%{search}%"))
            | (Product.nama_barang.ilike(f"%{search}%"))
            | (Product.nama_supplier.ilike(f"%{search}%"))
        )

    if kategori:
        query = query.filter(Product.kategori == kategori)

    if supplier:
        query = query.filter(Product.nama_supplier == supplier)

    if order_type:
        query = query.filter(Product.order_type == order_type)

    # Apply stock status filter at SQL level so pagination stays correct
    if status:
        stok_expr = (
            func.coalesce(Product.stok_sistem, 0)
            - func.coalesce(Product.stok_booking, 0)
            - func.coalesce(Product.stok_diterima, 0)
        )
        if status == "tersedia":
            query = query.filter(stok_expr > 5)
        elif status == "rendah":
            query = query.filter(stok_expr > 0, stok_expr <= 5)
        elif status == "habis":
            query = query.filter(stok_expr <= 0)

    products = query.offset(skip).limit(limit).all()

    result = []
    for p in products:
        stok_tersedia = max(
            0,
            (p.stok_sistem or 0)
            - (p.stok_booking or 0)
            - (p.stok_diterima or 0),
        )
        perlu_ditinjau = (p.stok_sistem or 0) < (
            (p.stok_booking or 0) + (p.stok_diterima or 0)
        )
        result.append(
            ProductResponse(
                id=p.id,
                branch=p.branch,
                branch_nama=branch_constants.get_branch_nama(p.branch),
                nama_barang=p.nama_barang,
                harga=p.harga,
                stok_sistem=p.stok_sistem or 0,
                stok_booking=p.stok_booking or 0,
                stok_diterima=p.stok_diterima or 0,
                stok_tersedia=stok_tersedia,
                perlu_ditinjau=(
                    (p.stok_sistem or 0) < (
                        (p.stok_booking or 0) + (p.stok_diterima or 0)
                    )
                    if current_user["role"] == "ADMIN" else None
                ),
                kategori=p.kategori,
                satuan=p.satuan,
                nama_supplier=p.nama_supplier,
                order_type=p.order_type or 'REGULER',
            )
        )

    if needs_review is not None:
        result = [p for p in result if p.perlu_ditinjau == needs_review]

    return result


@router.get("/kategori", response_model=List[str])
def get_kategori_list(
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_auth),
):
    """Return distinct kategori values for the filter dropdown (admin + manager).
    Branch-scoped."""
    query = db.query(Product.kategori).filter(
        Product.kategori.isnot(None), Product.kategori != ""
    )
    query = apply_branch_filter(query, Product, current_user)
    rows = query.distinct().order_by(Product.kategori).all()
    return [r[0] for r in rows]


@router.get("/supplier", response_model=List[str])
def get_supplier_list(
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_auth),
):
    """Return distinct supplier values for the filter dropdown (admin/supervisor).
    Branch-scoped."""
    query = db.query(Product.nama_supplier).filter(
        Product.nama_supplier.isnot(None), Product.nama_supplier != ""
    )
    query = apply_branch_filter(query, Product, current_user)
    rows = query.distinct().order_by(Product.nama_supplier).all()
    return [r[0] for r in rows]


@router.post("/sync", response_model=SyncResultResponse)
def sync_products(
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_write_access),
):
    sync_result = sync_products_from_excel(None, db, current_user={
        "user_id": current_user["user_id"],
        "nama": current_user.get("nama"),
        "branch": current_user.get("branch"),
    })
    needs_review = db.query(Product).filter(
        Product.stok_sistem < (Product.stok_booking + Product.stok_diterima)
    ).count() > 0
    return SyncResultResponse(
        success=sync_result["success"],
        total_rows=sync_result["total_rows"],
        inserted=sync_result["inserted"],
        updated=sync_result["updated"],
        skipped=sync_result["skipped"],
        errors=sync_result["errors"],
        needs_review=needs_review,
    )


@router.post("/import-excel", response_model=SyncResultResponse)
def import_excel(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_write_access),
):
    """
    Upload file Excel (.xlsx) untuk import / update data produk.
    Semua perubahan dijalankan dalam 1 transaksi database.
    """
    if not file.filename or not file.filename.lower().endswith(".xlsx"):
        raise HTTPException(
            status_code=400,
            detail="Format file harus .xlsx"
        )

    contents = file.file.read()
    if len(contents) == 0:
        raise HTTPException(status_code=400, detail="File kosong")

    sync_result = sync_products_from_excel(
        contents, db,
        current_user={
            "user_id": current_user["user_id"],
            "nama": current_user.get("nama"),
            "branch": current_user.get("branch"),
        },
        file_name=file.filename,
    )

    needs_review = db.query(Product).filter(
        Product.stok_sistem < (Product.stok_booking + Product.stok_diterima)
    ).count() > 0
    return SyncResultResponse(
        success=sync_result["success"],
        total_rows=sync_result["total_rows"],
        inserted=sync_result["inserted"],
        updated=sync_result["updated"],
        skipped=sync_result["skipped"],
        errors=sync_result["errors"],
        needs_review=needs_review,
    )


def _import_logs_branch_scope(current_user: dict) -> str | None:
    """Return branch to filter by, atau None untuk MANAGER (lihat semua).

    Legacy: import_logs.branch NULL sebelum tagging dianggap visible-to-all
    (jangan hilang). Filter by-branch = `WHERE branch = :scope OR branch IS NULL`.
    Helper ini return tuple-friendly clause via tuple return — caller pakai
    `or_(ImportLog.branch == scope, ImportLog.branch.is_(None))` kalau scope
    non-None; kalau None (MANAGER), no filter.
    """
    return current_user.get("branch")


@router.get("/import-logs", response_model=List[ImportLogResponse])
def get_import_logs(
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_auth),
):
    """Ambil histori import Excel (max 20 terbaru; pagination 5/halaman di client).

    Branch-scoped untuk ADMIN/SUPERVISOR: hanya log dengan branch = current
    user.branch, plus log legacy (branch NULL). MANAGER (global) lihat semua.
    """
    from sqlalchemy import or_
    scope = _import_logs_branch_scope(current_user)
    q = db.query(ImportLog)
    if scope is not None:
        q = q.filter(or_(ImportLog.branch == scope, ImportLog.branch.is_(None)))
    return q.order_by(ImportLog.created_at.desc()).limit(20).all()


@router.delete("/import-errors", status_code=204)
def clear_import_errors(
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_admin),
):
    """Hapus histori error import. Admin-only karena read-only manager
    tidak boleh mengubah state monitoring.

    Branch-scoped: ADMIN hanya hapus error di branch-nya. MANAGER (global)
    hapus semua.
    """
    from sqlalchemy import or_, select
    scope = _import_logs_branch_scope(current_user)
    # SQLAlchemy forbids Query.delete() when .join() has been applied, so we
    # build the list of import_log ids as a subquery and delete matching
    # SyncValidationError rows by id. Inner-join semantics preserved: errors
    # with NULL import_log_id are skipped, matching the pre-fix behavior.
    log_ids_stmt = select(ImportLog.id)
    if scope is not None:
        log_ids_stmt = log_ids_stmt.where(
            or_(ImportLog.branch == scope, ImportLog.branch.is_(None))
        )
    db.query(SyncValidationError).filter(
        SyncValidationError.import_log_id.in_(log_ids_stmt.scalar_subquery())
    ).delete(synchronize_session=False)
    db.commit()


@router.get("/sync/errors", response_model=List[dict])
def get_sync_errors(
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_auth),
):
    """Ambil error validasi dari sync terakhir (gabung dengan import_logs untuk
    menampilkan file name, import type, dan timestamp). 100 baris terbaru.

    Branch-scoped: sama dengan /import-logs.
    """
    from sqlalchemy import or_
    scope = _import_logs_branch_scope(current_user)
    q = (
        db.query(SyncValidationError, ImportLog)
        .outerjoin(ImportLog, SyncValidationError.import_log_id == ImportLog.id)
    )
    if scope is not None:
        q = q.filter(or_(ImportLog.branch == scope, ImportLog.branch.is_(None)))
    rows = q.order_by(SyncValidationError.created_at.desc()).limit(100).all()

    return [
        {
            "id": str(err.id),
            "row": err.row_number,
            "sku": err.sku,
            "reason": err.reason,
            "import_type": log.import_type if log else None,
            "file_name": log.file_name if log else None,
            "timestamp": _wita_str(err.created_at),
        }
        for err, log in rows
    ]


@router.get("/stats")
def get_admin_stats(
    date: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_auth),
):
    """Server-side dashboard stats - admin/supervisor access. Branch-scoped. Jika `date`
    Branch-scoped. Jika `date` diberikan (format YYYY-MM-DD), stats difilter untuk order
    yang dibuat pada tanggal tersebut saja. Tanpa `date`, mengembalikan semua order."""
    from sqlalchemy import func, Integer, cast
    from app.models.models import Order, Product, Customer

    query = db.query(Order.status, func.count(Order.id))
    query = apply_branch_filter(query, Order, current_user)

    if date:
        query = query.filter(
            func.date(Order.created_at) == cast(date, Date)
        )

    status_counts = dict(query.group_by(Order.status).all())
    total_orders = sum(status_counts.values())

    # Product stats: filtered by branch
    product_query = db.query(
        func.count(Product.id),
        func.sum(cast(
            Product.stok_sistem < (Product.stok_booking + Product.stok_diterima),
            Integer,
        )),
    )
    product_query = apply_branch_filter(product_query, Product, current_user)
    product_result = product_query.first()
    total_products = product_result[0] or 0
    needs_review = product_result[1] or 0

    # Total customer (exclude soft-deleted)
    customer_query = db.query(func.count(Customer.id)).filter(Customer.deleted_at.is_(None))
    customer_query = apply_branch_filter(customer_query, Customer, current_user)
    total_customers = customer_query.scalar() or 0

    return {
        "total_orders": total_orders,
        "pending_orders": status_counts.get("PENDING", 0),
        "approved_orders": status_counts.get("APPROVED", 0),
        "rejected_orders": status_counts.get("REJECTED", 0),
        "cancelled_orders": status_counts.get("CANCELLED", 0),
        "total_products": total_products,
        "needs_review": needs_review,
        "total_customers": total_customers,
    }


@router.get("/count")
def get_product_count(
    search: Optional[str] = None,
    kategori: Optional[str] = None,
    supplier: Optional[str] = None,
    status: Optional[str] = None,
    order_type: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_auth),
):
    """Return total product count for pagination - applies same filters as list_products."""
    query = db.query(func.count(Product.id))
    query = apply_branch_filter(query, Product, current_user)
    if search:
        query = query.filter(
            (Product.id.ilike(f"%{search}%"))
            | (Product.nama_barang.ilike(f"%{search}%"))
            | (Product.nama_supplier.ilike(f"%{search}%"))
        )
    if kategori:
        query = query.filter(Product.kategori == kategori)
    if supplier:
        query = query.filter(Product.nama_supplier == supplier)
    if order_type:
        query = query.filter(Product.order_type == order_type)
    if status:
        stok_expr = (
            func.coalesce(Product.stok_sistem, 0)
            - func.coalesce(Product.stok_booking, 0)
            - func.coalesce(Product.stok_diterima, 0)
        )
        if status == "tersedia":
            query = query.filter(stok_expr > 5)
        elif status == "rendah":
            query = query.filter(stok_expr > 0, stok_expr <= 5)
        elif status == "habis":
            query = query.filter(stok_expr <= 0)
    return {"total": query.scalar() or 0}


@router.get("/{product_id}", response_model=ProductResponse)
def get_product(
    product_id: str,
    branch: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_auth),
):
    query = db.query(Product).filter(Product.id == product_id)
    # Filter by branch: use explicit branch if provided, otherwise user's branch
    lookup_branch = branch or current_user.get("branch")
    if lookup_branch:
        query = query.filter(Product.branch == lookup_branch)
    product = query.first()
    if not product:
        raise HTTPException(status_code=404, detail="Produk tidak ditemukan")
    stok_tersedia = max(
        0,
        (product.stok_sistem or 0)
        - (product.stok_booking or 0)
        - (product.stok_diterima or 0),
    )
    return ProductResponse(
        id=product.id,
        branch=product.branch,
        nama_barang=product.nama_barang,
        harga=product.harga,
        stok_sistem=product.stok_sistem or 0,
        stok_booking=product.stok_booking or 0,
        stok_diterima=product.stok_diterima or 0,
        stok_tersedia=stok_tersedia,
        perlu_ditinjau=(
            (product.stok_sistem or 0)
            < ((product.stok_booking or 0) + (product.stok_diterima or 0))
            if current_user["role"] == "ADMIN" else None
        ),
        kategori=product.kategori,
        satuan=product.satuan,
        nama_supplier=product.nama_supplier,
        order_type=product.order_type or 'REGULER',
    )


@router.put("/{product_id}", response_model=ProductResponse)
def update_product(
    product_id: str,
    payload: ProductUpdate,
    branch: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_write_access),
):
    """Partial update untuk produk - admin/supervisor. Field yang None di-skip.
    order_type hanya menerima 'REGULER' atau '4P'."""
    query = db.query(Product).filter(Product.id == product_id)
    lookup_branch = branch or current_user.get("branch")
    if lookup_branch:
        query = query.filter(Product.branch == lookup_branch)
    product = (
        query
        .with_for_update()
        .first()
    )
    if not product:
        raise HTTPException(status_code=404, detail="Produk tidak ditemukan")

    if payload.order_type is not None and payload.order_type not in ('REGULER', '4P'):
        raise HTTPException(
            status_code=400,
            detail=f"order_type tidak valid: {payload.order_type}. Harus 'REGULER' atau '4P'.",
        )

    if payload.kategori is not None:
        product.kategori = payload.kategori
    if payload.satuan is not None:
        product.satuan = payload.satuan
    if payload.nama_supplier is not None:
        product.nama_supplier = payload.nama_supplier
    if payload.order_type is not None:
        product.order_type = payload.order_type

    db.commit()
    db.refresh(product)

    stok_tersedia = max(
        0,
        (product.stok_sistem or 0)
        - (product.stok_booking or 0)
        - (product.stok_diterima or 0),
    )
    return ProductResponse(
        id=product.id,
        branch=product.branch,
        nama_barang=product.nama_barang,
        harga=product.harga,
        stok_sistem=product.stok_sistem or 0,
        stok_booking=product.stok_booking or 0,
        stok_diterima=product.stok_diterima or 0,
        stok_tersedia=stok_tersedia,
        perlu_ditinjau=(
            (product.stok_sistem or 0)
            < ((product.stok_booking or 0) + (product.stok_diterima or 0))
            if current_user["role"] == "ADMIN" else None
        ),
        kategori=product.kategori,
        satuan=product.satuan,
        nama_supplier=product.nama_supplier,
        order_type=product.order_type or 'REGULER',
    )


@router.delete("/{product_id}", status_code=204)
def delete_product(
    product_id: str,
    branch: Optional[str] = None,
    db: Session = Depends(get_db),
    _current_user: CurrentUser = Depends(require_admin),
):
    from app.models.models import OrderItem
    query = db.query(Product).filter(Product.id == product_id)
    lookup_branch = branch or ""
    if lookup_branch:
        query = query.filter(Product.branch == lookup_branch)
    product = query.first()
    if not product:
        raise HTTPException(status_code=404, detail="Produk tidak ditemukan")

    db.query(OrderItem).filter(
        OrderItem.product_id == product_id,
        OrderItem.branch == product.branch,
    ).delete()
    db.delete(product)
    db.commit()


@router.put("/{product_id}/stock", response_model=ProductResponse)
def update_product_stock(
    product_id: str,
    stock_update: ProductUpdateStock,
    branch: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_write_access),
):
    query = db.query(Product).filter(Product.id == product_id)
    lookup_branch = branch or current_user.get("branch")
    if lookup_branch:
        query = query.filter(Product.branch == lookup_branch)
    product = (
        query
        .with_for_update()
        .first()
    )
    if not product:
        raise HTTPException(status_code=404, detail="Produk tidak ditemukan")

    old_stok = product.stok_sistem or 0
    delta = stock_update.stok_sistem - old_stok
    product.stok_sistem = stock_update.stok_sistem

    log_stock_change(
        db=db,
        product_id=product.id,
        sumber="MANUAL",
        field_terdampak="stok_sistem",
        delta=delta,
        nilai_sebelum=old_stok,
        nilai_sesudah=stock_update.stok_sistem,
        actor_id=UUID(current_user["user_id"]),
        order_id=None,
        branch=product.branch,
    )

    db.commit()
    db.refresh(product)

    stok_tersedia = max(
        0,
        (product.stok_sistem or 0)
        - (product.stok_booking or 0)
        - (product.stok_diterima or 0),
    )
    is_review_needed = (product.stok_sistem or 0) < (
        (product.stok_booking or 0) + (product.stok_diterima or 0)
    )
    return ProductResponse(
        id=product.id,
        branch=product.branch,
        nama_barang=product.nama_barang,
        harga=product.harga,
        stok_sistem=product.stok_sistem or 0,
        stok_booking=product.stok_booking or 0,
        stok_diterima=product.stok_diterima or 0,
        stok_tersedia=stok_tersedia,
        perlu_ditinjau=is_review_needed,
        kategori=product.kategori,
        satuan=product.satuan,
        nama_supplier=product.nama_supplier,
    )
