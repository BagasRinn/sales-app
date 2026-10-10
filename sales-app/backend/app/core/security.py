import os
import bcrypt
import jwt
from datetime import datetime, timedelta
from typing import Optional
from uuid import UUID
from fastapi import Depends, HTTPException, status, Query
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session

from app.models.database import get_db

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
    """Global MANAGER only (branch=NULL)."""
    if current_user.get("role") != "MANAGER":
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
    MANAGER global sees all branches; SUPERVISOR is branch-scoped."""
    role = current_user.get("role")
    if role == "MANAGER":
        return current_user
    if role == "SUPERVISOR":
        return current_user
    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Akses ditolak. Hanya supervisor atau manager global yang dapat mengakses endpoint ini.",
    )


def apply_branch_filter(query, model, current_user: dict):
    """Apply branch filter to a query based on the current user.

    - Global MANAGER (branch=NULL): returns query unchanged (sees all branches).
    - Branch-scoped users (ADMIN/SUPERVISOR/SALES): filters to their branch.
    - Fallback during migration (branch=NULL for branch-scoped users before
      backfill completes): returns query unchanged as a temporary bridge.
      This fallback is removed after migration stage C completes.
    """
    role = current_user.get("role")
    branch = current_user.get("branch")

    # Global MANAGER: no filter (sees all branches).
    if role == "MANAGER":
        return query

    # Branch-scoped user with branch set: apply filter.
    if branch is not None:
        return query.filter(model.branch == branch)

    # Fallback: branch is NULL but user is not global MANAGER.
    # This happens during migration staging between code deploy and backfill.
    # Return query unchanged to avoid filtering out all rows.
    return query


CurrentUser = dict
