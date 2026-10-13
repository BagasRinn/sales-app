"""Per-supplier monthly target CRUD endpoints.

Read is open to any authenticated user (branch-scoped via apply_branch_filter).
Write (PUT, DELETE) is restricted to ADMIN or SUPERVISOR via
require_admin_or_supervisor; SALES users get 403.
"""
from datetime import datetime, timezone
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.models.database import get_db
from app.models.models import SupplierTarget
from app.schemas.schemas import (
    SupplierTargetUpdate,
    SupplierTargetResponse,
)
from app.core.security import (
    require_admin_or_supervisor,
    require_auth,
    apply_branch_filter,
    CurrentUser,
)

router = APIRouter(prefix="/supplier-targets", tags=["Supplier Targets"])


@router.get("", response_model=List[SupplierTargetResponse])
def list_supplier_targets(
    period: Optional[str] = Query(None, description="Filter by period (YYYY-MM)"),
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_auth),
):
    """List supplier targets for the user's branch, optionally filtered by period."""
    query = db.query(SupplierTarget)
    query = apply_branch_filter(query, SupplierTarget, current_user)
    if period:
        query = query.filter(SupplierTarget.period == period)
    return query.order_by(
        SupplierTarget.branch,
        SupplierTarget.supplier_name,
        SupplierTarget.period.desc(),
    ).all()


@router.put("/{branch}/{supplier_name}/{period}", response_model=SupplierTargetResponse)
def upsert_supplier_target(
    branch: str,
    supplier_name: str,
    period: str,
    payload: SupplierTargetUpdate,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_admin_or_supervisor),
):
    """Set or update a supplier's monthly target. Upserts on (branch,
    supplier_name, period). Branch-scoped: ADMIN/SUPERVISOR can only
    set targets for their own branch."""
    # Branch access check: branch-scoped admin/supervisor can't write
    # targets for a different branch.
    if current_user.get("branch") is not None and current_user["branch"] != branch:
        raise HTTPException(
            status_code=403,
            detail="Tidak bisa mengatur target untuk branch lain",
        )
    if payload.target_value < 0:
        raise HTTPException(
            status_code=400,
            detail="target_value harus >= 0",
        )

    existing = (
        db.query(SupplierTarget)
        .filter(
            SupplierTarget.branch == branch,
            SupplierTarget.supplier_name == supplier_name,
            SupplierTarget.period == period,
        )
        .first()
    )
    if existing:
        existing.target_value = payload.target_value
        existing.updated_at = datetime.now(timezone.utc)
        target = existing
    else:
        target = SupplierTarget(
            branch=branch,
            supplier_name=supplier_name,
            period=period,
            target_value=payload.target_value,
        )
        db.add(target)

    db.commit()
    db.refresh(target)
    return target


@router.delete("/{branch}/{supplier_name}/{period}", status_code=204)
def delete_supplier_target(
    branch: str,
    supplier_name: str,
    period: str,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_admin_or_supervisor),
):
    """Delete a supplier's target for a (branch, period)."""
    if current_user.get("branch") is not None and current_user["branch"] != branch:
        raise HTTPException(
            status_code=403,
            detail="Tidak bisa menghapus target untuk branch lain",
        )
    row = (
        db.query(SupplierTarget)
        .filter(
            SupplierTarget.branch == branch,
            SupplierTarget.supplier_name == supplier_name,
            SupplierTarget.period == period,
        )
        .first()
    )
    if not row:
        raise HTTPException(status_code=404, detail="Target not found")
    db.delete(row)
    db.commit()
    return None
