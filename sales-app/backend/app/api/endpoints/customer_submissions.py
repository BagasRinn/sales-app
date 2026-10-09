"""Customer registration submission endpoints.
Sales submit pengajuan customer baru → admin/manager review → approve (bikin Customer row) atau reject.
"""
from datetime import datetime, timezone
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import text, or_, func
from sqlalchemy.orm import Session
from uuid import UUID, uuid4
import logging

from app.models.database import get_db
from app.models.models import Customer, CustomerRegistrationSubmission, Order, OrderItem, Product, User, CustomerAssignment, StokLog
from app.schemas.schemas import (
    CustomerSubmissionCreate,
    CustomerSubmissionResponse,
    CustomerSubmissionApprove,
    CustomerSubmissionReject,
    CustomerSubmissionCancelRequest,
    CustomerSubmissionCancelResponse,
)
from app.core.security import require_auth, require_admin, require_manager, apply_branch_filter, CurrentUser

router = APIRouter(prefix="/customer-submissions", tags=["Customer Submissions"])
logger = logging.getLogger(__name__)


def _serialize(submission: CustomerRegistrationSubmission, db: Session) -> dict:
    """Serialize submission + lookup sales_name & reviewed_by_name + nested order."""
    sales = db.query(User).filter(User.id == submission.sales_id).first()
    reviewer = (
        db.query(User).filter(User.id == submission.reviewed_by).first()
        if submission.reviewed_by
        else None
    )
    result = {
        "id": submission.id,
        "branch": submission.branch,
        "sales_id": submission.sales_id,
        "sales_nama": (sales.nama or sales.username) if sales else None,
        "sales_username": sales.username if sales else None,
        "status": submission.status,
        "reject_reason": submission.reject_reason,
        "approved_customer_id": submission.approved_customer_id,
        "bareng_customer_id": submission.bareng_customer_id,
        "reviewed_by": submission.reviewed_by,
        "reviewed_by_nama": (reviewer.nama or reviewer.username) if reviewer else None,
        "reviewed_at": submission.reviewed_at,
        "created_at": submission.created_at,
        "updated_at": submission.updated_at,
        "nama_langganan": submission.nama_langganan,
        "nomor_id_ktp": submission.nomor_id_ktp,
        "alamat_ktp": submission.alamat_ktp,
        "nama_kontak_pemilik": submission.nama_kontak_pemilik,
        "telpon_hp": submission.telpon_hp,
        "alamat_kirim": submission.alamat_kirim,
        "propinsi": submission.propinsi,
        "kecamatan": submission.kecamatan,
        "kota": submission.kota,
        "kelurahan": submission.kelurahan,
        "area_route": submission.area_route,
        "kode_area": submission.kode_area,
        "tipe_langganan": submission.tipe_langganan,
        "tipe_pembayaran": submission.tipe_pembayaran,
        "nama_pasar": submission.nama_pasar,
        "jangka_kredit_hari": submission.jangka_kredit_hari,
        "batas_kredit_rupiah": submission.batas_kredit_rupiah,
        "channel_kategori": submission.channel_kategori,
        "key_account_ref_id": submission.key_account_ref_id,
        "cluster_langganan": submission.cluster_langganan,
        "kode_salesman": submission.kode_salesman,
        "nama_salesman": submission.nama_salesman,
        "siklus_kunjungan": submission.siklus_kunjungan,
        "hari_kunjungan": submission.hari_kunjungan,
    }

    # Include nested order if bareng_order=True (identified by bareng_customer_id).
    if submission.bareng_customer_id:
        linked_order = (
            db.query(Order)
            .filter(
                Order.customer_id == submission.bareng_customer_id,
                Order.sales_id == submission.sales_id,
            )
            .first()
        )
        if linked_order:
            from app.api.endpoints.orders import _build_order_response
            result["order"] = _build_order_response(linked_order)
        else:
            result["order"] = None
    else:
        result["order"] = None

    return result


