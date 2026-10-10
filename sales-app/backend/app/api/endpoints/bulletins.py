"""Bulletin API endpoints -- CRUD + dismiss + PDF upload."""
from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, File
from sqlalchemy.orm import Session
from sqlalchemy import or_, exists
from uuid import UUID
from datetime import datetime, timezone, timedelta
from typing import List, Optional

from app.models.database import get_db
from app.models.models import Bulletin, BulletinDismiss
from app.schemas.schemas import BulletinCreate, BulletinUpdate, BulletinResponse
from app.core.security import require_auth, require_admin_or_supervisor, apply_branch_filter, CurrentUser
from app.core import branch as branch_constants
from app.services.supabase_storage import upload_pdf, delete_file


router = APIRouter(prefix="/bulletins", tags=["Bulletins"])


def _build_bulletin_response(bulletin: Bulletin, is_read: bool = False) -> dict:
    return {
        "id": bulletin.id,
        "branch": bulletin.branch,
        "branch_nama": branch_constants.get_branch_nama(bulletin.branch),
        "title": bulletin.title,
        "description": bulletin.description,
        "pdf_url": bulletin.pdf_url,
        "expire_at": bulletin.expire_at,
        "created_at": bulletin.created_at,
        "is_read": is_read,
    }


@router.get("", response_model=List[BulletinResponse])
def list_bulletins(
    include_read: bool = Query(
        False,
        alias="include_read",
        description="Jika true, include bulletins yang sudah di-dismiss oleh user ini",
    ),
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_auth),
):
    """List semua active bulletins (tidak expired).
    Non-expired = expire_at IS NULL OR expire_at >= now().
    Join BulletinDismiss untuk menyisipkan is_read flag per user.
    """
    wita = timezone(timedelta(hours=8))
    now_wita = datetime.now(wita)
    sales_id = UUID(current_user["user_id"])

    # EXISTS subquery: cek apakah bulletin sudah di-dismiss oleh user ini.
    # EXISTS lebih clean dari outer-join dengan subquery karena SQLAlchemy
    # tidak perlu treat BulletinDismiss sebagai FROM element tambahan.
    is_dismissed_by_me = exists().where(
        BulletinDismiss.bulletin_id == Bulletin.id,
        BulletinDismiss.sales_id == sales_id,
    )

    # When include_read=false: only show bulletins not yet dismissed
    base_filters = [
        or_(Bulletin.expire_at.is_(None), Bulletin.expire_at >= now_wita),
    ]
    if not include_read:
        base_filters.append(~is_dismissed_by_me)

    # Branch filter: NULL = global (visible to all), or matching branch
    user_branch = current_user.get("branch")
    if user_branch is not None:
        base_filters.append(
            or_(Bulletin.branch.is_(None), Bulletin.branch == user_branch)
        )

    query = db.query(Bulletin, is_dismissed_by_me.label("is_read")).filter(
        *base_filters,
    )

    results = query.order_by(Bulletin.created_at.desc()).all()
    return [_build_bulletin_response(b, bool(is_read)) for b, is_read in results]


@router.post("", response_model=BulletinResponse)
def create_bulletin(
    body: BulletinCreate,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_admin_or_supervisor),
):
    """Create bulletin."""
    bulletin = Bulletin(
        title=body.title,
        description=body.description,
        pdf_url=body.pdf_url,
        expire_at=body.expire_at,
        branch=current_user.get("branch"),  # ADMIN/SUPERVISOR -> their branch; MANAGER -> NULL (global)
        created_at=datetime.now(timezone.utc),
    )
    db.add(bulletin)
    db.commit()
    db.refresh(bulletin)
    return _build_bulletin_response(bulletin, is_read=False)


