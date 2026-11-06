import logging
import os
from datetime import datetime, timedelta
from typing import Optional
from uuid import UUID

import bcrypt
import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy import false
from sqlalchemy.orm import Session

from app.models.database import get_db

logger = logging.getLogger(__name__)

VALID_ROLES = ("ADMIN", "SUPERVISOR", "MANAGER", "SALES")

load_dotenv = None

try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

SECRET_KEY = os.getenv("SECRET_KEY")
if not SECRET_KEY:
    raise RuntimeError(
        "SECRET_KEY env var is required. Refusing to start with an unset/missing signing key."
    )
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30
REFRESH_TOKEN_EXPIRE_DAYS = 7


def verify_password(plain_password: str, hashed_password: str) -> bool:
    safe_password = str(plain_password)[:72]
    password_bytes = safe_password.encode("utf-8")
    hash_bytes = hashed_password.encode("utf-8")
    return bcrypt.checkpw(password_bytes, hash_bytes)


def get_password_hash(password: str) -> str:
    safe_password = str(password)[:72]
    password_bytes = safe_password.encode("utf-8")
    salt = bcrypt.gensalt()
    return bcrypt.hashpw(password_bytes, salt).decode("utf-8")


def create_access_token(data: dict) -> str:
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({
        "exp": expire,
        "type": "access",
        "tv": data.get("token_version", 0),
    })
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


def create_refresh_token(data: dict) -> str:
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    to_encode.update({
        "exp": expire,
        "type": "refresh",
        "tv": data.get("token_version", 0),
    })
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


def decode_token(token: str) -> Optional[dict]:
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload
    except jwt.ExpiredSignatureError:
        return None
    except jwt.PyJWTError:
        return None


oauth2_scheme = OAuth2PasswordBearer(tokenUrl="api/v1/auth/login")


def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
) -> dict:
    """Decode token, lookup user, dan validasi token_version.

    Return dict berisi info user. Raise 401 kalau token invalid, user tidak
    ada, atau token_version tidak match dengan current_user.token_version.
    Reads role + branch FESH from DB row (NOT from JWT payload) to support
    zero-downtime migration: in-flight tokens stay valid after role/branch
    changes because the authoritative source is always the DB.
    """
    payload = decode_token(token)
    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token tidak valid atau sudah kedaluwarsa",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Only access tokens are accepted as bearer credentials. Without this a
    # long-lived refresh token could be replayed as an access token.
    if payload.get("type") != "access":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token bukan access token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    user_id = payload.get("sub")
    token_version = payload.get("tv", 0)
    if user_id is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token payload tidak valid",
        )

    # Lazy import untuk hindari circular dependency
    from app.models.models import User
    user = db.query(User).filter(User.id == UUID(user_id)).first()
    if not user or user.deleted_at is not None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User tidak ditemukan",
        )
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Akun nonaktif",
            headers={"WWW-Authenticate": "Bearer"},
        )
    if (user.token_version or 0) != token_version:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Sesi sudah tidak valid (password telah diubah)",
        )

    return {
        "user_id": user_id,
        "username": payload.get("username"),
        # role + branch from DB row (authoritative), not from JWT payload.
        # This ensures that role/branch changes take effect immediately
        # without requiring the user to re-login.
        "role": user.role,
        "branch": user.branch,
        "nama": user.nama,
    }


def require_auth(current_user: dict = Depends(get_current_user)) -> dict:
    return current_user


def require_admin(current_user: dict = Depends(get_current_user)) -> dict:
    if current_user.get("role") != "ADMIN":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Akses ditolak. Hanya admin yang dapat mengakses endpoint ini.",
        )
    return current_user


def require_manager(current_user: dict = Depends(get_current_user)) -> dict:
    """Izinkan MANAGER (global) + ADMIN (branch-scoped).
    Note: SUPERVISOR is a branch-scoped role, not included here.
    Use require_admin_or_supervisor for branch-scoped management access.
    """
    role = current_user.get("role")
    if role not in ("MANAGER", "ADMIN"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Akses ditolak. Hanya manager atau admin yang dapat mengakses endpoint ini.",
        )
    return current_user


def require_supervisor(current_user: dict = Depends(get_current_user)) -> dict:
    """Branch-scoped SUPERVISOR only."""
    if current_user.get("role") != "SUPERVISOR":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Akses ditolak. Hanya supervisor yang dapat mengakses endpoint ini.",
        )
    return current_user


def require_manager_global(current_user: dict = Depends(get_current_user)) -> dict:
    """Global MANAGER only (branch=NULL).

    A MANAGER row that somehow has a branch set is treated as branch-scoped,
    so it cannot silently gain cross-branch access.
    """
    if not is_global_manager(current_user):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Akses ditolak. Hanya manager global yang dapat mengakses endpoint ini.",
        )
    return current_user


def require_admin_or_supervisor(current_user: dict = Depends(get_current_user)) -> dict:
    """ADMIN (branch-scoped) or SUPERVISOR (branch-scoped)."""
    role = current_user.get("role")
    if role not in ("ADMIN", "SUPERVISOR"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Akses ditolak. Hanya admin atau supervisor yang dapat mengakses endpoint ini.",
        )
    return current_user


