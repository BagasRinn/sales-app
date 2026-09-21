from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from uuid import UUID
import uuid

from app.models.database import get_db
from app.models.models import User
from app.schemas.schemas import UserCreate, UserLogin, Token, RefreshTokenRequest
from app.core.security import (
    get_password_hash,
    verify_password,
    create_access_token,
    create_refresh_token,
    decode_token,
)

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/register", status_code=status.HTTP_201_CREATED)
def register(user: UserCreate, db: Session = Depends(get_db)):
    existing = db.query(User).filter(User.username == user.username).first()
    if existing:
        raise HTTPException(status_code=400, detail="Username sudah terdaftar")

    if user.role.upper() not in ("ADMIN", "SALES"):
        raise HTTPException(status_code=400, detail="Role harus ADMIN atau SALES")

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

    access_token = create_access_token(
        data={
            "sub": str(db_user.id),
            "username": db_user.username,
            "role": db_user.role,
        }
    )

    refresh_token = create_refresh_token(
        data={
            "sub": str(db_user.id),
            "username": db_user.username,
            "role": db_user.role,
        }
    )

    return {"access_token": access_token, "refresh_token": refresh_token, "token_type": "bearer"}


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
        }
    )

    return {"access_token": access_token, "token_type": "bearer"}