@router.post("/upload-pdf")
def bulletin_upload_pdf(
    file: UploadFile = File(...),
    _current_user: CurrentUser = Depends(require_admin_or_supervisor),
):
    """Upload file PDF ke Supabase Storage."""
    if not file.filename or not file.filename.lower().endswith(".pdf"):
        raise HTTPException(status_code=400, detail="Hanya file PDF yang diizinkan")

    content = file.file.read()
    if len(content) == 0:
        raise HTTPException(status_code=400, detail="File kosong")
    if len(content) > 10 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="Ukuran file maksimal 10MB")

    try:
        public_url = upload_pdf(content, file.filename)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except RuntimeError as e:
        raise HTTPException(status_code=500, detail=f"Upload gagal: {e}")

    return {"pdf_url": public_url}


@router.put("/{bulletin_id}", response_model=BulletinResponse)
def update_bulletin(
    bulletin_id: UUID,
    body: BulletinUpdate,
    db: Session = Depends(get_db),
    _current_user: CurrentUser = Depends(require_admin_or_supervisor),
):
    """Update bulletin."""
    bulletin = db.query(Bulletin).filter(Bulletin.id == bulletin_id).first()
    if not bulletin:
        raise HTTPException(status_code=404, detail="Bulletin tidak ditemukan")

    if body.title is not None:
        bulletin.title = body.title
    if body.description is not None:
        bulletin.description = body.description
    if body.pdf_url is not None:
        bulletin.pdf_url = body.pdf_url
    if body.expire_at is not None:
        bulletin.expire_at = body.expire_at

    bulletin.updated_at = datetime.now(timezone.utc)
    db.commit()
    db.refresh(bulletin)

    # is_read untuk current user (walaupun ini endpoint manager,
    # is_read di-response adalah field utilitarian -- not critical)
    sales_id = UUID(_current_user["user_id"])
    dismiss = (
        db.query(BulletinDismiss)
        .filter(BulletinDismiss.bulletin_id == bulletin_id, BulletinDismiss.sales_id == sales_id)
        .first()
    )
    return _build_bulletin_response(bulletin, is_read=bool(dismiss))


@router.delete("/{bulletin_id}", status_code=204)
def delete_bulletin(
    bulletin_id: UUID,
    db: Session = Depends(get_db),
    _current_user: CurrentUser = Depends(require_admin_or_supervisor),
):
    """Delete bulletin dan semua dismiss record terkait."""
    bulletin = db.query(Bulletin).filter(Bulletin.id == bulletin_id).first()
    if not bulletin:
        raise HTTPException(status_code=404, detail="Bulletin tidak ditemukan")

    db.query(BulletinDismiss).filter(BulletinDismiss.bulletin_id == bulletin_id).delete(
        synchronize_session=False
    )
    pdf_url = bulletin.pdf_url
    db.delete(bulletin)
    db.commit()

    if pdf_url:
        try:
            delete_file(pdf_url)
        except Exception:
            pass  # Non-critical -- file orphan boleh

    return None


@router.post("/{bulletin_id}/dismiss")
def dismiss_bulletin(
    bulletin_id: UUID,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_auth),
):
    """Mark bulletin sebagai di-dismiss (popup sudah ditutup) oleh current user.
    Idempotent - memanggil ulang tidak error."""
    bulletin = db.query(Bulletin).filter(Bulletin.id == bulletin_id).first()
    if not bulletin:
        raise HTTPException(status_code=404, detail="Bulletin tidak ditemukan")

    sales_id = UUID(current_user["user_id"])

    existing = (
        db.query(BulletinDismiss)
        .filter(BulletinDismiss.bulletin_id == bulletin_id, BulletinDismiss.sales_id == sales_id)
        .first()
    )
    if existing:
        return {"message": "Already dismissed", "bulletin_id": str(bulletin_id)}

    dismiss = BulletinDismiss(
        bulletin_id=bulletin_id,
        sales_id=sales_id,
        dismissed_at=datetime.now(timezone.utc),
    )
    db.add(dismiss)
    db.commit()
    return {"message": "Dismissed", "bulletin_id": str(bulletin_id)}
