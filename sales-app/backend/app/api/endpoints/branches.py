"""Branches CRUD endpoint — for global MANAGER to manage the 5-branch list.

Branches are GLOBAL entities (not branch-scoped), so write operations require
MANAGER global. Read operations are open to any authenticated user — this lets
clients fetch the branch list at startup and refresh it after admin mutations.

After every mutation (POST/PUT/PATCH), the in-memory cache in
app/core/branch.py is reloaded so subsequent endpoint responses in this
process pick up the new label/code immediately.
"""
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.models.database import get_db
from app.models.models import Branch, Customer, Product, User
from app.schemas.schemas import (
    BranchCreate,
    BranchUpdate,
    BranchResponse,
    BranchStatsResponse,
)
from app.core.security import require_auth, require_manager_global, CurrentUser
from app.core import branch as branch_constants

router = APIRouter(prefix="/branches", tags=["Branches"])


def _reload_cache():
    """Reload in-memory cache after mutation. Failure is non-fatal — cache will
    be stale until next reload. Logged but not raised."""
    try:
        branch_constants.load_branches_cache()
    except Exception:
        # Cache reload happens lazily at startup normally; missing reload here
        # just means this process uses stale labels until next deploy.
        pass


@router.get("", response_model=list[BranchResponse])
def list_branches(
    include_inactive: bool = Query(
        False,
        description="Jika true, sertakan branch yang is_active=false",
    ),
    db: Session = Depends(get_db),
    _current_user: CurrentUser = Depends(require_auth),
):
    """List branches. Semua role boleh akses (data bukan sensitif).

    Default hanya return active branches — ini yang dipakai client saat startup
    untuk populate dropdown. MANAGER pakai `?include_inactive=true` untuk lihat
    inactive branches di admin UI.
    """
    query = db.query(Branch).order_by(Branch.code)
    if not include_inactive:
        query = query.filter(Branch.is_active.is_(True))
    return query.all()


@router.get("/{code}", response_model=BranchResponse)
def get_branch(
    code: str,
    db: Session = Depends(get_db),
    _current_user: CurrentUser = Depends(require_auth),
):
    branch = db.query(Branch).filter(Branch.code == code).first()
    if not branch:
        raise HTTPException(status_code=404, detail="Cabang tidak ditemukan")
    return branch


@router.post("", response_model=BranchResponse, status_code=201)
def create_branch(
    payload: BranchCreate,
    db: Session = Depends(get_db),
    _current_user: CurrentUser = Depends(require_manager_global),
):
    """Buat branch baru — global MANAGER only.

    Branch code di-uppercase dan divalidasi pattern di schema layer
    (letters/digits/underscore). 409 kalau code sudah ada.
    """
    existing = db.query(Branch).filter(Branch.code == payload.code).first()
    if existing:
        raise HTTPException(
            status_code=409,
            detail=f"Kode cabang '{payload.code}' sudah ada",
        )

    branch = Branch(
        code=payload.code,
        nama=payload.nama,
        is_active=True,
    )
    db.add(branch)
    db.commit()
    db.refresh(branch)
    _reload_cache()
    return branch


@router.put("/{code}", response_model=BranchResponse)
def update_branch(
    code: str,
    payload: BranchUpdate,
    db: Session = Depends(get_db),
    _current_user: CurrentUser = Depends(require_manager_global),
):
    """Update nama / is_active — partial update (field None di-skip).

    Branch code tidak bisa diubah via endpoint ini (kalau perlu ubah code,
    disable yang lama + create yang baru — supaya FK references existing
    data tidak ikut orphan).
    """
    branch = db.query(Branch).filter(Branch.code == code).first()
    if not branch:
        raise HTTPException(status_code=404, detail="Cabang tidak ditemukan")

    data = payload.model_dump(exclude_unset=True)
    for field, value in data.items():
        setattr(branch, field, value)
    branch.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(branch)
    _reload_cache()
    return branch


