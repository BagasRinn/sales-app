"""User listing & management endpoints - untuk manager/admin operations."""
from datetime import datetime, timezone
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Response
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
    require_supervisor_or_manager_global,
    get_password_hash,
    apply_branch_filter,
    assert_can_manage_role,
    effective_scope_role,
    is_global_manager,
    resolve_new_user_branch,
    CurrentUser,
)
from app.core import branch as branch_constants

router = APIRouter(prefix="/users", tags=["Users"])


def _user_to_response(u: User) -> UserResponse:
    """Build UserResponse ORM-style. Adds branch_nama via cache (single lookup)."""
    return UserResponse(
        id=u.id,
        username=u.username,
        nama=u.nama,
        role=u.role,
        branch=u.branch,
        branch_nama=branch_constants.get_branch_nama(u.branch),
        is_active=u.is_active,
        created_at=u.created_at,
    )


def _exclude_deleted(query):
    return query.filter(User.deleted_at.is_(None))


@router.get("/sales", response_model=List[SalesUserResponse])
def list_sales_users(
    limit: int = Query(100, ge=1, le=1000, description="Maksimal jumlah sales user; default 100"),
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_supervisor_or_manager_global),
):
    """List SALES user - supervisor + manager only. Branch-scoped for supervisor."""
    query = _exclude_deleted(db.query(User)).filter(
        User.role == "SALES", User.is_active.is_(True)
    )
    query = apply_branch_filter(query, User, current_user)
    return query.order_by(User.username).limit(limit).all()


@router.get("", response_model=List[UserResponse])
def list_users(
    response: Response,
    role: Optional[str] = None,
    search: Optional[str] = None,
    limit: Optional[int] = Query(None, ge=1, le=1000, description="Opsional; default = semua"),
    offset: int = Query(0, ge=0),
    include_total: bool = Query(False, description="True = kirim header X-Total-Count"),
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_supervisor_or_manager_global),
):
    """List semua user (kecuali soft-deleted) - supervisor + manager only.
    ADMIN tidak punya akses. Supervisor hanya melihat cabangnya sendiri;
    global MANAGER melihat semua."""
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
    query = query.order_by(User.role, User.username)
    if include_total:
        response.headers["X-Total-Count"] = str(query.order_by(None).count())
    if limit is not None or offset:
        query = query.limit(limit).offset(offset)
    return [_user_to_response(u) for u in query.all()]


@router.post("", response_model=UserResponse, status_code=201)
def create_user(
    user: UserCreate,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_supervisor_or_manager_global),
):
    """Buat user baru - manager global atau supervisor cabang.

    ADMIN tidak boleh membuat user. Manager global boleh membuat role apa pun;
    user non-MANAGER wajib punya branch, sedangkan MANAGER selalu global
    (branch=None). Supervisor hanya boleh membuat SALES di cabangnya sendiri.
    """
    # Enforces role ceiling + branch rules (fail-closed) for this caller.
    effective_branch = resolve_new_user_branch(
        current_user, user.role, user.branch
    )

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
    return _user_to_response(new_user)


@router.put("/{user_id}", response_model=UserResponse)
def update_user(
    user_id: UUID,
    update: UserUpdate,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_supervisor_or_manager_global),
):
    """Edit user - supervisor + manager only.

    Supervisor hanya boleh mengelola akun SALES di cabangnya sendiri.
    Global MANAGER boleh mengelola siapa pun. ADMIN tidak punya akses.
    """
    target_user = _exclude_deleted(db.query(User).filter(User.id == user_id)).first()
    if not target_user:
        raise HTTPException(status_code=404, detail="User tidak ditemukan")

    data = update.model_dump(exclude_unset=True)

    # --- Caller scope checks (fail-closed) -------------------------------
    creator_scope = effective_scope_role(current_user)
    creator_branch = current_user.get("branch")

    # Supervisor may only manage SALES accounts (never ADMIN/MANAGER).
    if creator_scope == "SUPERVISOR" and target_user.role != "SALES":
        raise HTTPException(
            status_code=403,
            detail="Supervisor hanya dapat mengelola user SALES",
        )

    if not is_global_manager(current_user):
        # Branch-scoped: only users in the same branch, never global managers.
        if target_user.branch != creator_branch:
            raise HTTPException(
                status_code=403,
                detail="Tidak bisa mengedit user di branch lain",
            )
        if target_user.role == "MANAGER":
            raise HTTPException(
                status_code=403,
                detail="Hanya manager global yang dapat mengelola manager",
            )

    # Prevent self role changes (avoids accidental self-lockout/escalation).
    if str(target_user.id) == str(current_user.get("user_id")) and "role" in data:
        if (data["role"] or "").upper() != target_user.role:
            raise HTTPException(
                status_code=400,
                detail="Tidak dapat mengubah role akun sendiri",
            )

    if "role" in data:
        # Enforce the caller's role ceiling (SUPERVISOR -> SALES only,
        # ADMIN -> up to ADMIN, MANAGER -> any).
        new_role = assert_can_manage_role(current_user, data["role"])
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

    # Handle branch update: only a global MANAGER can change branch. A no-op
    # value (client re-sends the user's current branch) is ignored so that
    # supervisor edits are not rejected by an unchanged field.
    if "branch" in data:
        new_branch = data["branch"]
        if new_branch == target_user.branch:
            data.pop("branch")
        else:
            if not is_global_manager(current_user):
                raise HTTPException(
                    status_code=403,
                    detail="Hanya manager global yang dapat mengubah branch",
                )
            if new_branch and not branch_constants.is_valid_branch(new_branch):
                raise HTTPException(status_code=400, detail=f"Branch tidak valid: {new_branch}")
            # MANAGER role must always have branch=None
            role_to_set = data.get("role", target_user.role)
            if role_to_set == "MANAGER" and new_branch is not None:
                raise HTTPException(status_code=400, detail="Manager global harus tanpa branch")

    # Promoting to MANAGER always yields the single global manager shape.
    # Only a global MANAGER can reach here (role ceiling above).
    if data.get("role") == "MANAGER":
        data["branch"] = None

    # Tangkap sebelum pop - deteksi request yang punya field password.
    had_password_change = "password" in data
    if "password" in data and data["password"]:
        data["password_hash"] = get_password_hash(data.pop("password"))

    # Increment token_version setiap kali password diubah - invalidate semua
    # sesi user target, baik dari self-service maupun reset oleh manager.
    if had_password_change:
        target_user.token_version = (target_user.token_version or 0) + 1

    for field, value in data.items():
        setattr(target_user, field, value)

    target_user.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(target_user)
    return _user_to_response(target_user)


@router.delete("/{user_id}", status_code=204)
def delete_user(
    user_id: UUID,
    db: Session = Depends(get_db),
    _current_user: CurrentUser = Depends(require_supervisor_or_manager_global),
):
    """Soft-delete user - DIHAPUS.

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
#     """Soft-delete user - manager + admin only."""
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
