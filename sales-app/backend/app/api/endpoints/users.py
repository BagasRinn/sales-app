"""User listing & management endpoints — untuk manager/admin operations."""
from datetime import datetime, timezone
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from uuid import UUID

from app.models.database import get_db
from app.models.models import User
from app.schemas.schemas import (
    UserCreate,
    UserUpdate,
    UserResponse,
    SalesUserResponse,
)
from app.core.security import (
    require_admin,
    require_manager,
    require_auth,
    get_password_hash,
    apply_branch_filter,
    CurrentUser,
)
from app.core import branch as branch_constants

router = APIRouter(prefix="/users", tags=["Users"])


def _exclude_deleted(query):
    return query.filter(User.deleted_at.is_(None))


@router.get("/sales", response_model=List[SalesUserResponse])
def list_sales_users(
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_auth),
):
    """List SALES user. Semua role login boleh. Branch-scoped for non-MANAGER."""
    query = _exclude_deleted(db.query(User)).filter(
        User.role == "SALES", User.is_active.is_(True)
    )
    query = apply_branch_filter(query, User, current_user)
    return query.order_by(User.username).all()


@router.get("", response_model=List[UserResponse])
def list_users(
    role: Optional[str] = None,
    search: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_manager),
):
    """List semua user (kecuali soft-deleted) — manager + admin only.
    Branch-scoped for ADMIN/SUPERVISOR; global MANAGER sees all."""
    query = _exclude_deleted(db.query(User))
    # Branch filter applied first
    query = apply_branch_filter(query, User, current_user)
    if role:
        query = query.filter(User.role == role.upper())
    if search:
        like = f"%{search}%"
        query = query.filter(
            (User.username.ilike(like)) | (User.nama.ilike(like))
        )
    return query.order_by(User.role, User.username).all()


@router.post("", response_model=UserResponse, status_code=201)
def create_user(
    user: UserCreate,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_manager),
):
    """Buat user baru — manager + admin only.

    Strict rule: ADMIN/SUPERVISOR cannot create users in another branch.
    If they attempt to do so → 400.
    Only global MANAGER can pick any branch.
    """
    creator_role = current_user.get("role")
    creator_branch = current_user.get("branch")
    target_branch = user.branch

    if creator_role in ("ADMIN", "SUPERVISOR"):
        # Branch-scoped creator: must create user in their own branch
        effective_branch = creator_branch
        if target_branch is not None and target_branch != creator_branch:
            raise HTTPException(
                status_code=400,
                detail="Admin tidak dapat membuat user di branch lain",
            )
    elif creator_role == "MANAGER":
        # Global manager: can create anywhere
        effective_branch = target_branch
        # Validate target branch
        if effective_branch and not branch_constants.is_valid_branch(effective_branch):
            raise HTTPException(
                status_code=400,
                detail=f"Branch tidak valid: {effective_branch}",
            )
        # MANAGER creating MANAGER → branch must be None (global)
        if user.role.upper() == "MANAGER" and effective_branch is not None:
            raise HTTPException(
                status_code=400,
                detail="Manager global harus tanpa branch",
            )
    else:
        raise HTTPException(status_code=403, detail="Akses ditolak")

    if user.role.upper() not in ("ADMIN", "SUPERVISOR", "MANAGER", "SALES"):
        raise HTTPException(status_code=400, detail="Role tidak valid")

    existing = (
        _exclude_deleted(db.query(User))
        .filter(User.username == user.username)
        .first()
    )
    if existing:
        raise HTTPException(status_code=409, detail="Username sudah digunakan")

    new_user = User(
        username=user.username,
        password_hash=get_password_hash(user.password),
        role=user.role.upper(),
        branch=effective_branch,
        nama=user.nama,
        is_active=True,
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    return new_user


@router.put("/{user_id}", response_model=UserResponse)
def update_user(
    user_id: UUID,
    update: UserUpdate,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_manager),
):
    """Edit user — manager + admin only. Branch-scoped: ADMIN/SUPERVISOR
    can only edit users in their own branch. Global MANAGER can edit anyone."""
    target_user = _exclude_deleted(db.query(User).filter(User.id == user_id)).first()
    if not target_user:
        raise HTTPException(status_code=404, detail="User tidak ditemukan")

    # Branch-scoped creator: can only edit users in their own branch
    creator_role = current_user.get("role")
    creator_branch = current_user.get("branch")
    if creator_role in ("ADMIN", "SUPERVISOR"):
        if target_user.branch != creator_branch:
            raise HTTPException(status_code=403, detail="Tidak bisa mengedit user di branch lain")

    data = update.model_dump(exclude_unset=True)

    if "role" in data:
        new_role = data["role"].upper()
        if new_role not in ("ADMIN", "SUPERVISOR", "MANAGER", "SALES"):
            raise HTTPException(status_code=400, detail="Role tidak valid")
        # Cegah admin terakhir di-nonaktifkan (safety)
        if target_user.role == "ADMIN" and new_role != "ADMIN":
            other_admins = (
                _exclude_deleted(db.query(User))
                .filter(User.role == "ADMIN", User.id != user_id, User.is_active.is_(True))
                .count()
            )
            if other_admins == 0:
                raise HTTPException(
                    status_code=400,
                    detail="Tidak bisa downgrade admin terakhir yang aktif",
                )
        data["role"] = new_role

    # Handle branch update: global MANAGER can change branch; others cannot
    if "branch" in data:
        if creator_role != "MANAGER":
            raise HTTPException(status_code=403, detail="Hanya manager global yang dapat mengubah branch")
        new_branch = data["branch"]
        if new_branch and not branch_constants.is_valid_branch(new_branch):
            raise HTTPException(status_code=400, detail=f"Branch tidak valid: {new_branch}")
        # MANAGER role must always have branch=None
        role_to_set = data.get("role", target_user.role)
        if role_to_set == "MANAGER" and new_branch is not None:
            raise HTTPException(status_code=400, detail="Manager global harus tanpa branch")

    # Tangkap sebelum pop — deteksi request yang punya field password.
    had_password_change = "password" in data
    if "password" in data and data["password"]:
        data["password_hash"] = get_password_hash(data.pop("password"))

    # Increment token_version setiap kali password diubah — invalidate semua
    # sesi user target, baik dari self-service maupun reset oleh manager.
    if had_password_change:
        target_user.token_version = (target_user.token_version or 0) + 1

    for field, value in data.items():
        setattr(target_user, field, value)

    target_user.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(target_user)
    return target_user


