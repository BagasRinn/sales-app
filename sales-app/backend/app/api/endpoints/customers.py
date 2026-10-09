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
    KodeAreaListResponse,
    SalesAssignmentItem,
    SyncResultResponse,
)
from app.core.security import require_admin_or_supervisor, require_auth, apply_branch_filter, CurrentUser
from app.core.visibility import visible_customer_query
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
    current_user: CurrentUser = Depends(require_admin_or_supervisor),
):
    query = _exclude_deleted(db.query(Customer))
    query = apply_branch_filter(query, Customer, current_user)
    if search:
        query = query.filter(Customer.nama_toko.ilike(f"%{search}%"))
    return query.order_by(Customer.nama_toko).offset(skip).limit(limit).all()


@router.get("/count")
def get_customer_count(
    search: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_admin_or_supervisor),
):
    """Total customers matching current filter — for pagination UI."""
    query = _exclude_deleted(db.query(func.count(Customer.id)))
    query = apply_branch_filter(query, Customer, current_user)
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

    - ADMIN/SUPERVISOR: semua customer di branch mereka (filtered via apply_branch_filter).
    - MANAGER (global): semua customer di semua branch.
    - SALES: customer yang COCOK dengan salah satu dari (semua di-OR):
        * `customer_assignments` punya row untuk sales ini (per-customer override)
        * `area_assignments` punya row untuk sales ini DAN customer.kode_area
          cocok dengan area_assignments.kode_area (default coverage by area)
        * customer tanpa assignment dan customer.kode_area tanpa assignment
          (unassigned = visible to all, backward-compat untuk gradual rollout)
    Branch filter applied via apply_branch_filter for ADMIN/SUPERVISOR/MANAGER.

    Limit dinaikkan ke 3000 (sebelumnya 1000) supaya muat ~2025 customer
    untuk sales. Mobile belum paginate jadi list harus include semua customer
    yang visible dalam 1 fetch. Kalau di masa depan >> 3000, switch mobile
    ke pagination proper.
    """
    if current_user["role"] in ("ADMIN", "SUPERVISOR", "MANAGER"):
        query = _exclude_deleted(db.query(Customer))
        query = apply_branch_filter(query, Customer, current_user)
    else:
        query = visible_customer_query(db, current_user)
        # Apply branch filter on top for SALES
        query = apply_branch_filter(query, Customer, current_user)

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


@router.get("/kode-areas", response_model=KodeAreaListResponse)
def list_kode_areas(
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_auth),
):
    """Distinct kode_area dari customers — sumber dropdown di mobile
    submission form. Sales boleh membuat kode_area baru yang tidak ada
    di list (free-text fallback di form, tidak ada 409/422).
    Branch-scoped: ADMIN/SUPERVISOR sees only their branch's kode_areas.
    SALES sees only their accessible areas (via visibility query).
    MANAGER sees all.

    Auth: require_auth (bukan require_manager) karena sales butuh akses
    untuk isi form pengajuan customer. Data yang dikembalikan (list of
    strings) tidak sensitif — tidak ada info sales-roster.
    """
    if current_user["role"] in ("ADMIN", "SUPERVISOR", "MANAGER"):
        rows = (
            db.query(Customer.kode_area)
            .filter(Customer.deleted_at.is_(None), Customer.kode_area.isnot(None))
        )
        rows = apply_branch_filter(rows, Customer, current_user)
        rows = rows.distinct().order_by(Customer.kode_area).all()
    else:
        # SALES: get kode_areas from visible customers
        vis_q = visible_customer_query(db, current_user)
        vis_q = apply_branch_filter(vis_q, Customer, current_user)
        rows = (
            vis_q.filter(Customer.kode_area.isnot(None))
            .with_entities(Customer.kode_area)
            .distinct()
            .order_by(Customer.kode_area)
            .all()
        )
    return KodeAreaListResponse(items=[r[0] if isinstance(r, tuple) else r for r in rows])


@router.post("", response_model=CustomerResponse, status_code=201)
def create_customer(
    customer: CustomerCreate,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_admin_or_supervisor),
):
    """Identity toko = (nama_toko, alamat) — kedua kolom wajib dan dicocokkan
    case-insensitive. Boleh ada dua toko dengan nama sama selama alamatnya beda.
    Branch is set to the admin's branch (enforced via apply_branch_filter on list)."""
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

    user_branch = current_user.get("branch")
    new_customer = Customer(**customer.model_dump(), branch=user_branch)
    db.add(new_customer)
    db.commit()
    db.refresh(new_customer)
    return new_customer


