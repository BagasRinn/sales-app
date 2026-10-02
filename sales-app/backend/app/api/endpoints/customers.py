"""Customer API endpoints — CRUD, Excel import."""
from datetime import datetime, timezone
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy import func, or_
from sqlalchemy.orm import Session
from uuid import UUID

from app.models.database import get_db
from app.models.models import Customer, ImportLog
from app.schemas.schemas import (
    CustomerCreate,
    CustomerUpdate,
    CustomerResponse,
    SyncResultResponse,
)
from app.core.security import require_manager, require_auth, CurrentUser
from app.services.customer_sync import sync_customers_from_excel

router = APIRouter(prefix="/customers", tags=["Customers"])


def _exclude_deleted(query):
    return query.filter(Customer.deleted_at.is_(None))


@router.get("", response_model=List[CustomerResponse])
def list_customers(
    skip: int = 0,
    limit: int = 50,
    search: Optional[str] = None,
    db: Session = Depends(get_db),
    _current_user: CurrentUser = Depends(require_manager),
):
    query = _exclude_deleted(db.query(Customer))
    if search:
        query = query.filter(Customer.nama_toko.ilike(f"%{search}%"))
    return query.order_by(Customer.nama_toko).offset(skip).limit(limit).all()


@router.get("/count")
def get_customer_count(
    search: Optional[str] = None,
    db: Session = Depends(get_db),
    _current_user: CurrentUser = Depends(require_manager),
):
    """Total customers matching current filter — for pagination UI."""
    query = _exclude_deleted(db.query(func.count(Customer.id)))
    if search:
        query = query.filter(Customer.nama_toko.ilike(f"%{search}%"))
    return {"total": query.scalar() or 0}


@router.get("/my", response_model=List[CustomerResponse])
def list_my_customers(
    search: Optional[str] = None,
    skip: int = 0,
    limit: int = 1000,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_auth),
):
    """Semua customer — semua sales dapat melihat dan membuat order untuk semua toko.
    Limit dinaikkan ke 1000 supaya mobile (yang belum paginai) ngga kehilangan
    customer di luar 100 pertama urut nama_toko. Search cocokkan nama/kode/alamat."""
    query = _exclude_deleted(db.query(Customer))
    if search:
        pattern = f"%{search}%"
        query = query.filter(
            or_(
                Customer.nama_toko.ilike(pattern),
                Customer.kode.ilike(pattern),
                Customer.alamat.ilike(pattern),
            )
        )
    return query.order_by(Customer.nama_toko).offset(skip).limit(limit).all()


@router.post("", response_model=CustomerResponse, status_code=201)
def create_customer(
    customer: CustomerCreate,
    db: Session = Depends(get_db),
    _current_user: CurrentUser = Depends(require_manager),
):
    """Identity toko = (nama_toko, alamat) — kedua kolom wajib dan dicocokkan
    case-insensitive. Boleh ada dua toko dengan nama sama selama alamatnya beda."""
    nama_norm = customer.nama_toko.strip().lower()
    alamat_norm = customer.alamat.strip().lower()

    existing = _exclude_deleted(
        db.query(Customer)
        .filter(func.lower(Customer.nama_toko) == nama_norm)
        .filter(func.lower(Customer.alamat) == alamat_norm)
    ).first()
    if existing:
        raise HTTPException(
            status_code=409,
            detail=(
                f"Toko dengan nama '{customer.nama_toko}' dan alamat "
                f"'{customer.alamat}' sudah ada."
            ),
        )

    new_customer = Customer(**customer.model_dump())
    db.add(new_customer)
    db.commit()
    db.refresh(new_customer)
    return new_customer


@router.put("/{customer_id}", response_model=CustomerResponse)
def update_customer(
    customer_id: UUID,
    update: CustomerUpdate,
    db: Session = Depends(get_db),
    _current_user: CurrentUser = Depends(require_manager),
):
    customer = _exclude_deleted(
        db.query(Customer).filter(Customer.id == customer_id)
    ).first()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer tidak ditemukan")

    data = update.model_dump(exclude_unset=True)
    for field, value in data.items():
        setattr(customer, field, value)
    db.commit()
    db.refresh(customer)
    return customer


@router.get("/{customer_id}", response_model=CustomerResponse)
def get_customer(
    customer_id: UUID,
    db: Session = Depends(get_db),
    _current_user: CurrentUser = Depends(require_manager),
):
    customer = _exclude_deleted(
        db.query(Customer).filter(Customer.id == customer_id)
    ).first()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer tidak ditemukan")
    return customer


@router.delete("/{customer_id}", status_code=204)
def delete_customer(
    customer_id: UUID,
    db: Session = Depends(get_db),
    _current_user: CurrentUser = Depends(require_manager),
):
    customer = _exclude_deleted(
        db.query(Customer).filter(Customer.id == customer_id)
    ).first()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer tidak ditemukan")

    customer.deleted_at = datetime.now(timezone.utc)
    db.commit()
    return None


@router.post("/import-excel", response_model=SyncResultResponse)
def import_excel(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    _current_user: CurrentUser = Depends(require_manager),
):
    if not file.filename or not file.filename.lower().endswith(".xlsx"):
        raise HTTPException(status_code=400, detail="Format file harus .xlsx")

    contents = file.file.read()
    if len(contents) == 0:
        raise HTTPException(status_code=400, detail="File kosong")

    sync_result = sync_customers_from_excel(
        contents, db,
        current_user={
            "user_id": _current_user["user_id"],
            "nama": _current_user.get("nama"),
        },
        file_name=file.filename,
    )

    return SyncResultResponse(
        success=sync_result["success"],
        total_rows=sync_result["total_rows"],
        inserted=sync_result["inserted"],
        updated=sync_result["updated"],
        skipped=sync_result["skipped"],
        errors=sync_result["errors"],
        needs_review=sync_result.get("needs_review", False),
    )
