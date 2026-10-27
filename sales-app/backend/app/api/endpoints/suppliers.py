from typing import Optional
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Query, HTTPException, status, Response
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.database import get_db
from app.models.models import Supplier, Product
from app.schemas.schemas import (
    SupplierResponse,
    SupplierCreate,
    SupplierActiveUpdate,
    SupplierOrderTypeUpdate,
)
from app.core.security import require_auth, apply_branch_filter, require_manager_global, CurrentUser

router = APIRouter(prefix="/suppliers", tags=["Suppliers"])


@router.get("")
def list_suppliers(
    response: Response,
    active: Optional[bool] = Query(None, description="Filter by is_active"),
    order_type: Optional[str] = Query(None, description="Filter by order_type ('REGULER' / '4P')"),
    search: Optional[str] = Query(None, description="Cari nama supplier"),
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_auth),
):
    """List suppliers. product_count follows apply_branch_filter (branch-scoped
    for ADMIN/SUPERVISOR; global for MANAGER)."""
    # Subquery: product count per supplier_name, scoped via the same
    # apply_branch_filter as the rest of the product API.
    product_count_subq = (
        db.query(
            Product.nama_supplier.label("name"),
            func.count(Product.id).label("product_count"),
        )
        .group_by(Product.nama_supplier)
    )
    product_count_subq = apply_branch_filter(product_count_subq, Product, current_user).subquery()

    query = (
        db.query(
            Supplier,
            func.coalesce(product_count_subq.c.product_count, 0).label("product_count"),
        )
        .outerjoin(product_count_subq, product_count_subq.c.name == Supplier.name)
    )
    if active is not None:
        query = query.filter(Supplier.is_active == active)
    if order_type is not None:
        norm_ot = order_type.strip().upper()
        query = query.filter(Supplier.order_type == norm_ot)
    if search:
        query = query.filter(Supplier.name.ilike(f"%{search.strip()}%"))

    total = query.order_by(None).count()
    response.headers["X-Total-Count"] = str(total)
    rows = query.order_by(Supplier.name).offset(skip).limit(limit).all()
    suppliers = [
        SupplierResponse(
            name=sup.name,
            is_active=sup.is_active,
            order_type=sup.order_type or "REGULER",
            product_count=int(product_count or 0),
            created_at=sup.created_at,
            updated_at=sup.updated_at,
        )
        for sup, product_count in rows
    ]
    return {
        "suppliers": [supplier.model_dump(mode="json") for supplier in suppliers],
        "total": total,
    }


@router.post("", response_model=SupplierResponse, status_code=status.HTTP_201_CREATED)
def create_supplier(
    payload: SupplierCreate,
    db: Session = Depends(get_db),
    _current_user: CurrentUser = Depends(require_manager_global),
):
    """Create a new supplier. MANAGER only. 409 if name already exists."""
    existing = db.query(Supplier).filter(Supplier.name == payload.name).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"Supplier '{payload.name}' sudah ada",
        )
    norm_ot = (payload.order_type or "REGULER").strip().upper()
    if norm_ot not in ("REGULER", "4P"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="order_type must be 'REGULER' or '4P'",
        )
    sup = Supplier(name=payload.name, is_active=True, order_type=norm_ot)
    db.add(sup)
    db.commit()
    db.refresh(sup)
    return SupplierResponse(
        name=sup.name,
        is_active=sup.is_active,
        order_type=sup.order_type,
        product_count=0,
        created_at=sup.created_at,
        updated_at=sup.updated_at,
    )


@router.patch("/{name}/active", response_model=SupplierResponse)
def update_supplier_active(
    name: str,
    payload: SupplierActiveUpdate,
    db: Session = Depends(get_db),
    _current_user: CurrentUser = Depends(require_manager_global),
):
    """Toggle a supplier's is_active. MANAGER only. 404 if not found."""
    sup = db.query(Supplier).filter(Supplier.name == name).first()
    if not sup:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Supplier '{name}' tidak ditemukan",
        )
    sup.is_active = payload.is_active
    sup.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(sup)
    return SupplierResponse(
        name=sup.name,
        is_active=sup.is_active,
        order_type=sup.order_type or "REGULER",
        product_count=0,
        created_at=sup.created_at,
        updated_at=sup.updated_at,
    )


@router.patch("/{name}/order-type", response_model=SupplierResponse)
def update_supplier_order_type(
    name: str,
    payload: SupplierOrderTypeUpdate,
    db: Session = Depends(get_db),
    _current_user: CurrentUser = Depends(require_manager_global),
):
    """Update supplier order_type (REGULER/4P) and cascade to existing products. MANAGER only."""
    norm_ot = (payload.order_type or "").strip().upper()
    if norm_ot not in ("REGULER", "4P"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="order_type must be 'REGULER' or '4P'",
        )
    sup = db.query(Supplier).filter(Supplier.name == name).first()
    if not sup:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Supplier '{name}' tidak ditemukan",
        )
    sup.order_type = norm_ot
    sup.updated_at = datetime.now(timezone.utc)
    # Cascade update to all products belonging to this supplier across all branches
    db.query(Product).filter(Product.nama_supplier == name).update(
        {Product.order_type: norm_ot},
        synchronize_session=False,
    )
    db.commit()
    db.refresh(sup)

    count = db.query(Product).filter(Product.nama_supplier == name).count()
    return SupplierResponse(
        name=sup.name,
        is_active=sup.is_active,
        order_type=sup.order_type,
        product_count=count,
        created_at=sup.created_at,
        updated_at=sup.updated_at,
    )
