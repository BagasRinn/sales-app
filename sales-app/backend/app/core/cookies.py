"""Sesi login admin web via cookie httpOnly.

Pola: refresh token hidup di cookie httpOnly dengan path terbatas ke
``/api/v1/auth`` — JavaScript di browser tidak bisa membacanya, sehingga
XSS tidak dapat mengeksfiltrasi kredensial jangka panjang. Access token
tetap dikirim di response body (disimpan in-memory oleh admin web) dan
endpoint bisnis tetap memakai ``Authorization: Bearer``, sehingga client
mobile tidak tersentuh perubahan ini (dual-mode: cookie ATAU body).

Proteksi CSRF untuk request yang mengandalkan cookie memakai validasi
header ``Origin``: admin web di-deploy di origin berbeda (Firebase Hosting)
sehingga cookie domain API tidak bisa dibaca JS untuk pola double-submit.
Browser selalu mengirim ``Origin`` pada request POST lintas-origin dan JS
tidak bisa memalsukannya, jadi cukup cocokkan dengan daftar origin yang
diizinkan (CORS_ORIGINS) atau origin API sendiri. Client mobile tidak
mengirim cookie, sehingga tidak relevan dan dilewati.
"""

import os
from typing import Optional, Tuple
from urllib.parse import urlparse

from fastapi import HTTPException, Request, Response, status

from app.core.security import REFRESH_TOKEN_EXPIRE_DAYS

_is_production = (os.getenv("ENVIRONMENT") or "").strip().lower() in (
    "production",
    "prod",
)

REFRESH_COOKIE_NAME = os.getenv("REFRESH_COOKIE_NAME", "admin_rt")

# Default mengikuti ENVIRONMENT: production lintas registrable domain butuh
# SameSite=None (wajib Secure); dev lokal memakai Lax agar tanpa ribet HTTPS.
COOKIE_SAMESITE = (
    os.getenv("COOKIE_SAMESITE") or ("none" if _is_production else "lax")
).strip().lower()
COOKIE_SECURE = (
    os.getenv("COOKIE_SECURE") or str(_is_production)
).strip().lower() in ("1", "true", "yes", "on")
# Host-only by default; set hanya bila cookie harus dibagikan lintas subdomain.
COOKIE_DOMAIN = (os.getenv("COOKIE_DOMAIN") or "").strip() or None
COOKIE_PATH = os.getenv("COOKIE_PATH", "/api/v1/auth")

# Selaras dengan masa hidup refresh token JWT di security.py.
REFRESH_COOKIE_MAX_AGE = REFRESH_TOKEN_EXPIRE_DAYS * 24 * 60 * 60


def _cookie_kwargs() -> dict:
    return {
        "path": COOKIE_PATH,
        "domain": COOKIE_DOMAIN,
        "secure": COOKIE_SECURE,
        "samesite": COOKIE_SAMESITE or None,
    }


def apply_refresh_cookie(response: Response, token: str) -> None:
    """Pasang refresh token di cookie httpOnly (rotation: selalu timpa yang lama)."""
    response.set_cookie(
        REFRESH_COOKIE_NAME,
        token,
        max_age=REFRESH_COOKIE_MAX_AGE,
        httponly=True,
        **_cookie_kwargs(),
    )


def clear_session_cookies(response: Response) -> None:
    """Hapus cookie sesi (dipakai /auth/logout)."""
    response.delete_cookie(REFRESH_COOKIE_NAME, **_cookie_kwargs())


def _allowed_origins() -> set:
    """Sumber yang sama dengan middleware CORS (env CORS_ORIGINS)."""
    return {
        origin.strip()
        for origin in os.getenv("CORS_ORIGINS", "").split(",")
        if origin.strip()
    }


def verify_csrf_origin(request: Request, require_origin: bool = False) -> None:
    """Validasi Origin untuk request yang mengandalkan cookie (anti-CSRF).

    Aturan:
    - Origin kosong = bukan browser yang memakai cookie (mobile/curl).
      Bila ``require_origin`` (flow cookie aktif) → tolak; selain itu lewati.
    - Origin harus terdaftar di CORS_ORIGINS atau sama dengan host API
      (deployment same-origin).
    """
    origin = request.headers.get("origin")
    if not origin:
        if require_origin:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Origin wajib untuk request berbasis cookie",
            )
        return

    if origin in _allowed_origins():
        return

    host = (request.headers.get("host") or "").lower()
    if host and urlparse(origin).netloc.lower() == host:
        return

    raise HTTPException(
        status_code=status.HTTP_403_FORBIDDEN,
        detail="Origin tidak diizinkan untuk request ini",
    )


def extract_refresh_token(
    request: Request, body_token: Optional[str]
) -> Tuple[Optional[str], str]:
    """Ambil refresh token dari cookie (admin web) atau body (mobile).

    Return ``(token, sumber)`` dengan sumber ``"cookie"``, ``"body"``, atau
    ``"none"``. Pemanggil wajib memanggil :func:`verify_csrf_origin` untuk
    sumber ``"cookie"``.
    """
    cookie_token = request.cookies.get(REFRESH_COOKIE_NAME)
    if cookie_token:
        return cookie_token, "cookie"
    if body_token:
        return body_token, "body"
    return None, "none"
