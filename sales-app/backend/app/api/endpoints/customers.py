"""Customer API endpoints — CRUD, assignment, Excel import."""
from datetime import datetime, timezone
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy.orm import Session
from sqlalchemy import func
from uuid import UUID

from app.models.database import get_db
from app.models.models import Customer, CustomerSales, User, ImportLog
from app.schemas.schemas import (
    CustomerCreate,
    CustomerUpdate,
    CustomerResponse,
    CustomerAssignmentRequest,
    SalesAssignmentResponse,
    SalesUserResponse,
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
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_auth),
):
    sales_id = UUID(current_user["user_id"])
    query = (
        db.query(Customer)
        .join(CustomerSales, CustomerSales.customer_id == Customer.id)
        .filter(CustomerSales.sales_id == sales_id)
        .filter(Customer.deleted_at.is_(None))
    )
    if search:
        query = query.filter(Customer.nama_toko.ilike(f"%{search}%"))
    return query.order_by(Customer.nama_toko).all()


@router.post("", response_model=CustomerResponse, status_code=201)
def create_customer(
    customer: CustomerCreate,
    db: Session = Depends(get_db),
    _current_user: CurrentUser = Depends(require_manager),
):
    existing = _exclude_deleted(
        db.query(Customer).filter(Customer.nama_toko == customer.nama_toko.strip())
    ).first()
    if existing:
        raise HTTPException(status_code=409, detail=f"Customer '{customer.nama_toko}' sudah ada")

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


def _list_assignments(customer_id: UUID, db: Session):
    rows = (
        db.query(CustomerSales, User)
        .join(User, User.id == CustomerSales.sales_id)
        .filter(CustomerSales.customer_id == customer_id)
        .all()
    )
    return [
        SalesAssignmentResponse(
            sales_id=cs.sales_id,
            sales_username=user.username if user else None,
            sales_nama=user.nama if user else None,
            assigned_at=cs.assigned_at,
        )
        for cs, user in rows
    ]


@router.post("/{customer_id}/assign", response_model=List[SalesAssignmentResponse])
def assign_sales(
    customer_id: UUID,
    request: CustomerAssignmentRequest,
    db: Session = Depends(get_db),
    _current_user: CurrentUser = Depends(require_manager),
):
    customer = _exclude_deleted(
        db.query(Customer).filter(Customer.id == customer_id)
    ).first()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer tidak ditemukan")

    sales_users = db.query(User).filter(
        User.id.in_(request.sales_ids),
        User.role == "SALES",
    ).all()
    found_ids = {str(s.id) for s in sales_users}
    invalid = [str(sid) for sid in request.sales_ids if str(sid) not in found_ids]
    if invalid:
        raise HTTPException(status_code=400, detail=f"Sales ID tidak valid: {invalid}")

    db.query(CustomerSales).filter(CustomerSales.customer_id == customer_id).delete()
    for sales_id in request.sales_ids:
        db.add(CustomerSales(customer_id=customer_id, sales_id=sales_id))
    db.commit()

    return _list_assignments(customer_id, db)


@router.get("/{customer_id}/assignments", response_model=List[SalesAssignmentResponse])
def list_assignments(
    customer_id: UUID,
    db: Session = Depends(get_db),
    _current_user: CurrentUser = Depends(require_manager),
):
    return _list_assignments(customer_id, db)


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

    sync_result = sync_customers_from_excel(contents, db)

    # Catat ke histori import
    db.add(ImportLog(
        user_id=_current_user["user_id"],
        nama=_current_user.get("nama"),
        import_type="CUSTOMER",
        total_rows=sync_result["total_rows"],
        inserted=sync_result["inserted"],
        updated=sync_result["updated"],
        skipped=sync_result["skipped"],
        file_name=file.filename,
    ))
    db.commit()

    return SyncResultResponse(
        success=sync_result["success"],
        total_rows=sync_result["total_rows"],
        inserted=sync_result["inserted"],
        updated=sync_result["updated"],
        skipped=sync_result["skipped"],
        errors=sync_result["errors"],
        needs_review=sync_result.get("needs_review", False),
    )
