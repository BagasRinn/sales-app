"""Sales target & incentive management endpoints — manager only."""
from datetime import datetime, timezone
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from uuid import UUID

from app.models.database import get_db
from app.models.models import SalesTarget, User
from app.schemas.schemas import (
    SalesTargetUpdate,
    SalesTargetResponse,
)
from app.core.security import require_admin_or_supervisor, require_auth, apply_branch_filter, CurrentUser

router = APIRouter(prefix="/sales-targets", tags=["Sales Targets"])


@router.get("", response_model=List[SalesTargetResponse])
def list_sales_targets(
    period: Optional[str] = Query(None, description="Filter by period (YYYY-MM)"),
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_admin_or_supervisor),
):
    """List all sales targets. Admin/Supervisor only. Branch-scoped for ADMIN/SUPERVISOR."""
    # First get sales users in the same branch
    from app.models.models import User
    sales_users_q = db.query(User.id).filter(
        User.role == "SALES",
        User.deleted_at.is_(None),
    )
    sales_users_q = apply_branch_filter(sales_users_q, User, current_user)
    sales_user_ids = [row[0] for row in sales_users_q.all()]

    query = db.query(SalesTarget)
    if sales_user_ids:
        query = query.filter(SalesTarget.user_id.in_(sales_user_ids))
    if period:
        query = query.filter(SalesTarget.period == period)
    return query.order_by(SalesTarget.period.desc(), SalesTarget.user_id).all()


@router.put("/{user_id}", response_model=SalesTargetResponse)
def upsert_sales_target(
    user_id: UUID,
    payload: SalesTargetUpdate,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_admin_or_supervisor),
):
    """Set or update target + incentive for a sales user.
    Creates new record if none exists for (user_id, period), otherwise updates.
    Admin/Supervisor only. Branch-scoped: ADMIN/SUPERVISOR can only set targets for sales in their branch."""
    # Validate user exists and is SALES role
    user = db.query(User).filter(User.id == user_id, User.deleted_at.is_(None)).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if user.role != "SALES":
        raise HTTPException(status_code=400, detail="Target hanya bisa diset untuk role SALES")

    # Branch access check for ADMIN/SUPERVISOR
    if current_user.get("role") in ("ADMIN", "SUPERVISOR") and current_user.get("branch") is not None:
        if user.branch != current_user["branch"]:
            raise HTTPException(status_code=403, detail="Tidak bisa mengatur target untuk sales di branch lain")

    # Upsert
    target = (
        db.query(SalesTarget)
        .filter(SalesTarget.user_id == user_id, SalesTarget.period == payload.period)
        .first()
    )
    if target:
        target.target_type = payload.target_type
        target.target_value = payload.target_value
        target.incentive_amount = payload.incentive_amount
        target.updated_at = datetime.now(timezone.utc)
    else:
        target = SalesTarget(
            user_id=user_id,
            period=payload.period,
            target_type=payload.target_type,
            target_value=payload.target_value,
            incentive_amount=payload.incentive_amount,
        )
        db.add(target)

    db.commit()
    db.refresh(target)
    return target


@router.get("/my", response_model=SalesTargetResponse | None)
def get_my_target(
    period: Optional[str] = Query(None, description="Periode (YYYY-MM). Default: bulan ini."),
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_auth),
):
    """Get target untuk user yang sedang login.
    Semua role (SALES/MANAGER/ADMIN) boleh.
    Return null jika belum ada target diset untuk periode tersebut."""
    from datetime import datetime, timedelta, timezone

    wita = timezone(timedelta(hours=8))
    now_wita = datetime.now(wita)
    if period is None:
        period = f"{now_wita.year}-{now_wita.month:02d}"

    target = (
        db.query(SalesTarget)
        .filter(SalesTarget.user_id == current_user["user_id"], SalesTarget.period == period)
        .first()
    )
    return target
