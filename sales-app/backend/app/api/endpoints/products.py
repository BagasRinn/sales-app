from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks
from sqlalchemy.orm import Session
from sqlalchemy import text
from typing import List, Optional
from uuid import UUID

from app.models.database import get_db
from app.models.models import Product, User
from app.schemas.schemas import (
    ProductResponse,
    ProductUpdateStock,
    SyncResultResponse,
)
from app.core.security import require_admin, require_auth, CurrentUser
from app.services.sheets_sync import sync_products_from_sheets
from app.services.stock_logger import log_stock_change

router = APIRouter(prefix="/products", tags=["Products"])


@router.get("", response_model=List[ProductResponse])
def list_products(
    skip: int = 0,
    limit: int = 100,
    search: Optional[str] = None,
    needs_review: Optional[bool] = None,
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
            )
        )

    if needs_review is not None:
        result = [p for p in result if p.perlu_ditinjau == needs_review]

    return result


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
    is_review_needed = (product.stok_sistem or 0) < (product.stok_booking or 0)
    return ProductResponse(
        id=product.id,
        nama_barang=product.nama_barang,
        harga=product.harga,
        stok_sistem=product.stok_sistem or 0,
        stok_booking=product.stok_booking or 0,
        stok_tersedia=stok_tersedia,
        perlu_ditinjau=(
            is_review_needed if current_user["role"] == "ADMIN" else None
        ),
    )


@router.put("/{product_id}/stock", response_model=ProductResponse)
def update_product_stock(
    product_id: str,
    stock_update: ProductUpdateStock,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_admin),
):
    product = db.query(Product).filter(Product.id == product_id).first()
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
    )


@router.post("/sync", response_model=SyncResultResponse)
def sync_products(
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    _current_user: CurrentUser = Depends(require_admin),
):
    sync_result = sync_products_from_sheets(db)
    return SyncResultResponse(
        success=sync_result["success"],
        total_rows=sync_result["total_rows"],
        inserted=sync_result["inserted"],
        updated=sync_result["updated"],
        skipped=sync_result["skipped"],
        errors=sync_result["errors"],
    )


@router.get("/sync/errors", response_model=List[dict])
def get_sync_errors(
    db: Session = Depends(get_db),
    _current_user: CurrentUser = Depends(require_admin),
):
    result = db.execute(
        text(
            "SELECT id, product_id, sumber, field_terdampak, delta, "
            "nilai_sebelum, nilai_sesudah, created_at "
            "FROM stok_log WHERE sumber = 'SYNC' "
            "ORDER BY created_at DESC LIMIT 100"
        )
    ).fetchall()

    return [
        {
            "id": str(row.id),
            "product_id": row.product_id,
            "sumber": row.sumber,
            "field_terdampak": row.field_terdampak,
            "delta": row.delta,
            "nilai_sebelum": row.nilai_sebelum,
            "nilai_sesudah": row.nilai_sesudah,
            "created_at": str(row.created_at),
        }
        for row in result
    ]