@router.put("/{customer_id}", response_model=CustomerResponse)
def update_customer(
    customer_id: UUID,
    update: CustomerUpdate,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_admin_or_supervisor),
):
    customer = _exclude_deleted(
        db.query(Customer).filter(Customer.id == customer_id)
    ).first()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer tidak ditemukan")
    # Branch access check
    if current_user.get("role") != "MANAGER" and current_user.get("branch") is not None:
        if customer.branch != current_user["branch"]:
            raise HTTPException(status_code=403, detail="Tidak memiliki akses ke customer ini")

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
    current_user: CurrentUser = Depends(require_admin_or_supervisor),
):
    customer = _exclude_deleted(
        db.query(Customer).filter(Customer.id == customer_id)
    ).first()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer tidak ditemukan")
    if current_user.get("role") != "MANAGER" and current_user.get("branch") is not None:
        if customer.branch != current_user["branch"]:
            raise HTTPException(status_code=403, detail="Tidak memiliki akses ke customer ini")
    return customer


@router.get("/{customer_id}/assignments", response_model=List[SalesAssignmentItem])
def list_customer_assignments(
    customer_id: UUID,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_admin_or_supervisor),
):
    """List sales yang di-assign ke customer ini. Manager + admin only."""
    customer = _exclude_deleted(
        db.query(Customer).filter(Customer.id == customer_id)
    ).first()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer tidak ditemukan")
    if current_user.get("role") != "MANAGER" and current_user.get("branch") is not None:
        if customer.branch != current_user["branch"]:
            raise HTTPException(status_code=403, detail="Tidak memiliki akses ke customer ini")
    return _list_assignments(customer_id, db)


@router.put("/{customer_id}/assignments", response_model=List[SalesAssignmentItem])
def put_customer_assignments(
    customer_id: UUID,
    body: CustomerAssignmentsPut,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_admin_or_supervisor),
):
    """Replace full set of sales assigned to a customer. Idempotent.
    Empty sales_ids = unassign everyone (customer jadi visible-to-all).
    Branch access check applied."""
    customer = _exclude_deleted(
        db.query(Customer).filter(Customer.id == customer_id)
    ).first()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer tidak ditemukan")
    if current_user.get("role") != "MANAGER" and current_user.get("branch") is not None:
        if customer.branch != current_user["branch"]:
            raise HTTPException(status_code=403, detail="Tidak memiliki akses ke customer ini")

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
    current_user: CurrentUser = Depends(require_admin_or_supervisor),
):
    customer = _exclude_deleted(
        db.query(Customer).filter(Customer.id == customer_id)
    ).first()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer tidak ditemukan")
    if current_user.get("role") != "MANAGER" and current_user.get("branch") is not None:
        if customer.branch != current_user["branch"]:
            raise HTTPException(status_code=403, detail="Tidak memiliki akses ke customer ini")

    customer.deleted_at = datetime.now(timezone.utc)
    db.commit()
    return None


@router.post("/import-excel", response_model=SyncResultResponse)
def import_excel(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_admin_or_supervisor),
):
    if not file.filename or not file.filename.lower().endswith(".xlsx"):
        raise HTTPException(status_code=400, detail="Format file harus .xlsx")

    contents = file.file.read()
    if len(contents) == 0:
        raise HTTPException(status_code=400, detail="File kosong")

    sync_result = sync_customers_from_excel(
        contents, db,
        current_user={
            "user_id": current_user["user_id"],
            "nama": current_user.get("nama"),
            "branch": current_user.get("branch"),
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