@router.post("", response_model=CustomerSubmissionResponse, status_code=201)
def submit_customer_registration(
    payload: CustomerSubmissionCreate,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_auth),
):
    """Submit pengajuan customer baru.
    - Jika bareng_order=True, customer langsung dibuat agar sales bisa langsung order.
    - Status submission tetap PENDING — admin perlu approve untuk mengesahkan.
    sales_id otomatis dari token (siapa yang login).
    """
    sales_id = UUID(current_user["user_id"])

    # Buat dict payload, pisahkan field non-database (flag & order-related).
    payload_dict = payload.model_dump()
    bareng_order = payload_dict.pop("bareng_order", False)
    # order_type hanya untuk flow bareng_order, bukan field submission.
    payload_dict.pop("order_type", None)

    # Auto-fill salesman info dari auth token — submission melacak siapa yang mengajukan.
    payload_dict["kode_salesman"] = current_user.get("username")
    payload_dict["nama_salesman"] = current_user.get("nama")

    submission = CustomerRegistrationSubmission(
        id=uuid4(),
        sales_id=sales_id,
        branch=current_user.get("branch"),
        status='PENDING',
        **payload_dict,
    )
    db.add(submission)
    db.flush()  # dapat UUID submission

    bareng_customer_id = None
    if bareng_order:
        # Auto-create customer placeholder so sales can order right away.
        customer_id = uuid4()
        customer = Customer(
            id=customer_id,
            kode=None,  # admin assigns this on approve
            nama_toko=payload.nama_langganan,
            alamat=payload.alamat_kirim or payload.alamat_ktp or '',
            kode_area=payload.kode_area,
            branch=current_user.get("branch"),
        )
        db.add(customer)

        # Scope visibility: only the submitting sales sees this placeholder.
        assignment = CustomerAssignment(
            customer_id=customer_id,
            sales_id=sales_id,
            assigned_at=datetime.now(timezone.utc),
            assigned_by=sales_id,
        )
        db.add(assignment)

        # Create the order in DRAFT status.
        order_type = (payload.order_type or 'REGULER').upper()
        if order_type not in ('REGULER', '4P'):
            raise HTTPException(
                status_code=400,
                detail=f"order_type tidak valid: {payload.order_type}. Harus 'REGULER' atau '4P'."
            )
        order = Order(
            id=uuid4(),
            sales_id=sales_id,
            customer_id=customer_id,
            branch=current_user.get("branch"),
            status='DRAFT',
            created_at=datetime.now(timezone.utc),
            order_type=order_type,
            store_name=payload.nama_langganan,
            store_contact=None,
            store_address=payload.alamat_kirim or payload.alamat_ktp or '',
        )
        db.add(order)
        db.flush()  # get order.id

        # Order dibuat kosong di sini. Items dipilih sales di OrderFlowScreen
        # setelah submit — endpoint order flow yang handle items + booking.
        submission.bareng_customer_id = customer_id
        bareng_customer_id = customer_id

    db.commit()
    db.refresh(submission)

    result = _serialize(submission, db)
    result["bareng_customer_id"] = bareng_customer_id
    return result


@router.get("/my", response_model=List[CustomerSubmissionResponse])
def list_my_submissions(
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_auth),
):
    """Sales lihat history submission sendiri (semua status, urut terbaru)."""
    sales_id = UUID(current_user["user_id"])
    submissions = (
        db.query(CustomerRegistrationSubmission)
        .filter(CustomerRegistrationSubmission.sales_id == sales_id)
    )
    submissions = apply_branch_filter(submissions, CustomerRegistrationSubmission, current_user)
    submissions = submissions.order_by(CustomerRegistrationSubmission.created_at.desc()).all()
    return [_serialize(s, db) for s in submissions]


