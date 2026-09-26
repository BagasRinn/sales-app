"""User listing & management endpoints — untuk manager/admin operations."""
from datetime import datetime, timezone
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException
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
    CurrentUser,
)

router = APIRouter(prefix="/users", tags=["Users"])


def _exclude_deleted(query):
    return query.filter(User.deleted_at.is_(None))


@router.get("/sales", response_model=List[SalesUserResponse])
def list_sales_users(
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_auth),
):
    """List SALES user — untuk dropdown assignment toko. Semua role login boleh."""
    users = (
        _exclude_deleted(db.query(User))
        .filter(User.role == "SALES", User.is_active.is_(True))
        .order_by(User.username)
        .all()
    )
    return users


@router.get("", response_model=List[UserResponse])
def list_users(
    role: Optional[str] = None,
    search: Optional[str] = None,
    db: Session = Depends(get_db),
    _current_user: CurrentUser = Depends(require_manager),
):
    """List semua user (kecuali soft-deleted) — manager + admin only."""
    query = _exclude_deleted(db.query(User))
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
    _current_user: CurrentUser = Depends(require_manager),
):
    """Buat user baru — manager + admin only."""
    if user.role.upper() not in ("ADMIN", "MANAGER", "SALES"):
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
    _current_user: CurrentUser = Depends(require_manager),
):
    """Edit user — manager + admin only. Hanya field yang dikirim yang berubah."""
    user = _exclude_deleted(db.query(User).filter(User.id == user_id)).first()
    if not user:
        raise HTTPException(status_code=404, detail="User tidak ditemukan")

    data = update.model_dump(exclude_unset=True)

    if "role" in data:
        new_role = data["role"].upper()
        if new_role not in ("ADMIN", "MANAGER", "SALES"):
            raise HTTPException(status_code=400, detail="Role tidak valid")
        # Cegah admin terakhir di-nonaktifkan (safety)
        if user.role == "ADMIN" and new_role != "ADMIN":
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

    # Tangkap sebelum pop — deteksi request yang punya field password.
    had_password_change = "password" in data
    if "password" in data and data["password"]:
        data["password_hash"] = get_password_hash(data.pop("password"))

    # Increment token_version setiap kali password diubah — invalidate semua
    # sesi user target, baik dari self-service maupun reset oleh manager.
    if had_password_change:
        user.token_version = (user.token_version or 0) + 1

    for field, value in data.items():
        setattr(user, field, value)

    user.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(user)
    return user


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
