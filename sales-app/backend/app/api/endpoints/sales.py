"""Sales-centric endpoints — list customer assigned to a sales user."""
from typing import List
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.models.database import get_db
from app.models.models import Customer, CustomerAssignment, User
from app.schemas.schemas import CustomerResponse
from app.core.security import require_manager, CurrentUser

router = APIRouter(prefix="/sales", tags=["Sales"])


@router.get("/{sales_id}/customers", response_model=List[CustomerResponse])
def list_sales_customers(
    sales_id: UUID,
    db: Session = Depends(get_db),
    _current_user: CurrentUser = Depends(require_manager),
):
    """Semua customer yang di-assign ke sales ini (exclude soft-deleted).
    Manager + admin only — untuk tab 'Per Sales' di admin web."""
    user = db.query(User).filter(
        User.id == sales_id,
        User.deleted_at.is_(None),
    ).first()
    if not user:
        raise HTTPException(status_code=404, detail="User tidak ditemukan")

    rows = (
        db.query(Customer)
        .join(CustomerAssignment, CustomerAssignment.customer_id == Customer.id)
        .filter(
            CustomerAssignment.sales_id == sales_id,
            Customer.deleted_at.is_(None),
        )
        .order_by(Customer.nama_toko)
        .all()
    )
    return rows