@router.get("/check-duplicate")
def check_duplicate_customer(
    name: str = Query(..., min_length=1, description="Nama toko yang akan disubmit"),
    alamat: str = Query("", description="Alamat toko (opsional)"),
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_auth),
):
    """Cek apakah ada customer existing dengan nama+alamat mirip (LIKE).
    Return list match — frontend show warning tapi tetap boleh submit."""
    name_pattern = f"%{name.lower()}%"
    query = db.query(Customer).filter(
        Customer.deleted_at.is_(None),
        func.lower(Customer.nama_toko).like(name_pattern),
    )
    if alamat and alamat.strip():
        alamat_pattern = f"%{alamat.lower()}%"
        query = query.filter(func.lower(Customer.alamat).like(alamat_pattern))

    matches = query.limit(5).all()
    return {
        "has_duplicate": len(matches) > 0,
        "matches": [
            {
                "id": c.id,
                "kode": c.kode,
                "nama_toko": c.nama_toko,
                "alamat": c.alamat,
            }
            for c in matches
        ],
    }


@router.get("", response_model=List[CustomerSubmissionResponse])
def list_submissions(
    status: Optional[str] = Query(None, description="Filter status: PENDING/APPROVED/REJECTED"),
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_manager),
):
    """Admin/manager lihat semua submissions. Default: semua status (untuk log view)."""
    query = db.query(CustomerRegistrationSubmission)
    query = apply_branch_filter(query, CustomerRegistrationSubmission, current_user)
    if status:
        query = query.filter(CustomerRegistrationSubmission.status == status.upper())
    submissions = query.order_by(CustomerRegistrationSubmission.created_at.desc()).all()
    return [_serialize(s, db) for s in submissions]


@router.get("/{submission_id}", response_model=CustomerSubmissionResponse)
def get_submission(
    submission_id: UUID,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_auth),
):
    """Detail submission. Admin/manager bisa lihat semua; sales hanya bisa lihat milik sendiri."""
    submission = db.query(CustomerRegistrationSubmission).filter(
        CustomerRegistrationSubmission.id == submission_id
    ).first()
    if not submission:
        raise HTTPException(status_code=404, detail="Pengajuan tidak ditemukan")

    role = current_user.get("role")
    user_id = current_user["user_id"]
    if role not in ("ADMIN", "MANAGER") and str(submission.sales_id) != user_id:
        raise HTTPException(status_code=403, detail="Tidak punya akses ke pengajuan ini")
    # Branch access check for ADMIN
    if role == "ADMIN" and current_user.get("branch") is not None:
        if submission.branch != current_user["branch"]:
            raise HTTPException(status_code=403, detail="Tidak punya akses ke pengajuan ini")

    return _serialize(submission, db)


