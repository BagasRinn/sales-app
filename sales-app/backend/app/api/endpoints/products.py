from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy.orm import Session
from sqlalchemy import text, func
from typing import List, Optional
from uuid import UUID

from app.models.database import get_db
from app.models.models import Product, Order, ImportLog, SyncValidationError
from app.schemas.schemas import (
    ProductResponse,
    ProductUpdateStock,
    SyncResultResponse,
    ImportLogResponse,
)
from app.core.security import require_admin, require_manager, require_auth, CurrentUser
from app.services.sheets_sync import sync_products_from_excel
from app.services.stock_logger import log_stock_change

router = APIRouter(prefix="/products", tags=["Products"])


@router.get("", response_model=List[ProductResponse])
def list_products(
    skip: int = 0,
    limit: int = 20,
    search: Optional[str] = None,
    needs_review: Optional[bool] = None,
    kategori: Optional[str] = None,
    status: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_auth),
):
    # needs_review hanya boleh digunakan oleh ADMIN
    if needs_review is not None and current_user["role"] != "ADMIN":
        needs_review = None

    query = db.query(Product)

    if search:
        query = query.filter(
            (Product.id.ilike(f"%{search}%"))
            | (Product.nama_barang.ilike(f"%{search}%"))
        )

    if kategori:
        query = query.filter(Product.kategori == kategori)

    # Apply stock status filter at SQL level so pagination stays correct
    if status:
        stok_expr = (func.coalesce(Product.stok_sistem, 0) - func.coalesce(Product.stok_booking, 0))
        if status == "tersedia":
            query = query.filter(stok_expr > 5)
        elif status == "rendah":
            query = query.filter(stok_expr > 0, stok_expr <= 5)
        elif status == "habis":
            query = query.filter(stok_expr <= 0)

    products = query.offset(skip).limit(limit).all()

    result = []
    for p in products:
        stok_tersedia = max(0, (p.stok_sistem or 0) - (p.stok_booking or 0))
        perlu_ditinjau = (p.stok_sistem or 0) < (p.stok_booking or 0)
        result.append(
            ProductResponse(
                id=p.id,
                nama_barang=p.nama_barang,
                harga=p.harga,
                stok_sistem=p.stok_sistem or 0,
                stok_booking=p.stok_booking or 0,
                stok_tersedia=stok_tersedia,
                perlu_ditinjau=(
            (p.stok_sistem or 0) < (p.stok_booking or 0)
            if current_user["role"] == "ADMIN" else None
        ),
                kategori=p.kategori,
                satuan=p.satuan,
            )
        )

    if needs_review is not None:
        result = [p for p in result if p.perlu_ditinjau == needs_review]

    return result


@router.get("/kategori", response_model=List[str])
def get_kategori_list(
    db: Session = Depends(get_db),
    _current_user: CurrentUser = Depends(require_admin),
):
    """Return distinct kategori values for the filter dropdown."""
    rows = (
        db.query(Product.kategori)
        .filter(Product.kategori.isnot(None), Product.kategori != "")
        .distinct()
        .order_by(Product.kategori)
        .all()
    )
    return [r[0] for r in rows]


