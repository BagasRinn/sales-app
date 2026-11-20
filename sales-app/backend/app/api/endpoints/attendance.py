"""Integrasi absensi kunjungan sales dari grup WhatsApp.

* ``POST /webhooks/wa-attendance`` — dipanggil worker Baileys, autentikasi
  ``X-Internal-API-Key`` (fail-closed: menolak 503 bila server belum punya key).
* ``GET  /sales-attendances`` — dibaca admin web / aplikasi Flutter dengan JWT
  existing dan scope branch yang sama seperti endpoint lain.
"""
import hmac
import logging
import os
from datetime import datetime
from typing import List, Optional
from uuid import UUID

from fastapi import APIRouter, Depends, Header, HTTPException, Query, Response
from sqlalchemy import false
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.security import (
    CurrentUser,
    is_global_manager,
    require_auth,
)
from app.core.timezone import local_day_utc_bounds
from app.models.database import get_db
from app.models.models import SalesAttendance, User
from app.schemas.schemas import (
    SalesAttendanceResponse,
    WAAttendanceWebhookPayload,
    WAAttendanceWebhookResponse,
)

logger = logging.getLogger(__name__)

router = APIRouter(tags=["Sales Attendance"])


def _expected_internal_key() -> str:
    """Dibaca saat request agar test/env loader bisa mengubahnya."""
    return (os.getenv("INTERNAL_API_KEY") or "").strip()


def require_internal_api_key(
    x_internal_api_key: Optional[str] = Header(
        default=None, alias="X-Internal-API-Key"
    ),
) -> None:
    """Validasi shared secret worker ↔ backend.

    Fail-closed: tanpa ``INTERNAL_API_KEY`` di server, endpoint menolak semua
    request (503) alih-alih membiarkan webhook terbuka.
    """
    expected = _expected_internal_key()
    if not expected:
        raise HTTPException(
            status_code=503,
            detail="Webhook absensi belum dikonfigurasi (INTERNAL_API_KEY kosong).",
        )
    if not x_internal_api_key or not hmac.compare_digest(
        str(x_internal_api_key), expected
    ):
        raise HTTPException(status_code=401, detail="X-Internal-API-Key tidak valid")


def _resolve_sales(db: Session, phone: str) -> Optional[User]:
    """Cari user ber-role SALES yang nomornya cocok (aktif, belum dihapus)."""
    return (
        db.query(User)
        .filter(
            User.whatsapp_number == phone,
            User.role == "SALES",
            User.is_active.is_(True),
            User.deleted_at.is_(None),
        )
        .first()
    )


@router.post(
    "/webhooks/wa-attendance",
    response_model=WAAttendanceWebhookResponse,
    status_code=201,
)
def receive_wa_attendance(
    payload: WAAttendanceWebhookPayload,
    response: Response,
    db: Session = Depends(get_db),
    _: None = Depends(require_internal_api_key),
):
    """Terima satu pesan absensi dari worker WhatsApp.

    Idempotent lewat ``wa_message_id``: pesan yang dikirim ulang Baileys
    (reconnect / history sync) mengembalikan 200 ``duplicate=true`` tanpa
    menulis baris baru.
    """
    if payload.wa_message_id:
        existing = (
            db.query(SalesAttendance)
            .filter(SalesAttendance.wa_message_id == payload.wa_message_id)
            .first()
        )
        if existing:
            response.status_code = 200
            return WAAttendanceWebhookResponse(
                status="ignored",
                attendance_id=existing.id,
                duplicate=True,
                is_registered_sales=existing.is_registered_sales,
                sales_id=existing.sales_id,
                message="Pesan sudah pernah dicatat",
            )

    sender = _resolve_sales(db, payload.sender_phone)
    push_name = (payload.sender_push_name or "").strip() or "Unknown"

    if sender:
        sales_id = sender.id
        sales_name = sender.nama or sender.username or push_name
        is_registered = True
    else:
        sales_id = None
        sales_name = push_name
        is_registered = False

    attendance = SalesAttendance(
        sales_id=sales_id,
        sales_name=sales_name,
        sender_phone=payload.sender_phone,
        sender_push_name=payload.sender_push_name,
        is_registered_sales=is_registered,
        outlet_code=payload.outlet_code.strip().upper(),
        outlet_name=payload.outlet_name.strip(),
        outlet_channel=payload.outlet_channel.strip(),
        has_photo_proof=payload.has_photo_proof,
        wa_group_id=payload.wa_group_id,
        wa_message_id=payload.wa_message_id,
        visited_at=payload.message_timestamp,
        raw_message=payload.raw_message,
    )
    db.add(attendance)
    try:
        db.commit()
    except IntegrityError:
        # Balapan dengan worker lain untuk wa_message_id yang sama.
        db.rollback()
        duplicate = None
        if payload.wa_message_id:
            duplicate = (
                db.query(SalesAttendance)
                .filter(SalesAttendance.wa_message_id == payload.wa_message_id)
                .first()
            )
        if duplicate:
            response.status_code = 200
            return WAAttendanceWebhookResponse(
                status="ignored",
                attendance_id=duplicate.id,
                duplicate=True,
                is_registered_sales=duplicate.is_registered_sales,
                sales_id=duplicate.sales_id,
                message="Pesan sudah pernah dicatat",
            )
        raise

    db.refresh(attendance)
    logger.info(
        "[ATTENDANCE] %s | %s#%s#%s | registered=%s",
        attendance.sender_phone,
        attendance.outlet_code,
        attendance.outlet_name,
        attendance.outlet_channel,
        attendance.is_registered_sales,
    )
    return WAAttendanceWebhookResponse(
        status="created",
        attendance_id=attendance.id,
        duplicate=False,
        is_registered_sales=is_registered,
        sales_id=sales_id,
        message="Absensi tersimpan",
    )


