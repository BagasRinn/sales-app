from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Request, Response, status
from sqlalchemy.orm import Session
from uuid import UUID
from datetime import datetime, timezone

from app.models.database import get_db
from app.models.models import User
from app.schemas.schemas import UserCreate, UserLogin, Token, RefreshTokenRequest, ChangePasswordRequest
from app.core.cookies import (
    REFRESH_COOKIE_NAME,
    apply_refresh_cookie,
    clear_session_cookies,
    extract_refresh_token,
    verify_csrf_origin,
)
from app.core.security import (
    get_password_hash,
    verify_password,
    create_access_token,
    create_refresh_token,
    decode_token,
    require_auth,
    require_manager_global,
    resolve_new_user_branch,
    VALID_ROLES,
)
from app.core import branch as branch_constants

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/register", status_code=status.HTTP_201_CREATED)
def register(
    user: UserCreate,
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_manager_global),
):
    """Create a user.

    Only a global MANAGER may create accounts. ADMIN and SUPERVISOR are
    rejected; SUPERVISOR can still manage existing SALES accounts through
    /users.
    """
    existing = db.query(User).filter(User.username == user.username).first()
    if existing:
        raise HTTPException(status_code=400, detail="Username sudah terdaftar")

    if user.role.upper() not in VALID_ROLES:
        raise HTTPException(
            status_code=400,
            detail="Role harus ADMIN, SUPERVISOR, MANAGER, atau SALES",
        )

    # Enforces role ceiling + branch rules for the caller's scope.
    branch = resolve_new_user_branch(current_user, user.role, user.branch)

    new_user = User(
        username=user.username,
        password_hash=get_password_hash(user.password),
        role=user.role.upper(),
        branch=branch,
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
def login(
    user: UserLogin,
    request: Request,
    response: Response,
    db: Session = Depends(get_db),
):
    # Anti login-CSRF: bila request datang dari browser (ada Origin), origin
    # harus diizinkan. Request tanpa Origin (mobile/curl) tetap dilayani.
    verify_csrf_origin(request)

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

    # Admin web hanya untuk peran pengelola. Ditegakkan di server (bukan hanya
    # UI) supaya cookie sesi tidak pernah dibuat untuk akun SALES — kalau
    # dicek di frontend saja, silent refresh berikutnya akan memulihkan sesi
    # yang tadi ditolak.
    is_web_client = (user.client or "").strip().lower() == "web"
    if is_web_client and (db_user.role or "").upper() not in (
        "ADMIN",
        "SUPERVISOR",
        "MANAGER",
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                "Hanya admin, supervisor, dan manager yang boleh "
                "mengakses dashboard ini."
            ),
        )

    access_token = create_access_token(
        data={
            "sub": str(db_user.id),
            "username": db_user.username,
            "role": db_user.role,
            "branch": db_user.branch,
            "token_version": db_user.token_version or 0,
        }
    )

    refresh_token = create_refresh_token(
        data={
            "sub": str(db_user.id),
            "username": db_user.username,
            "role": db_user.role,
            "branch": db_user.branch,
            "token_version": db_user.token_version or 0,
        }
    )

    # Sesi admin web: refresh token dikirim via cookie httpOnly agar tidak
    # bisa dibaca JavaScript (XSS tidak dapat mengeksfiltrasi sesi 7 hari).
    # Hanya client web yang menerima cookie; mobile tetap memakai body dan
    # tidak pernah mendapat ambient credential.
    if is_web_client:
        apply_refresh_cookie(response, refresh_token)

    branch_nama = branch_constants.get_branch_nama(db_user.branch)

    payload = {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "username": db_user.username,
        "nama": db_user.nama,
        "role": db_user.role,
        "branch": db_user.branch,
        "branch_nama": branch_nama,
        "is_active": db_user.is_active,
    }
    if is_web_client:
        # Browser tidak boleh menerima refresh token di body — cookie di atas
        # satu-satunya jalur sesi panjang untuk admin web.
        payload["refresh_token"] = None

    return payload