@router.post("/{submission_id}/approve", response_model=dict, status_code=201)
def approve_submission(
    submission_id: UUID,
    payload: CustomerSubmissionApprove,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_admin),
):
    """Approve submission → bikin Customer baru (dengan kode dari admin) → update submission jadi APPROVED."""
    submission = (
        db.query(CustomerRegistrationSubmission)
        .filter(CustomerRegistrationSubmission.id == submission_id)
        .with_for_update()
        .first()
    )
    if not submission:
        raise HTTPException(status_code=404, detail="Pengajuan tidak ditemukan")
    if current_user.get("branch") is not None and submission.branch != current_user["branch"]:
        raise HTTPException(status_code=403, detail="Tidak punya akses ke pengajuan ini")
    if submission.status != "PENDING":
        raise HTTPException(
            status_code=409,
            detail=f"Pengajuan tidak bisa di-approve (status saat ini: {submission.status})",
        )

    # Cek kode belum dipakai customer lain (kecuali customer bareng_order).
    kode = payload.kode.strip()
    existing = db.query(Customer).filter(
        Customer.deleted_at.is_(None),
        Customer.kode == kode,
    ).first()
    if existing and existing.id != submission.bareng_customer_id:
        raise HTTPException(
            status_code=409,
            detail=f"Kode '{kode}' sudah dipakai customer lain",
        )

    admin_id = UUID(current_user["user_id"])
    submission.status = 'APPROVED'
    submission.reviewed_by = admin_id
    submission.reviewed_at = datetime.now(timezone.utc)
    submission.updated_at = datetime.now(timezone.utc)

    # Kalau customer sudah dibuat saat submission (via bareng_order),
    # cukup update kode-nya. Jangan bikin customer baru.
    if submission.bareng_customer_id:
        existing_customer = db.query(Customer).filter(
            Customer.id == submission.bareng_customer_id
        ).first()
        if existing_customer:
            existing_customer.kode = kode
            # Copy kode_area from submission if set (do NOT override NULL — legacy
            # placeholder may already have a value from create).
            if submission.kode_area:
                existing_customer.kode_area = submission.kode_area
            # Apply optional overrides from admin payload.
            if payload.nama_toko:
                existing_customer.nama_toko = payload.nama_toko
            if payload.alamat:
                existing_customer.alamat = payload.alamat
        submission.approved_customer_id = submission.bareng_customer_id

        # Transition order to PENDING so admin reviews items in Pesanan tab.
        # NOT CONFIRMED — that bypasses admin review.
        linked_order = db.query(Order).filter(
            Order.customer_id == submission.bareng_customer_id,
            Order.sales_id == submission.sales_id,
        ).first()
        if linked_order:
            linked_order.status = 'PENDING'

        db.commit()
        db.refresh(submission)
        # Serialize nested order in response.
        from app.api.endpoints.orders import _build_order_response
        result = {
            "submission": _serialize(submission, db),
            "customer": {
                "id": str(submission.bareng_customer_id),
                "kode": kode,
                "nama_toko": existing_customer.nama_toko if existing_customer else submission.nama_langganan,
                "alamat": existing_customer.alamat if existing_customer else None,
            },
        }
        if linked_order:
            result["order"] = _build_order_response(linked_order)
        else:
            result["order"] = None
        return result

    # Bikin Customer baru. Nama & alamat dari submission, override kalau admin isi.
    nama_toko = (payload.nama_toko or submission.nama_langganan).strip()
    alamat = (payload.alamat or submission.alamat_kirim or "").strip()

    customer = Customer(
        id=uuid4(),
        kode=kode,
        nama_toko=nama_toko,
        alamat=alamat if alamat else None,
        kode_area=submission.kode_area,
    )
    db.add(customer)
    db.flush()  # dapet customer.id

    submission.approved_customer_id = customer.id

    db.commit()
    db.refresh(customer)
    db.refresh(submission)

    return {
        "submission": _serialize(submission, db),
        "customer": {
            "id": customer.id,
            "kode": customer.kode,
            "nama_toko": customer.nama_toko,
            "alamat": customer.alamat,
        },
    }


@router.post("/{submission_id}/reject")
def reject_submission(
    submission_id: UUID,
    payload: CustomerSubmissionReject,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_manager),
):
    """Reject submission → status jadi REJECTED dengan reject_reason (opsional)."""
    submission = (
        db.query(CustomerRegistrationSubmission)
        .filter(CustomerRegistrationSubmission.id == submission_id)
        .with_for_update()
        .first()
    )
    if not submission:
        raise HTTPException(status_code=404, detail="Pengajuan tidak ditemukan")
    if current_user.get("branch") is not None and submission.branch != current_user["branch"]:
        raise HTTPException(status_code=403, detail="Tidak punya akses ke pengajuan ini")
    if submission.status != "PENDING":
        raise HTTPException(
            status_code=409,
            detail=f"Pengajuan tidak bisa di-reject (status saat ini: {submission.status})",
        )

    admin_id = UUID(current_user["user_id"])
    submission.status = 'REJECTED'
    submission.reject_reason = payload.reject_reason
    submission.reviewed_by = admin_id
    submission.reviewed_at = datetime.now(timezone.utc)
    submission.updated_at = datetime.now(timezone.utc)

    if submission.bareng_customer_id:
        # Cancel linked order and release stock.
        linked_order = db.query(Order).filter(
            Order.customer_id == submission.bareng_customer_id,
            Order.sales_id == submission.sales_id,
        ).first()
        if linked_order:
            linked_order.status = 'CANCELLED'
            # Release stock bookings.
            items = db.query(OrderItem).filter(OrderItem.order_id == linked_order.id).all()
            for item in items:
                result = db.execute(
                    text(
                        "UPDATE products "
                        "SET stok_booking = stok_booking - :qty "
                        "WHERE id = :pid "
                        "RETURNING stok_booking"
                    ),
                    {"pid": item.product_id, "qty": item.qty},
                ).first()
                if result:
                    new_booking = result[0]
                    old_booking = new_booking + item.qty
                    # Write StokLog entry.
                    log_entry = StokLog(
                        id=uuid4(),
                        product_id=item.product_id,
                        sumber="CANCEL",
                        field_terdampak="stok_booking",
                        delta=-item.qty,
                        nilai_sebelum=old_booking,
                        nilai_sesudah=new_booking,
                        actor_id=admin_id,
                        order_id=linked_order.id,
                    )
                    db.add(log_entry)

        # Soft-delete placeholder customer.
        placeholder = db.query(Customer).filter(
            Customer.id == submission.bareng_customer_id
        ).first()
        if placeholder:
            placeholder.deleted_at = datetime.now(timezone.utc)

    db.commit()
    db.refresh(submission)
    return _serialize(submission, db)


