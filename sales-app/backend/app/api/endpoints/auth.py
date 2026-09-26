from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from uuid import UUID
from datetime import datetime, timezone

from app.models.database import get_db
from app.models.models import User
from app.schemas.schemas import UserCreate, UserLogin, Token, RefreshTokenRequest, ChangePasswordRequest
from app.core.security import (
    get_password_hash,
    verify_password,
    create_access_token,
    create_refresh_token,
    decode_token,
    require_auth,
)

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/register", status_code=status.HTTP_201_CREATED)
def register(user: UserCreate, db: Session = Depends(get_db)):
    existing = db.query(User).filter(User.username == user.username).first()
    if existing:
        raise HTTPException(status_code=400, detail="Username sudah terdaftar")

    if user.role.upper() not in ("ADMIN", "MANAGER", "SALES"):
        raise HTTPException(status_code=400, detail="Role harus ADMIN, MANAGER, atau SALES")

    new_user = User(
        username=user.username,
        password_hash=get_password_hash(user.password),
        role=user.role.upper(),
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    return {
        "message": "User berhasil didaftarkan",
        "username": new_user.username,
        "role": new_user.role,
    }


@router.post("/login", response_model=Token)
def login(user: UserLogin, db: Session = Depends(get_db)):
    db_user = db.query(User).filter(User.username == user.username).first()

    if not db_user or not verify_password(user.password, db_user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Username atau kata sandi salah",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if not db_user.is_active or db_user.deleted_at is not None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Akun nonaktif. Hubungi manager.",
        )

    access_token = create_access_token(
        data={
            "sub": str(db_user.id),
            "username": db_user.username,
            "role": db_user.role,
            "token_version": db_user.token_version or 0,
        }
    )

    refresh_token = create_refresh_token(
        data={
            "sub": str(db_user.id),
            "username": db_user.username,
            "role": db_user.role,
            "token_version": db_user.token_version or 0,
        }
    )

    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "username": db_user.username,
        "nama": db_user.nama,
        "role": db_user.role,
        "is_active": db_user.is_active,
    }


@router.post("/refresh", response_model=Token)
def refresh_token(body: RefreshTokenRequest, db: Session = Depends(get_db)):
    payload = decode_token(body.refresh_token)
    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token tidak valid atau sudah kedaluwarsa",
            headers={"WWW-Authenticate": "Bearer"},
        )

    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token payload tidak valid",
        )

    db_user = db.query(User).filter(User.id == UUID(user_id)).first()
    if not db_user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User tidak ditemukan",
        )

    access_token = create_access_token(
        data={
            "sub": str(db_user.id),
            "username": db_user.username,
            "role": db_user.role,
            "token_version": db_user.token_version or 0,
        }
    )

    return {"access_token": access_token, "token_type": "bearer"}


@router.post("/change-password")
def change_password(
    body: ChangePasswordRequest,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_auth),
):
    """Ganti password user yang sedang login.

    Verify password lama, set password baru, increment token_version sehingga
    SEMUA sesi lama (termasuk device ini) ter-invalidate. User harus login
    ulang dengan password baru.
    """
    user = db.query(User).filter(User.id == UUID(current_user["user_id"])).first()
    if not user or user.deleted_at is not None or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Akun nonaktif atau tidak ditemukan",
        )

    if not verify_password(body.old_password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Password lama salah",
        )

    user.password_hash = get_password_hash(body.new_password)
    user.token_version = (user.token_version or 0) + 1
    user.updated_at = datetime.now(timezone.utc)
    db.commit()

    return {"detail": "Password berhasil diubah. Silakan login ulang."}
