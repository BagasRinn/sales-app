"""Sales-centric endpoints — list customer assigned to a sales user, plus area assignments."""
from typing import List
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.database import get_db
from app.models.models import (
    AreaAssignment,
    Customer,
    CustomerAssignment,
    User,
)
from app.schemas.schemas import (
    AreaAssignmentListItem,
    AreaAssignmentsPut,
    CustomerResponse,
    SalesAssignmentItem,
)
from app.core.security import require_manager, apply_branch_filter, CurrentUser

router = APIRouter(prefix="/sales", tags=["Sales"])


@router.get("/{sales_id}/customers", response_model=List[CustomerResponse])
def list_sales_customers(
    sales_id: UUID,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_manager),
):
    """Semua customer yang visible untuk sales ini (hybrid: area + direct override).
    Manager + admin only — untuk tab 'Per Sales' di admin web."""
    user = db.query(User).filter(
        User.id == sales_id,
        User.deleted_at.is_(None),
    ).first()
    if not user:
        raise HTTPException(status_code=404, detail="User tidak ditemukan")

    # Subquery: area yang di-cover sales ini
    my_areas_subq = (
        db.query(AreaAssignment.kode_area)
        .filter(AreaAssignment.sales_id == sales_id)
        .subquery()
    )
    # Subquery: customer yang di-assign langsung ke sales ini
    my_direct_subq = (
        db.query(CustomerAssignment.customer_id)
        .filter(CustomerAssignment.sales_id == sales_id)
        .subquery()
    )

    rows = (
        db.query(Customer)
        .filter(
            Customer.deleted_at.is_(None),
        )
        .filter(
            # Direct override ATAU area coverage. Exclude 'unassigned fallback'
            # (kode_area null AND no direct) — itu bukan assignment spesifik.
            (Customer.id.in_(my_direct_subq)) |
            (Customer.kode_area.in_(my_areas_subq))
        )
    )
    # Apply branch filter
    rows = apply_branch_filter(rows, Customer, current_user)
    rows = rows.order_by(Customer.kode_area, Customer.nama_toko).all()
    return rows


# ==================== Area assignment endpoints ====================

def _list_area_assignments(db: Session, current_user: dict) -> List[AreaAssignmentListItem]:
    """Return all distinct kode_area dengan sales yang di-assign.
    Areas tanpa assignment TETAP di-include (sales=[]), supaya manager bisa
    lihat area mana yang belum di-handle.
    Branch-scoped: only returns areas from customers in the same branch."""
    # Subquery: distinct kode_area dari customer (exclude null), filtered by branch
    customer_areas_subq = (
        db.query(Customer.kode_area)
        .filter(Customer.deleted_at.is_(None), Customer.kode_area.isnot(None))
    )
    customer_areas_subq = apply_branch_filter(customer_areas_subq, Customer, current_user)
    customer_areas_subq = customer_areas_subq.distinct().subquery()
    # Pakai select() explicit supaya tidak kena SAWarning "Coercing Subquery
    # object into a select()".
    from sqlalchemy import select
    customer_areas_subq_select = select(customer_areas_subq.c.kode_area).subquery()
    # LEFT JOIN ke area_assignments + User
    rows = (
        db.query(AreaAssignment, User)
        .outerjoin(
            User,
            (User.id == AreaAssignment.sales_id) & (User.deleted_at.is_(None)),
        )
        .filter(AreaAssignment.kode_area.in_(customer_areas_subq_select))
        .order_by(AreaAssignment.kode_area, User.username)
        .all()
    )
    # Group by kode_area
    grouped: dict[str, List[SalesAssignmentItem]] = {}
    for ca, user in rows:
        grouped.setdefault(ca.kode_area, []).append(
            SalesAssignmentItem(
                sales_id=ca.sales_id,
                sales_username=user.username if user else None,
                sales_nama=user.nama if user else None,
                assigned_at=ca.assigned_at,
            )
        )
    # Include area tanpa assignment
    all_areas = [r[0] for r in db.query(customer_areas_subq.c.kode_area).all()]
    return [
        AreaAssignmentListItem(kode_area=area, sales=grouped.get(area, []))
        for area in sorted(all_areas)
    ]


@router.get("/area-assignments", response_model=List[AreaAssignmentListItem])
def list_area_assignments(
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_manager),
):
    """List semua distinct kode_area (dari customer) dengan sales assigned-nya.
    Manager + admin only — untuk tab 'Penugasan Sales' sub-view 'Per Area'."""
    return _list_area_assignments(db, current_user)


@router.get("/area-assignments/{kode_area}", response_model=List[SalesAssignmentItem])
def list_area_assignment_detail(
    kode_area: str,
    db: Session = Depends(get_db),
    _current_user: CurrentUser = Depends(require_manager),
):
    """List sales yang di-assign ke kode_area tertentu."""
    rows = (
        db.query(AreaAssignment, User)
        .outerjoin(
            User,
            (User.id == AreaAssignment.sales_id) & (User.deleted_at.is_(None)),
        )
        .filter(AreaAssignment.kode_area == kode_area)
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


@router.put("/area-assignments/{kode_area}", response_model=List[SalesAssignmentItem])
def put_area_assignment(
    kode_area: str,
    body: AreaAssignmentsPut,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_manager),
):
    """Replace full set of sales assigned to kode_area. Idempotent.
    Empty sales_ids = unassign semua sales dari area ini (customer di area
    kembali ke 'unassigned' state, visible to all sales)."""
    # Validasi setiap sales_id: harus SALES, is_active, tidak soft-deleted
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
        # Branch validation: all sales must be in same branch as creator
        user_branch = current_user.get("branch")
        if user_branch is not None:
            for u in valid:
                if u.branch != user_branch:
                    raise HTTPException(
                        status_code=400,
                        detail=f"Sales '{u.username}' tidak berada di branch ini",
                    )

    # Idempotent replace
    db.query(AreaAssignment).filter(
        AreaAssignment.kode_area == kode_area
    ).delete()
    actor_id = UUID(current_user["user_id"])
    for sales_id in body.sales_ids:
        db.add(AreaAssignment(
            kode_area=kode_area,
            sales_id=sales_id,
            assigned_by=actor_id,
        ))
    db.commit()
    return list_area_assignment_detail(kode_area, db)