@router.post("/{submission_id}/cancel", response_model=CustomerSubmissionCancelResponse)
def cancel_submission(
    submission_id: UUID,
    _body: CustomerSubmissionCancelRequest,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_auth),
):
    """Sales membatalkan submission mereka sendiri.
    - Hanya SALES role yang boleh memanggil endpoint ini.
    - Hanya owner (submission.sales_id == current_user.user_id) yang boleh.
    - Submission harus berstatus PENDING.
    """
    if current_user["role"] != "SALES":
        raise HTTPException(
            status_code=403,
            detail="Hanya sales yang dapat membatalkan pengajuan sendiri",
        )

    sales_id = UUID(current_user["user_id"])
    submission = (
        db.query(CustomerRegistrationSubmission)
        .filter(CustomerRegistrationSubmission.id == submission_id)
        .with_for_update()
        .first()
    )
    if not submission:
        raise HTTPException(status_code=404, detail="Pengajuan tidak ditemukan")
    if submission.sales_id != sales_id:
        raise HTTPException(status_code=403, detail="Tidak punya akses ke pengajuan ini")
    if submission.status != "PENDING":
        raise HTTPException(
            status_code=409,
            detail=f"Pengajuan tidak bisa dibatalkan (status saat ini: {submission.status})",
        )

    submission.status = 'CANCELLED'
    submission.updated_at = datetime.now(timezone.utc)

    if submission.bareng_customer_id:
        # Cancel linked order and release stock (same logic as reject).
        linked_order = db.query(Order).filter(
            Order.customer_id == submission.bareng_customer_id,
            Order.sales_id == submission.sales_id,
        ).first()
        if linked_order:
            linked_order.status = 'CANCELLED'
            items = db.query(OrderItem).filter(OrderItem.order_id == linked_order.id).all()
            for item in items:
                result = db.execute(
                    text(
                        "UPDATE products "
                        "SET stok_booking = stok_booking - :qty "
                        "WHERE id = :pid "
                        "RETURNING stok_booking"
                    ),
                    {"pid": item.product_id, "qty": item.qty},
                ).first()
                if result:
                    new_booking = result[0]
                    old_booking = new_booking + item.qty
                    log_entry = StokLog(
                        id=uuid4(),
                        product_id=item.product_id,
                        sumber="CANCEL",
                        field_terdampak="stok_booking",
                        delta=-item.qty,
                        nilai_sebelum=old_booking,
                        nilai_sesudah=new_booking,
                        actor_id=sales_id,
                        order_id=linked_order.id,
                    )
                    db.add(log_entry)

        # Soft-delete placeholder.
        placeholder = db.query(Customer).filter(
            Customer.id == submission.bareng_customer_id
        ).first()
        if placeholder:
            placeholder.deleted_at = datetime.now(timezone.utc)

    db.commit()

    return CustomerSubmissionCancelResponse(
        message="Pengajuan berhasil dibatalkan",
        submission_id=submission.id,
        status="CANCELLED",
    )