@router.patch("/{code}/disable", response_model=BranchResponse)
def disable_branch(
    code: str,
    db: Session = Depends(get_db),
    _current_user: CurrentUser = Depends(require_manager_global),
):
    """Soft-disable branch (set is_active=false).

    409 kalau branch masih punya dependency (active users, products, customers).
    Caller harus panggil GET /branches/{code}/stats dulu untuk lihat counts —
    kalau dependency > 0, UI harus tampilkan warning + confirm dulu.

    Note: tidak menghapus data existing. Branch yang sudah punya order/history
    tetap ada di DB dan akan muncul di historical reports.
    """
    branch = db.query(Branch).filter(Branch.code == code).first()
    if not branch:
        raise HTTPException(status_code=404, detail="Cabang tidak ditemukan")

    # Reject kalau ada active dependency — caller harus reassign / hapus dulu.
    active_user_count = (
        db.query(func.count(User.id))
        .filter(
            User.branch == code,
            User.is_active.is_(True),
            User.deleted_at.is_(None),
        )
        .scalar() or 0
    )
    product_count = (
        db.query(func.count(Product.id))
        .filter(Product.branch == code)
        .scalar() or 0
    )
    customer_count = (
        db.query(func.count(Customer.id))
        .filter(Customer.branch == code, Customer.deleted_at.is_(None))
        .scalar() or 0
    )

    if active_user_count > 0 or product_count > 0 or customer_count > 0:
        raise HTTPException(
            status_code=409,
            detail=(
                f"Cabang '{code}' masih punya {active_user_count} user aktif, "
                f"{product_count} produk, {customer_count} customer. "
                f"Reassign atau hapus dulu sebelum nonaktifkan."
            ),
        )

    branch.is_active = False
    branch.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(branch)
    _reload_cache()
    return branch


@router.patch("/{code}/enable", response_model=BranchResponse)
def enable_branch(
    code: str,
    db: Session = Depends(get_db),
    _current_user: CurrentUser = Depends(require_manager_global),
):
    """Reactivate a disabled branch."""
    branch = db.query(Branch).filter(Branch.code == code).first()
    if not branch:
        raise HTTPException(status_code=404, detail="Cabang tidak ditemukan")

    branch.is_active = True
    branch.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(branch)
    _reload_cache()
    return branch


@router.get("/{code}/stats", response_model=BranchStatsResponse)
def get_branch_stats(
    code: str,
    db: Session = Depends(get_db),
    _current_user: CurrentUser = Depends(require_manager_global),
):
    """Aggregate counts for a branch — dipakai untuk konfirmasi sebelum disable."""
    branch = db.query(Branch).filter(Branch.code == code).first()
    if not branch:
        raise HTTPException(status_code=404, detail="Cabang tidak ditemukan")

    user_count = (
        db.query(func.count(User.id))
        .filter(User.branch == code, User.deleted_at.is_(None))
        .scalar() or 0
    )
    active_user_count = (
        db.query(func.count(User.id))
        .filter(
            User.branch == code,
            User.is_active.is_(True),
            User.deleted_at.is_(None),
        )
        .scalar() or 0
    )
    product_count = (
        db.query(func.count(Product.id))
        .filter(Product.branch == code)
        .scalar() or 0
    )
    customer_count = (
        db.query(func.count(Customer.id))
        .filter(Customer.branch == code, Customer.deleted_at.is_(None))
        .scalar() or 0
    )
    sales_count = (
        db.query(func.count(User.id))
        .filter(
            User.branch == code,
            User.role == "SALES",
            User.is_active.is_(True),
            User.deleted_at.is_(None),
        )
        .scalar() or 0
    )

    return BranchStatsResponse(
        code=branch.code,
        nama=branch.nama,
        is_active=branch.is_active,
        user_count=user_count,
        active_user_count=active_user_count,
        product_count=product_count,
        customer_count=customer_count,
        sales_count=sales_count,
    )