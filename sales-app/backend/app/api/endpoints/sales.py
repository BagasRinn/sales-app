"""Sales-centric endpoints - list customer assigned to a sales user, plus area assignments."""
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
from app.core.security import require_admin_or_supervisor, require_auth, require_supervisor_or_manager_global, apply_branch_filter, CurrentUser

router = APIRouter(prefix="/sales", tags=["Sales"])


@router.get("/{sales_id}/customers", response_model=List[CustomerResponse])
def list_sales_customers(
    sales_id: UUID,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_auth),
):
    """Semua customer yang visible untuk sales ini (hybrid: area + direct override).
    Admin + supervisor only - untuk tab 'Per Sales' di admin web."""
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
            # (kode_area null AND no direct) - itu bukan assignment spesifik.
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
    Branch-scoped: only returns areas from customers in the same branch,
    dan hanya sales assignment di branch yang sama."""
    user_branch = current_user.get("branch")
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
    # LEFT JOIN ke area_assignments + User, FILTER BY BRANCH supaya area
    # bernama sama di branch lain tidak ikut kelihatan (bug: sebelumnya
    # `area_assignments` tidak punya kolom branch, jadi semua branch
    # di-mix jadi satu. Migration `migrate_2026_10_10_06_area_assignments_branch`
    # fix dengan composite PK).
    aa_q = (
        db.query(AreaAssignment, User)
        .outerjoin(
            User,
            (User.id == AreaAssignment.sales_id) & (User.deleted_at.is_(None)),
        )
        .filter(AreaAssignment.kode_area.in_(select(customer_areas_subq.c.kode_area)))
    )
    if user_branch is not None:
        aa_q = aa_q.filter(AreaAssignment.branch == user_branch)
    rows = aa_q.order_by(AreaAssignment.kode_area, User.username).all()
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
    # Include area tanpa assignment (filtered by customer branch via subquery)
    all_areas = [r[0] for r in db.query(customer_areas_subq.c.kode_area).all()]
    return [
        AreaAssignmentListItem(kode_area=area, sales=grouped.get(area, []))
        for area in sorted(all_areas)
    ]


@router.get("/area-assignments", response_model=List[AreaAssignmentListItem])
def list_area_assignments(
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_auth),
):
    """List semua distinct kode_area (dari customer) dengan sales assigned-nya.
    Branch-scoped — hanya dari branch user yang login. MANAGER (branch=NULL)
    lihat semua branch."""
    return _list_area_assignments(db, current_user)


@router.get("/area-assignments/{kode_area}", response_model=List[SalesAssignmentItem])
def list_area_assignment_detail(
    kode_area: str,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_auth),
):
    """List sales yang di-assign ke kode_area tertentu. Branch-scoped."""
    user_branch = current_user.get("branch")
    q = (
        db.query(AreaAssignment, User)
        .outerjoin(
            User,
            (User.id == AreaAssignment.sales_id) & (User.deleted_at.is_(None)),
        )
        .filter(AreaAssignment.kode_area == kode_area)
    )
    if user_branch is not None:
        q = q.filter(AreaAssignment.branch == user_branch)
    rows = q.order_by(User.username).all()
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
    current_user: CurrentUser = Depends(require_supervisor_or_manager_global),
):
    """Replace full set of sales assigned to kode_area. Idempotent.
    Empty sales_ids = unassign semua sales dari area ini (customer di area
    kembali ke 'unassigned' state, visible to all sales).

    Branch-scoped: assignment di-tag dengan current_user.branch (atau bypass
    untuk MANAGER global). Hanya sales dalam branch user yang boleh di-assign.
    """
    user_branch = current_user.get("branch")
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
        if user_branch is not None:
            for u in valid:
                if u.branch != user_branch:
                    raise HTTPException(
                        status_code=400,
                        detail=f"Sales '{u.username}' tidak berada di branch ini",
                    )

    # Idempotent replace — DELETE only untuk branch ini (untuk MANAGER branch
    # NULL: hapus semua row karena global). Preserve rows di branch lain agar
    # assignment tidak ikut ter-clear di tempat lain.
    del_q = db.query(AreaAssignment).filter(
        AreaAssignment.kode_area == kode_area,
    )
    if user_branch is not None:
        del_q = del_q.filter(AreaAssignment.branch == user_branch)
    del_q.delete(synchronize_session=False)

    actor_id = UUID(current_user["user_id"])
    # Hanya insert kalau caller bukan MANAGER-guest (no-branch). Kalau user
    # branch None, assignment tetap di-tag NULL (gagal NOT NULL constraint)
    # — tolak awal dengan HTTPException.
    if user_branch is None:
        raise HTTPException(
            status_code=400,
            detail=(
                "MANAGER global tidak bisa assign area — area harus di-scope "
                "ke branch tertentu. Login sebagai admin/supervisor branch "
                "yang relevan."
            ),
        )
    for sales_id in body.sales_ids:
        db.add(AreaAssignment(
            branch=user_branch,
            kode_area=kode_area,
            sales_id=sales_id,
            assigned_by=actor_id,
        ))
    db.commit()
    return list_area_assignment_detail(kode_area, db, current_user)
