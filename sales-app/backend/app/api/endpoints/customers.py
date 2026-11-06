"""Customer API endpoints - CRUD, Excel import, sales assignment."""
from datetime import datetime, timezone
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Response, UploadFile, File, status
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
    CustomerListResponse,
    CustomerResponse,
    CustomerUpdate,
    KodeAreaListResponse,
    SalesAssignmentItem,
    SyncResultResponse,
)
from app.core.security import (
    require_admin_or_supervisor,
    require_auth,
    require_write_access,
    apply_branch_filter,
    branch_guard,
    CurrentUser,
)
from app.core import branch as branch_constants
from app.core.visibility import visible_customer_query, validate_order_customer_for_sales
from app.services.customer_sync import sync_customers_from_excel

router = APIRouter(prefix="/customers", tags=["Customers"])

# Hard cap for uploaded Excel files (10 MiB) to avoid memory-exhaustion DoS.
MAX_EXCEL_UPLOAD_BYTES = 10 * 1024 * 1024


def _customer_to_response(c: Customer) -> CustomerResponse:
    """Build CustomerResponse. Adds branch_nama via cache (single lookup)."""
    return CustomerResponse(
        id=c.id,
        branch=c.branch,
        branch_nama=branch_constants.get_branch_nama(c.branch),
        kode=c.kode,
        nama_toko=c.nama_toko,
        alamat=c.alamat,
        kode_area=c.kode_area,
        created_at=c.created_at,
        updated_at=c.updated_at,
        deleted_at=c.deleted_at,
    )


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
    current_user: CurrentUser = Depends(require_auth),
):
    query = _exclude_deleted(db.query(Customer))
    if current_user.get("role") == "SALES":
        # SALES must use the same 3-tier visibility rule as /customers/my.
        query = visible_customer_query(db, current_user)
    query = apply_branch_filter(query, Customer, current_user)
    if search:
        query = query.filter(Customer.nama_toko.ilike(f"%{search}%"))
    return [_customer_to_response(c) for c in query.order_by(Customer.nama_toko).offset(skip).limit(limit).all()]


@router.get("/count")
def get_customer_count(
    search: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_auth),
):
    """Total customers matching current filter - for pagination UI."""
    query = _exclude_deleted(db.query(func.count(Customer.id)))
    if current_user.get("role") == "SALES":
        vis = visible_customer_query(db, current_user)
        query = vis.with_entities(func.count(Customer.id))
    query = apply_branch_filter(query, Customer, current_user)
    if search:
        query = query.filter(Customer.nama_toko.ilike(f"%{search}%"))
    return {"total": query.scalar() or 0}


@router.get("/my", response_model=List[CustomerListResponse])
def list_my_customers(
    response: Response,
    search: Optional[str] = None,
    skip: int = 0,
    limit: int = Query(3000, ge=1, le=3000),
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

    Query sengaja memilih 5 kolom saja (bukan seluruh row Customer) karena
    endpoint ini dipanggil setiap order flow dibuka. Kolom branch/timestamp
    tidak dipakai UI list dan hanya menambah egress Supabase.
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
    # Izinkan browser (sales_web) memakai cache sebentar supaya repeat-open
    # order flow tidak selalu menembak DB. Mobile native tetap memakai cache
    # in-memory di CustomerRepository.
    response.headers["Cache-Control"] = "private, max-age=300"

    rows = (
        query.with_entities(
            Customer.id,
            Customer.kode,
            Customer.nama_toko,
            Customer.alamat,
            Customer.kode_area,
        )
        .order_by(Customer.nama_toko)
        .offset(skip)
        .limit(limit)
        .all()
    )
    return [
        CustomerListResponse(
            id=row.id,
            kode=row.kode,
            nama_toko=row.nama_toko,
            alamat=row.alamat,
            kode_area=row.kode_area,
        )
        for row in rows
    ]


@router.get("/kode-areas", response_model=KodeAreaListResponse)
def list_kode_areas(
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_auth),
):
    """Distinct kode_area dari customers - sumber dropdown di mobile
    submission form. Sales boleh membuat kode_area baru yang tidak ada
    di list (free-text fallback di form, tidak ada 409/422).
    Branch-scoped: ADMIN/SUPERVISOR sees only their branch's kode_areas.
    SALES sees only their accessible areas (via visibility query).
    MANAGER sees all.

    Auth: require_auth (bukan require_manager) karena sales butuh akses
    untuk isi form pengajuan customer. Data yang dikembalikan (list of
    strings) tidak sensitif - tidak ada info sales-roster.
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
    items = []
    for r in rows:
        val = r[0] if hasattr(r, '__getitem__') else r
        if isinstance(val, tuple):
            val = val[0]
        items.append(val)
    return KodeAreaListResponse(items=items)


@router.post("", response_model=CustomerResponse, status_code=201)
def create_customer(
    customer: CustomerCreate,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_write_access),
):
    """Identity toko = (nama_toko, alamat) - kedua kolom wajib dan dicocokkan
    case-insensitive. Boleh ada dua toko dengan nama sama selama alamatnya beda.
    Branch is set to the admin's branch (enforced via apply_branch_filter on list)."""
    nama_norm = customer.nama_toko.strip().lower()
    alamat_norm = customer.alamat.strip().lower()

    user_branch = current_user.get("branch")
    # Customer rows must always belong to a branch; a NULL branch would make
    # the row invisible to every scope (and historically leaked globally).
    if not user_branch:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Akun Anda belum memiliki cabang. Hubungi manager.",
        )

    existing = _exclude_deleted(
        db.query(Customer)
        .filter(Customer.branch == user_branch)
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

    new_customer = Customer(**customer.model_dump(), branch=user_branch)
    db.add(new_customer)
    db.commit()
    db.refresh(new_customer)
    return _customer_to_response(new_customer)


@router.put("/{customer_id}", response_model=CustomerResponse)
def update_customer(
    customer_id: UUID,
    update: CustomerUpdate,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_write_access),
):
    customer = _exclude_deleted(
        db.query(Customer).filter(Customer.id == customer_id)
    ).first()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer tidak ditemukan")
    # Branch access check
    branch_guard(current_user, customer.branch)

    data = update.model_dump(exclude_unset=True)
    for field, value in data.items():
        setattr(customer, field, value)
    db.commit()
    db.refresh(customer)
    return _customer_to_response(customer)