def require_supervisor_or_manager_global(current_user: dict = Depends(get_current_user)) -> dict:
    """SUPERVISOR (branch-scoped) or MANAGER (global, branch=NULL).
    ADMIN excluded — admin is read-only.
    MANAGER global sees all branches; SUPERVISOR is branch-scoped.
    A MANAGER row with a branch is treated as branch ADMIN and rejected."""
    if is_global_manager(current_user):
        return current_user
    if effective_scope_role(current_user) == "SUPERVISOR":
        return current_user
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Akses ditolak. Hanya supervisor atau manager global yang dapat mengakses endpoint ini.",
    )


def require_write_access(current_user: dict = Depends(get_current_user)) -> dict:
    """ADMIN (branch-scoped), SUPERVISOR (branch-scoped), or MANAGER (global).
    Allows all write-capable roles. SALES excluded."""
    role = effective_scope_role(current_user)
    if role in ("ADMIN", "SUPERVISOR", "MANAGER"):
        return current_user
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Akses ditolak. Hanya admin, supervisor, atau manager yang dapat mengakses endpoint ini.",
    )


# ---------------------------------------------------------------------------
# Role / branch helpers (fail-closed)
# ---------------------------------------------------------------------------

def is_global_manager(current_user: dict) -> bool:
    """True only for MANAGER with branch=NULL (the documented global role)."""
    return (
        current_user.get("role") == "MANAGER"
        and current_user.get("branch") is None
    )


def effective_scope_role(current_user: dict) -> str:
    """Role used for authorization decisions.

    A MANAGER row with a branch set is malformed; treat it as a branch ADMIN
    instead of granting global scope.
    """
    role = (current_user.get("role") or "").upper()
    if role == "MANAGER" and current_user.get("branch") is not None:
        return "ADMIN"
    return role


def branch_guard(current_user: dict, resource_branch: str | None) -> None:
    """Raise 403 unless the user may access data belonging to `resource_branch`.

    - Global MANAGER (role=MANAGER, branch=NULL) may access every branch.
    - Everyone else must have a branch and it must match the resource.
    - Fail-closed: a non-manager with branch=NULL gets no access.
    """
    if is_global_manager(current_user):
        return
    user_branch = current_user.get("branch")
    if user_branch is None or resource_branch != user_branch:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Tidak memiliki akses ke data cabang lain",
        )


def assert_can_manage_role(creator: dict, target_role: str) -> str:
    """Enforce a role ceiling for user management.

    Only a global MANAGER and a branch SUPERVISOR may create/manage users.
    ADMIN has no user-management access at all. A SUPERVISOR is limited to
    SALES accounts inside their own branch (see ``resolve_new_user_branch``).

    MANAGER    -> any role (global manager only)
    SUPERVISOR -> SALES only
    """
    role = (target_role or "").upper()
    if role not in VALID_ROLES:
        raise HTTPException(status_code=400, detail="Role tidak valid")

    creator_scope = effective_scope_role(creator)
    allowed = {
        "MANAGER": set(VALID_ROLES),
        "SUPERVISOR": {"SALES"},
    }.get(creator_scope, set())

    if role not in allowed:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                f"Role {creator_scope or 'UNKNOWN'} tidak boleh membuat/mengubah "
                f"user dengan role {role}"
            ),
        )
    return role


def resolve_new_user_branch(
    creator: dict, target_role: str, requested_branch: str | None
) -> str | None:
    """Validate role ceiling + branch for a new user, return the branch to store.

    - Global MANAGER may create any role. MANAGER targets are always global
      (``branch=None``); other roles require an explicit valid branch.
    - SUPERVISOR may only create SALES accounts, and they are always pinned to
      the supervisor's own branch. Fail-closed if the supervisor has no branch.
    """
    from app.core import branch as branch_constants

    role = assert_can_manage_role(creator, target_role)
    creator_scope = effective_scope_role(creator)

    if role == "MANAGER":
        if requested_branch:
            raise HTTPException(
                status_code=400,
                detail="Manager global harus tanpa branch",
            )
        return None

    if creator_scope == "SUPERVISOR":
        creator_branch = creator.get("branch")
        if not creator_branch:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Supervisor tanpa branch tidak dapat membuat user",
            )
        if requested_branch and requested_branch != creator_branch:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Supervisor hanya dapat membuat user di cabangnya sendiri",
            )
        return creator_branch

    if not requested_branch:
        raise HTTPException(
            status_code=400,
            detail="Branch wajib untuk ADMIN, SUPERVISOR, atau SALES",
        )
    if not branch_constants.is_valid_branch(requested_branch):
        raise HTTPException(
            status_code=400,
            detail=f"Branch tidak valid: {requested_branch}",
        )
    return requested_branch


def apply_branch_filter(query, model, current_user: dict):
    """Apply branch filter to a query based on the current user.

    - Global MANAGER (branch=NULL): returns query unchanged (sees all branches).
    - Branch-scoped users: filters to their branch.
    - Fail-closed: a non-MANAGER account without a branch sees NOTHING instead
      of every branch. Legacy/misconfigured rows must be fixed, not silently
      granted global scope.
    """
    role = effective_scope_role(current_user)
    branch = current_user.get("branch")

    if role == "MANAGER":
        return query

    if branch is not None:
        return query.filter(model.branch == branch)

    logger.warning(
        "[AUTHZ] Non-manager user without branch (%s/%s) denied all rows — "
        "fix the user's branch assignment.",
        current_user.get("user_id"),
        current_user.get("role"),
    )
    return query.filter(false())


CurrentUser = dict