@router.post("/sync", response_model=SyncResultResponse)
def sync_products(
    db: Session = Depends(get_db),
    _current_user: CurrentUser = Depends(require_admin),
):
    sync_result = sync_products_from_excel(None, db)
    needs_review = db.query(Product).filter(
        Product.stok_sistem < Product.stok_booking
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
    current_user: CurrentUser = Depends(require_admin),
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

    sync_result = sync_products_from_excel(contents, db)

    # Catat ke histori import
    db.add(ImportLog(
        user_id=current_user["user_id"],
        nama=current_user.get("nama"),
        import_type="PRODUCT",
        total_rows=sync_result["total_rows"],
        inserted=sync_result["inserted"],
        updated=sync_result["updated"],
        skipped=sync_result["skipped"],
        file_name=file.filename,
    ))
    db.commit()

    needs_review = db.query(Product).filter(
        Product.stok_sistem < Product.stok_booking
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


@router.get("/import-logs", response_model=List[ImportLogResponse])
def get_import_logs(
    db: Session = Depends(get_db),
    _current_user: CurrentUser = Depends(require_admin),
):
    """Ambil histori import Excel."""
    logs = db.query(ImportLog).order_by(ImportLog.created_at.desc()).limit(50).all()
    return logs


@router.delete("/import-errors", status_code=204)
def clear_import_errors(
    db: Session = Depends(get_db),
    _current_user: CurrentUser = Depends(require_admin),
):
    """Hapus semua histori error import."""
    db.query(SyncValidationError).delete()
    db.commit()


@router.get("/sync/errors", response_model=List[dict])
def get_sync_errors(
    db: Session = Depends(get_db),
    _current_user: CurrentUser = Depends(require_admin),
):
    # Return persisted validation skips (empty SKU, negative, duplicate) first
    from app.models.models import SyncValidationError
    val_errors = db.query(SyncValidationError).order_by(
        SyncValidationError.created_at.desc()
    ).limit(100).all()
    # Then include SYNC audit log rows for reference
    stock_changes = db.execute(
        text(
            "SELECT id, product_id, sumber, field_terdampak, delta, "
            "nilai_sebelum, nilai_sesudah, created_at "
            "FROM stok_log WHERE sumber = 'SYNC' "
            "ORDER BY created_at DESC LIMIT 100"
        )
    ).fetchall()

    val_rows = [
        {"id": str(e.id), "row": e.row_number, "sku": e.sku,
         "reason": e.reason, "source": "validation"}
        for e in val_errors
    ]
    audit_rows = [
        {"id": str(r.id), "product_id": r.product_id,
         "sumber": r.sumber, "field_terdampak": r.field_terdampak,
         "delta": r.delta, "nilai_sebelum": r.nilai_sebelum,
         "nilai_sesudah": r.nilai_sesudah, "created_at": str(r.created_at),
         "source": "audit"}
        for r in stock_changes
    ]
    return val_rows + audit_rows


@router.get("/stats")
def get_admin_stats(
    db: Session = Depends(get_db),
    _current_user: CurrentUser = Depends(require_manager),
):
    """Server-side dashboard stats — MANAGER boleh akses untuk Dashboard ringkasan (read-only)."""
    from sqlalchemy import func
    from sqlalchemy import Integer
    from sqlalchemy import cast

    status_counts = dict(
        db.query(Order.status, func.count(Order.id))
        .group_by(Order.status).all()
    )
    total_orders = sum(status_counts.values())

    # Combine both product COUNT queries into a single round-trip
    product_result = db.query(
        func.count(Product.id),
        func.sum(cast(Product.stok_sistem < Product.stok_booking, Integer)),
    ).first()
    total_products = product_result[0] or 0
    needs_review = product_result[1] or 0

    return {
        "total_orders": total_orders,
        "pending_orders": status_counts.get("PENDING", 0),
        "approved_orders": status_counts.get("APPROVED", 0),
        "rejected_orders": status_counts.get("REJECTED", 0),
        "expired_orders": status_counts.get("EXPIRED", 0),
        "cancelled_orders": status_counts.get("CANCELLED", 0),
        "total_products": total_products,
        "needs_review": needs_review,
    }


@router.get("/count")
def get_product_count(
    search: Optional[str] = None,
    kategori: Optional[str] = None,
    status: Optional[str] = None,
    db: Session = Depends(get_db),
    _current_user: CurrentUser = Depends(require_admin),
):
    """Return total product count for pagination — applies same filters as list_products."""
    query = db.query(func.count(Product.id))
    if search:
        query = query.filter(
            (Product.id.ilike(f"%{search}%"))
            | (Product.nama_barang.ilike(f"%{search}%"))
        )
    if kategori:
        query = query.filter(Product.kategori == kategori)
    if status:
        stok_expr = (func.coalesce(Product.stok_sistem, 0) - func.coalesce(Product.stok_booking, 0))
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
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_auth),
):
    product = db.query(Product).filter(Product.id == product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="Produk tidak ditemukan")
    stok_tersedia = max(0, (product.stok_sistem or 0) - (product.stok_booking or 0))
    return ProductResponse(
        id=product.id,
        nama_barang=product.nama_barang,
        harga=product.harga,
        stok_sistem=product.stok_sistem or 0,
        stok_booking=product.stok_booking or 0,
        stok_tersedia=stok_tersedia,
        perlu_ditinjau=(
            (product.stok_sistem or 0) < (product.stok_booking or 0)
            if current_user["role"] == "ADMIN" else None
        ),
        kategori=product.kategori,
        satuan=product.satuan,
    )


@router.delete("/{product_id}", status_code=204)
def delete_product(
    product_id: str,
    db: Session = Depends(get_db),
    _current_user: CurrentUser = Depends(require_admin),
):
    from app.models.models import OrderItem
    product = db.query(Product).filter(Product.id == product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="Produk tidak ditemukan")

    db.query(OrderItem).filter(OrderItem.product_id == product_id).delete()
    db.delete(product)
    db.commit()


@router.put("/{product_id}/stock", response_model=ProductResponse)
def update_product_stock(
    product_id: str,
    stock_update: ProductUpdateStock,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_admin),
):
    product = (
        db.query(Product)
        .filter(Product.id == product_id)
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
    )

    db.commit()
    db.refresh(product)

    stok_tersedia = max(0, (product.stok_sistem or 0) - (product.stok_booking or 0))
    is_review_needed = (product.stok_sistem or 0) < (product.stok_booking or 0)
    return ProductResponse(
        id=product.id,
        nama_barang=product.nama_barang,
        harga=product.harga,
        stok_sistem=product.stok_sistem or 0,
        stok_booking=product.stok_booking or 0,
        stok_tersedia=stok_tersedia,
        perlu_ditinjau=is_review_needed,
        kategori=product.kategori,
        satuan=product.satuan,
    )