@router.post("/refresh", response_model=Token)
def refresh(
    request: Request,
    response: Response,
    body: Optional[RefreshTokenRequest] = None,
    db: Session = Depends(get_db),
):
    """Perbarui access token.

    Dual-mode: admin web mengirim refresh token lewat cookie httpOnly
    (rotasi — refresh token baru ditulis ke cookie dan TIDAK dikirim di
    body); mobile mengirimnya di body seperti sebelumnya dan tidak menerima
    refresh baru (perilaku lama dipertahankan).
    """
    raw_token, source = extract_refresh_token(
        request, body.refresh_token if body is not None else None
    )
    if not raw_token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token tidak ditemukan",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if source == "cookie":
        # Cookie membawa ambient credential → wajib origin admin web yang sah.
        verify_csrf_origin(request, require_origin=True)

    payload = decode_token(raw_token)
    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token tidak valid atau sudah kedaluwarsa",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Only actual refresh tokens may be used here; an access token must not be
    # replayable as a long-lived session.
    if payload.get("type") != "refresh":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token bukan refresh token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token payload tidak valid",
        )

    try:
        user_uuid = UUID(user_id)
    except (ValueError, TypeError):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token payload tidak valid",
        )

    db_user = db.query(User).filter(User.id == user_uuid).first()
    if not db_user or db_user.deleted_at is not None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User tidak ditemukan",
        )

    if not db_user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Akun nonaktif. Hubungi manager.",
        )

    # A password change bumps token_version; refresh tokens issued before that
    # must stop working.
    if (db_user.token_version or 0) != payload.get("tv", 0):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Sesi sudah tidak valid (password telah diubah)",
            headers={"WWW-Authenticate": "Bearer"},
        )

    access_token = create_access_token(
        data={
            "sub": str(db_user.id),
            "username": db_user.username,
            "role": db_user.role,
            "branch": db_user.branch,
            "token_version": db_user.token_version or 0,
        }
    )

    branch_nama = branch_constants.get_branch_nama(db_user.branch)

    if source == "cookie":
        # Rotasi + sliding session: refresh token lama diganti JWT baru dan
        # cookie di-renew. User aktif tidak pernah ter-logout; token bocor
        # berumur maksimal satu interval refresh. Token baru hanya lewat
        # cookie — body tetap tanpa refresh token untuk mode web.
        new_refresh_token = create_refresh_token(
            data={
                "sub": str(db_user.id),
                "username": db_user.username,
                "role": db_user.role,
                "branch": db_user.branch,
                "token_version": db_user.token_version or 0,
            }
        )
        apply_refresh_cookie(response, new_refresh_token)

    return {
        "access_token": access_token,
        "token_type": "bearer",
        "username": db_user.username,
        "nama": db_user.nama,
        "role": db_user.role,
        "branch": db_user.branch,
        "branch_nama": branch_nama,
        "is_active": db_user.is_active,
    }


@router.post("/logout")
def logout(request: Request, response: Response):
    """Hapus cookie sesi admin web.

    Tanpa require_auth: dipanggil juga saat access token sudah kedaluwarsa
    supaya cookie tetap bersih. Request ber-cookie wajib berasal dari origin
    admin web yang sah (anti-CSRF) agar halaman lain tidak bisa memaksa
    logout korban.
    """
    if request.cookies.get(REFRESH_COOKIE_NAME) is not None:
        verify_csrf_origin(request, require_origin=True)
    clear_session_cookies(response)
    return {"detail": "Logout berhasil"}


@router.get("/me")
def me(
    db: Session = Depends(get_db),
    current_user: dict = Depends(require_auth),
):
    """Identitas user yang sedang login (untuk UI admin web).

    UI tidak perlu menyimpan username/role/branch di storage browser —
    cukup ambil dari sini setelah silent refresh.
    """
    branch_nama = branch_constants.get_branch_nama(current_user.get("branch"))
    return {**current_user, "branch_nama": branch_nama}


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