@router.get("/{customer_id}", response_model=CustomerResponse)
def get_customer(
    customer_id: UUID,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_auth),
):
    customer = _exclude_deleted(
        db.query(Customer).filter(Customer.id == customer_id)
    ).first()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer tidak ditemukan")
    if current_user.get("role") == "SALES":
        # SALES may only read customers they can see/order (3-tier rule).
        customer = validate_order_customer_for_sales(db, current_user, customer_id)
    else:
        branch_guard(current_user, customer.branch)
    return _customer_to_response(customer)


@router.get("/{customer_id}/assignments", response_model=List[SalesAssignmentItem])
def list_customer_assignments(
    customer_id: UUID,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_write_access),
):
    """List sales yang di-assign ke customer ini. Manager + admin only."""
    customer = _exclude_deleted(
        db.query(Customer).filter(Customer.id == customer_id)
    ).first()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer tidak ditemukan")
    branch_guard(current_user, customer.branch)
    return _list_assignments(customer_id, db)


@router.put("/{customer_id}/assignments", response_model=List[SalesAssignmentItem])
def put_customer_assignments(
    customer_id: UUID,
    body: CustomerAssignmentsPut,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_write_access),
):
    """Replace full set of sales assigned to a customer. Idempotent.
    Empty sales_ids = unassign everyone (customer jadi visible-to-all).
    Branch access check applied."""
    customer = _exclude_deleted(
        db.query(Customer).filter(Customer.id == customer_id)
    ).first()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer tidak ditemukan")
    branch_guard(current_user, customer.branch)

    # Validasi setiap sales_id: harus SALES, is_active, tidak soft-deleted,
    # dan (untuk non-global-manager) berada di branch customer yang sama.
    if body.sales_ids:
        q = db.query(User).filter(
            User.id.in_(body.sales_ids),
            User.role == "SALES",
            User.is_active.is_(True),
            User.deleted_at.is_(None),
            User.branch == customer.branch,
        )
        valid = q.all()
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
    current_user: CurrentUser = Depends(require_write_access),
):
    customer = _exclude_deleted(
        db.query(Customer).filter(Customer.id == customer_id)
    ).first()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer tidak ditemukan")
    branch_guard(current_user, customer.branch)

    customer.deleted_at = datetime.now(timezone.utc)
    db.commit()
    return None


@router.post("/import-excel", response_model=SyncResultResponse)
def import_excel(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_write_access),
):
    if not file.filename or not file.filename.lower().endswith(".xlsx"):
        raise HTTPException(status_code=400, detail="Format file harus .xlsx")

    contents = file.file.read(MAX_EXCEL_UPLOAD_BYTES + 1)
    if len(contents) > MAX_EXCEL_UPLOAD_BYTES:
        raise HTTPException(
            status_code=413,
            detail=(
                "File terlalu besar. Maksimal "
                f"{MAX_EXCEL_UPLOAD_BYTES // (1024 * 1024)} MB."
            ),
        )
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
