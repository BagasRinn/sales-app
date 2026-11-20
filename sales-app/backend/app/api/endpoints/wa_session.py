"""Kontrol sesi WhatsApp (pairing QR) lewat worker Baileys.

Halaman admin web tidak boleh bicara langsung ke worker: worker hanya ada di
network internal Docker dan dilindungi ``X-Internal-API-Key``. Endpoint di sini
mem-proxy request dengan JWT global MANAGER sebagai gerbang tambahan.
"""
import logging
import os

import httpx
from fastapi import APIRouter, Depends, HTTPException

from app.core.security import CurrentUser, require_manager_global
from app.schemas.schemas import WASessionStatusResponse

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/wa", tags=["WhatsApp Session"])

DEFAULT_TIMEOUT_SECONDS = 5.0


def _worker_base_url() -> str:
    url = (os.getenv("WA_WORKER_URL") or "").strip().rstrip("/")
    if not url:
        raise HTTPException(
            status_code=503,
            detail="WA_WORKER_URL belum dikonfigurasi.",
        )
    return url


def _internal_key() -> str:
    key = (os.getenv("INTERNAL_API_KEY") or "").strip()
    if not key:
        raise HTTPException(
            status_code=503,
            detail="INTERNAL_API_KEY kosong; kontrol WhatsApp tidak tersedia.",
        )
    return key


def _timeout_seconds() -> float:
    raw = (os.getenv("WA_WORKER_TIMEOUT_SECONDS") or "").strip()
    if not raw:
        return DEFAULT_TIMEOUT_SECONDS
    try:
        value = float(raw)
    except ValueError:
        return DEFAULT_TIMEOUT_SECONDS
    return value if value > 0 else DEFAULT_TIMEOUT_SECONDS


def _worker_request(method: str, path: str) -> httpx.Response:
    """Panggil control server worker. Dipisah agar mudah di-mock di test."""
    url = f"{_worker_base_url()}{path}"
    headers = {"X-Internal-API-Key": _internal_key()}
    try:
        with httpx.Client(timeout=_timeout_seconds()) as client:
            return client.request(method, url, headers=headers)
    except httpx.HTTPError as exc:
        logger.warning("[WA] Worker tidak bisa dihubungi: %s", exc)
        raise HTTPException(
            status_code=503,
            detail="Worker WhatsApp tidak bisa dihubungi.",
        ) from exc


def _normalize_response(response: httpx.Response) -> WASessionStatusResponse:
    if response.status_code != 200:
        raise HTTPException(
            status_code=503,
            detail=(
                "Worker WhatsApp mengembalikan HTTP "
                f"{response.status_code}."
            ),
        )
    try:
        data = response.json()
    except ValueError as exc:
        raise HTTPException(
            status_code=502,
            detail="Respons worker WhatsApp bukan JSON yang valid.",
        ) from exc
    if not isinstance(data, dict):
        raise HTTPException(
            status_code=502,
            detail="Respons worker WhatsApp tidak dikenali.",
        )
    return WASessionStatusResponse(**data)


@router.get("/session", response_model=WASessionStatusResponse)
def get_wa_session(
    _: CurrentUser = Depends(require_manager_global),
):
    """Status koneksi WhatsApp + QR (kalau sedang menunggu scan)."""
    return _normalize_response(_worker_request("GET", "/status"))


@router.post(
    "/session/logout",
    response_model=WASessionStatusResponse,
    status_code=202,
)
def logout_wa_session(
    _: CurrentUser = Depends(require_manager_global),
):
    """Putuskan sesi dan minta worker menyiapkan QR baru.

    Dipakai tombol "Putuskan & scan ulang" saat nomor diganti atau sesi
    terputus. Respons langsung 202; admin web mem-poll status untuk QR baru.
    """
    response = _worker_request("POST", "/logout")
    if response.status_code not in (200, 202):
        raise HTTPException(
            status_code=503,
            detail=(
                "Worker WhatsApp gagal memutuskan sesi "
                f"(HTTP {response.status_code})."
            ),
        )
    return WASessionStatusResponse(
        status="logging_out",
        connected=False,
        message="Sesi WhatsApp diputuskan; QR baru sedang disiapkan.",
    )