@router.get("/sales-attendances", response_model=List[SalesAttendanceResponse])
def list_sales_attendances(
    date: Optional[str] = Query(None, description="Tanggal kunjungan (YYYY-MM-DD)"),
    sales_id: Optional[str] = Query(None, description="Filter satu sales (UUID)"),
    is_registered_sales: Optional[bool] = Query(
        None, description="True = hanya nomor terdaftar, False = tidak terdaftar"
    ),
    outlet_channel: Optional[str] = Query(None, description="Filter channel outlet"),
    limit: int = Query(200, ge=1, le=1000),
    offset: int = Query(0, ge=0),
    timezone_offset_minutes: Optional[int] = Header(
        default=None, alias="X-Timezone-Offset-Minutes"
    ),
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_auth),
):
    """List absensi sales, terbaru lebih dulu.

    Scope: global MANAGER melihat semua; user branch-scoped hanya melihat
    absensi milik sales di cabangnya. Absensi dari nomor tak terdaftar
    (``sales_id`` NULL) tidak punya cabang sehingga hanya tampil untuk global
    MANAGER.
    """
    query = db.query(SalesAttendance)

    if not is_global_manager(current_user):
        branch = current_user.get("branch")
        if branch is None:
            # Fail-closed: akun branch-scoped tanpa branch tidak melihat apa pun.
            query = query.filter(false())
        else:
            query = query.join(
                User, SalesAttendance.sales_id == User.id
            ).filter(User.branch == branch)

    if date:
        try:
            target_date = datetime.strptime(date, "%Y-%m-%d").date()
        except ValueError:
            raise HTTPException(
                status_code=400, detail="Format tanggal harus YYYY-MM-DD"
            )
        start_utc, end_utc = local_day_utc_bounds(
            target_date, timezone_offset_minutes=timezone_offset_minutes
        )
        query = query.filter(
            SalesAttendance.visited_at >= start_utc,
            SalesAttendance.visited_at < end_utc,
        )

    if sales_id:
        try:
            sales_uuid = UUID(sales_id)
        except (TypeError, ValueError):
            raise HTTPException(status_code=400, detail="sales_id harus UUID valid")
        query = query.filter(SalesAttendance.sales_id == sales_uuid)
    if is_registered_sales is not None:
        query = query.filter(
            SalesAttendance.is_registered_sales.is_(is_registered_sales)
        )
    if outlet_channel:
        query = query.filter(
            SalesAttendance.outlet_channel == outlet_channel.strip()
        )

    return (
        query.order_by(SalesAttendance.visited_at.desc())
        .offset(offset)
        .limit(limit)
        .all()
    )
