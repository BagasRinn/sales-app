"""Customer API endpoints — CRUD, Excel import, sales assignment."""
from datetime import datetime, timezone
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy import and_, func, or_
from sqlalchemy.orm import Session
from uuid import UUID

from app.models.database import get_db
from app.models.models import (
    AreaAssignment,
    Customer,
    CustomerAssignment,
    ImportLog,
    User,
)
from app.schemas.schemas import (
    AreaAssignmentListItem,
    AreaAssignmentsPut,
    CustomerAssignmentsPut,
    CustomerCreate,
    CustomerResponse,
    CustomerUpdate,
    SalesAssignmentItem,
    SyncResultResponse,
)
from app.core.security import require_manager, require_auth, CurrentUser
from app.services.customer_sync import sync_customers_from_excel

router = APIRouter(prefix="/customers", tags=["Customers"])


def _exclude_deleted(query):
    return query.filter(Customer.deleted_at.is_(None))


def _list_assignments(customer_id: UUID, db: Session) -> List[SalesAssignmentItem]:
    """Return semua sales assigned ke customer_id, dengan display fields."""
    rows = (
        db.query(CustomerAssignment, User)
        .join(User, User.id == CustomerAssignment.sales_id)
        .filter(CustomerAssignment.customer_id == customer_id)
        .order_by(User.username)
        .all()
    )
    return [
        SalesAssignmentItem(
            sales_id=ca.sales_id,
            sales_username=user.username if user else None,
            sales_nama=user.nama if user else None,
            assigned_at=ca.assigned_at,
        )
        for ca, user in rows
    ]


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
    limit: int = 3000,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_auth),
):
    """Customer yang visible untuk current user.

    - ADMIN/MANAGER: semua active customer.
    - SALES: customer yang COCOK dengan salah satu dari (semua di-OR):
        * `customer_assignments` punya row untuk sales ini (per-customer override)
        * `area_assignments` punya row untuk sales ini DAN customer.kode_area
          cocok dengan area_assignments.kode_area (default coverage by area)
        * customer tanpa assignment dan customer.kode_area tanpa assignment
          (unassigned = visible to all, backward-compat untuk gradual rollout)

    Limit dinaikkan ke 3000 (sebelumnya 1000) supaya muat ~2025 customer
    untuk sales. Mobile belum paginate jadi list harus include semua customer
    yang visible dalam 1 fetch. Kalau di masa depan >> 3000, switch mobile
    ke pagination proper.
    """
    if current_user["role"] in ("ADMIN", "MANAGER"):
        query = _exclude_deleted(db.query(Customer))
    else:
        me = UUID(current_user["user_id"])
        # Pakai select() explicit (SQLAlchemy 2.x style) supaya tidak kena
        # SAWarning "Coercing Subquery object into a select()".
        from sqlalchemy import select
        # Subquery 1: customer yang punya assignment langsung ke saya
        mine_subq = (
            select(CustomerAssignment.customer_id)
            .where(CustomerAssignment.sales_id == me)
            .subquery()
        )
        # Subquery 2: kode_area yang saya cover
        my_areas_subq = (
            select(AreaAssignment.kode_area)
            .where(AreaAssignment.sales_id == me)
            .subquery()
        )
        # Subquery 3: semua customer yang punya assignment apapun (untuk NOT IN)
        all_customer_assigned = (
            select(CustomerAssignment.customer_id).subquery()
        )
        # Subquery 4: semua kode_area yang punya assignment
        all_assigned_areas = (
            select(AreaAssignment.kode_area).subquery()
        )
        query = (
            _exclude_deleted(db.query(Customer))
            .filter(
                or_(
                    # Saya di-assign langsung ke customer
                    Customer.id.in_(select(mine_subq.c.customer_id)),
                    # Customer di area yang saya cover
                    Customer.kode_area.in_(select(my_areas_subq.c.kode_area)),
                    # Unassigned: customer tanpa assignment apapun
                    # DAN customer.kode_area tanpa assignment apapun
                    and_(
                        ~Customer.id.in_(select(all_customer_assigned.c.customer_id)),
                        or_(
                            Customer.kode_area.is_(None),
                            ~Customer.kode_area.in_(select(all_assigned_areas.c.kode_area)),
                        ),
                    ),
                )
            )
        )

    if search:
        pattern = f"%{search}%"
        query = query.filter(
            or_(
                Customer.nama_toko.ilike(pattern),
                Customer.kode.ilike(pattern),
                Customer.alamat.ilike(pattern),
                Customer.kode_area.ilike(pattern),
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


@router.get("/{customer_id}/assignments", response_model=List[SalesAssignmentItem])
def list_customer_assignments(
    customer_id: UUID,
    db: Session = Depends(get_db),
    _current_user: CurrentUser = Depends(require_manager),
):
    """List sales yang di-assign ke customer ini. Manager + admin only."""
    customer = _exclude_deleted(
        db.query(Customer).filter(Customer.id == customer_id)
    ).first()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer tidak ditemukan")
    return _list_assignments(customer_id, db)


@router.put("/{customer_id}/assignments", response_model=List[SalesAssignmentItem])
def put_customer_assignments(
    customer_id: UUID,
    body: CustomerAssignmentsPut,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_manager),
):
    """Replace full set of sales assigned to a customer. Idempotent.
    Empty sales_ids = unassign everyone (customer jadi visible-to-all).
    """
    customer = _exclude_deleted(
        db.query(Customer).filter(Customer.id == customer_id)
    ).first()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer tidak ditemukan")

    # Validasi setiap sales_id: harus SALES, is_active, tidak soft-deleted.
    if body.sales_ids:
        valid = (
            db.query(User)
            .filter(
                User.id.in_(body.sales_ids),
                User.role == "SALES",
                User.is_active.is_(True),
                User.deleted_at.is_(None),
            )
            .all()
        )
        found = {str(u.id) for u in valid}
        invalid = [str(sid) for sid in body.sales_ids if str(sid) not in found]
        if invalid:
            raise HTTPException(
                status_code=400,
                detail=f"Sales ID tidak valid: {invalid}",
            )

    # Idempotent replace: delete semua assignment lama, insert yang baru.
    db.query(CustomerAssignment).filter(
        CustomerAssignment.customer_id == customer_id
    ).delete()
    actor_id = UUID(current_user["user_id"])
    for sales_id in body.sales_ids:
        db.add(CustomerAssignment(
            customer_id=customer_id,
            sales_id=sales_id,
            assigned_by=actor_id,
        ))
    db.commit()
    return _list_assignments(customer_id, db)


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
