"""Shared customer-visibility helpers for sales (branch-scoped + kode_area sub-filter).

The 3-tier rule (direct assignment → area coverage → unassigned fallback)
must be identical everywhere so a sales user never sees a customer in a list
but gets 403 when trying to order it.
"""
from uuid import UUID
from fastapi import HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import and_, select, or_

from app.models.models import Customer, CustomerAssignment, AreaAssignment, CustomerKodeArea
from app.core.security import apply_branch_filter


def visible_customer_query(db: Session, current_user: dict):
    """Return a filtered Customer query for the given user.

    - ADMIN/SUPERVISOR/MANAGER (global): all customers in user's branch (or all
      branches for MANAGER), filtered by branch via apply_branch_filter.
    - SALES: customers matching the 3-tier visibility rule, further scoped to
      the user's branch.

    NOTE: callers that need branch filtering on top should wrap:
        apply_branch_filter(visible_customer_query(db, current_user), Customer, current_user)
    """
    from app.models.models import Customer as CustomerModel
    me_id = UUID(current_user["user_id"])

    if current_user["role"] in ("ADMIN", "SUPERVISOR", "MANAGER"):
        # Branch filter applied separately via apply_branch_filter at caller.
        query = db.query(CustomerModel).filter(CustomerModel.deleted_at.is_(None))
        return query

    # SALES: 3-tier rule
    # Subquery 1: customer IDs with direct assignment to me
    mine_subq = (
        select(CustomerAssignment.customer_id)
        .where(CustomerAssignment.sales_id == me_id)
        .subquery()
    )
    # Subquery 2: kode_area values I cover
    my_areas_subq = (
        select(AreaAssignment.kode_area)
        .where(AreaAssignment.sales_id == me_id)
        .subquery()
    )
    # Subquery 3: all customer IDs that have ANY direct assignment
    all_direct = (
        select(CustomerAssignment.customer_id).subquery()
    )
    # Subquery 4: all kode_area values that have ANY assignment
    all_areas = (
        select(AreaAssignment.kode_area).subquery()
    )

    # kode_area di customer.kode_area adalah deprecated column (kosong untuk data baru).
    # Cek kode_area via junction table customer_kode_areas.
    all_cka_subq = (
        select(CustomerKodeArea.customer_id).subquery()
    )
    cka_in_my_areas_subq = (
        select(CustomerKodeArea.customer_id)
        .where(CustomerKodeArea.kode_area.in_(select(my_areas_subq.c.kode_area)))
        .subquery()
    )
    cka_with_any_area = (
        select(CustomerKodeArea.customer_id)
        .where(CustomerKodeArea.kode_area.in_(select(all_areas.c.kode_area)))
        .subquery()
    )

    query = (
        db.query(CustomerModel)
        .filter(CustomerModel.deleted_at.is_(None))
        .filter(
            or_(
                # Tier 1: direct assignment to me
                CustomerModel.id.in_(select(mine_subq.c.customer_id)),
                # Tier 2: customer is in a kode_area I cover (via junction table)
                CustomerModel.id.in_(select(cka_in_my_areas_subq.c.customer_id)),
                # Tier 3: unassigned — no direct assignment AND no area assignment
                # (backward-compat for legacy customers)
                and_(
                    ~CustomerModel.id.in_(select(all_direct.c.customer_id)),
                    or_(
                        # customer tidak ada di junction table
                        ~CustomerModel.id.in_(select(all_cka_subq.c.customer_id)),
                        # atau customer ada di junction table tapi kode_area-nya
                        # tidak di-assign ke siapa pun
                        ~CustomerModel.id.in_(select(cka_with_any_area.c.customer_id)),
                    ),
                ),
            )
        )
    )
    return query


def validate_order_customer_for_sales(db: Session, current_user: dict, customer_id: UUID) -> Customer:
    """Validate that `customer_id` is orderable by `current_user` (SALES role).

    Logic must match visible_customer_query — never return a customer in
    a list but 403 on order.

    Raises HTTPException 403 if customer is not accessible.
    Returns the Customer row if accessible.
    """
    customer = db.query(Customer).filter(
        Customer.id == customer_id,
        Customer.deleted_at.is_(None),
    ).first()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer tidak ditemukan")

    # Branch filter — sales must only order within their own branch.
    # Global MANAGER bypasses this check (already filtered at endpoint level).
    user_branch = current_user.get("branch")
    if current_user["role"] != "MANAGER" and user_branch is not None:
        if customer.branch != user_branch:
            raise HTTPException(
                status_code=403,
                detail="Customer tidak ditemukan",
            )

    me_id = UUID(current_user["user_id"])

    # 1. Direct assignment check
    has_direct = (
        db.query(CustomerAssignment)
        .filter(CustomerAssignment.customer_id == customer.id)
        .first()
    ) is not None
    if has_direct:
        mine = (
            db.query(CustomerAssignment)
            .filter(
                CustomerAssignment.customer_id == customer.id,
                CustomerAssignment.sales_id == me_id,
            )
            .first()
        ) is not None
        if mine:
            return customer
        raise HTTPException(
            status_code=403,
            detail="Customer tidak di-assign ke sales ini",
        )

    # 2. No direct → check area coverage via junction table
    # (customer.kode_area is deprecated; all new data is in customer_kode_areas)
    cka_rows = (
        db.query(CustomerKodeArea)
        .filter(CustomerKodeArea.customer_id == customer.id)
        .all()
    )
    if cka_rows:
        # Customer punya satu atau lebih kode_area
        kode_areas = [cka.kode_area for cka in cka_rows]
        # Cek apakah salah satu kode_area di-assign ke siapa pun
        any_assigned = (
            db.query(AreaAssignment)
            .filter(AreaAssignment.kode_area.in_(kode_areas))
            .first()
        ) is not None
        if not any_assigned:
            return customer  # area unassigned → visible to all
        # Cek apakah sales ini cover salah satu kode_area customer
        mine_area = (
            db.query(AreaAssignment)
            .filter(
                AreaAssignment.kode_area.in_(kode_areas),
                AreaAssignment.sales_id == me_id,
            )
            .first()
        ) is not None
        if mine_area:
            return customer
        raise HTTPException(
            status_code=403,
            detail="Customer tidak di-assign ke sales ini",
        )

    # 3. No direct + no kode_area (legacy data, junction table empty) → visible to all
    return customer