@router.delete("/{user_id}", status_code=204)
def delete_user(
    user_id: UUID,
    db: Session = Depends(get_db),
    _current_user: CurrentUser = Depends(require_manager),
):
    """Soft-delete user — DIHAPUS.

    Fitur nonaktifkan user (toggle is_active di dialog edit) sudah cukup untuk
    memblokir akses login. Tidak ada dua fitur dengan tujuan yang sama.

    Endpoint ini di-comment bukan di-delete supaya kalau ada rollback / audit,
    kode aslinya masih kelihatan. Untuk restore: uncomment blok di bawah.
    """
    raise HTTPException(
        status_code=410,
        detail="Endpoint dihapus. Gunakan toggle is_active untuk blokir akses user.",
    )


# --- KODE ASLI (di-comment, tidak lagi dipakai) ---
# def delete_user(
#     user_id: UUID,
#     db: Session = Depends(get_db),
#     _current_user: CurrentUser = Depends(require_manager),
# ):
#     """Soft-delete user — manager + admin only."""
#     user = _exclude_deleted(db.query(User).filter(User.id == user_id)).first()
#     if not user:
#         raise HTTPException(status_code=404, detail="User tidak ditemukan")
#
#     # Jangan hapus diri sendiri
#     if str(user.id) == str(_current_user.get("user_id")):
#         raise HTTPException(status_code=400, detail="Tidak bisa menghapus akun sendiri")
#
#     # Jangan hapus admin terakhir
#     if user.role == "ADMIN":
#         other_admins = (
#             _exclude_deleted(db.query(User))
#             .filter(User.role == "ADMIN", User.id != user_id, User.is_active.is_(True))
#             .count()
#         )
#         if other_admins == 0:
#             raise HTTPException(
#                 status_code=400,
#                 detail="Tidak bisa menghapus admin terakhir",
#             )
#
#     user.deleted_at = datetime.now(timezone.utc)
#     user.is_active = False
#     db.commit()
#     return None
