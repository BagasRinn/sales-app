"""Daily and period order reports — Excel export untuk admin & manager."""
from datetime import datetime, timedelta, timezone
from io import BytesIO
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import StreamingResponse
from openpyxl import Workbook
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.utils import get_column_letter
from sqlalchemy.orm import Session, joinedload

from app.models.database import get_db
from app.models.models import Order, OrderItem, Product, Customer, User
from app.core.security import require_manager

router = APIRouter(prefix="/reports", tags=["Reports"])


def _nilai_diskon(harga_satuan: int, qty: int, discount_type: str,
                   discount_percent: int, discount_nominal: int) -> int:
    """Hitung nilai diskon dalam nominal ( rupiah)."""
    if (discount_type or "PERCENT").upper() == "NOMINAL":
        return max(0, (discount_nominal or 0))
    pct = max(0, min(100, discount_percent or 0))
    return int(harga_satuan * qty * pct / 100)


def _harga_setelah(harga_satuan: int, qty: int, discount_type: str,
                   discount_percent: int, discount_nominal: int) -> int:
    """Hitung total harga setelah diskon per-qty."""
    nilai = _nilai_diskon(harga_satuan, qty, discount_type, discount_percent, discount_nominal)
    return max(0, harga_satuan * qty - nilai)


def _build_report(
    orders,
    ws: Workbook.active,
    title: str,
) -> int:
    """Generate report rows with 12-column format. Returns row count."""
    ws.title = title

    headers = [
        "Kode Pelanggan",
        "Nama Pelanggan",
        "Kode Item",
        "Nama Item",
        "Qty",
        "Satuan",
        "Harga Satuan",
        "Total Harga Sebelum Diskon",
        "Nilai Diskon",
        "Total Harga Setelah Diskon",
        "Nama Sales",
        "Supplier",
    ]
    ws.append(headers)

    header_font = Font(bold=True, color="FFFFFF")
    header_fill = PatternFill(start_color="1976D2", end_color="1976D2", fill_type="solid")
    for cell in ws[1]:
        cell.font = header_font
        cell.fill = header_fill
        cell.alignment = Alignment(horizontal="center", vertical="center")

    total_rows = 0
    for order in orders:
        customer = order.customer
        sales = order.sales
        sales_name = ""
        if sales:
            sales_name = sales.nama if (sales.nama and sales.nama.strip()) else (sales.username or "")
        for item in order.items:
            product = item.product
            harga_satuan = product.harga if product else 0
            qty = item.qty
            total_sebelum_diskon = harga_satuan * qty
            nilai_diskon = _nilai_diskon(
                harga_satuan,
                qty,
                item.discount_type or "PERCENT",
                item.discount_percent or 0,
                item.discount_nominal or 0,
            )
            total_setelah_diskon = _harga_setelah(
                harga_satuan,
                qty,
                item.discount_type or "PERCENT",
                item.discount_percent or 0,
                item.discount_nominal or 0,
            )

            ws.append([
                customer.kode if customer else "",
                customer.nama_toko if customer else "",
                item.product_id or "",
                product.nama_barang if product else "",
                qty,
                product.satuan if product else "",
                harga_satuan,
                total_sebelum_diskon,
                nilai_diskon,
                total_setelah_diskon,
                sales_name,
                product.nama_supplier if product else "",
            ])
            total_rows += 1

    # Auto-width columns
    widths = [16, 28, 14, 32, 6, 8, 14, 20, 14, 20, 20, 28]
    for i, w in enumerate(widths, 1):
        ws.column_dimensions[get_column_letter(i)].width = w

    return total_rows


@router.get("/daily")
def daily_report(
    date: str = Query(..., description="Tanggal laporan, format YYYY-MM-DD (WITA)"),
    status: str = Query(
        "APPROVED",
        description="Status filter, comma-separated. Default APPROVED.",
    ),
    db: Session = Depends(get_db),
    _current_user: dict = Depends(require_manager),
):
    """Generate Excel laporan harian. Timezone mengikuti sales app (WITA/UTC+8).

    12 kolom: Kode/Nama Pelanggan, Kode/Nama Item, Qty, Satuan,
    Harga Satuan, Total Sebelum Diskon, Nilai Diskon, Total Setelah Diskon,
    Nama Sales, Supplier.
    """
    try:
        target_date = datetime.strptime(date, "%Y-%m-%d").date()
    except ValueError:
        raise HTTPException(status_code=400, detail="Format tanggal harus YYYY-MM-DD")

    statuses = [s.strip().upper() for s in status.split(",") if s.strip()]
    if not statuses:
        statuses = ["APPROVED"]

    wita = timezone(timedelta(hours=8))
    start_of_day = datetime.combine(target_date, datetime.min.time()).replace(tzinfo=wita)
    end_of_day = start_of_day + timedelta(days=1)
    start_utc = start_of_day.astimezone(timezone.utc)
    end_utc = end_of_day.astimezone(timezone.utc)

    orders = (
        db.query(Order)
        .options(
            joinedload(Order.items).joinedload(OrderItem.product),
            joinedload(Order.customer),
            joinedload(Order.sales),
        )
        .filter(
            Order.status.in_(statuses),
            Order.created_at >= start_utc,
            Order.created_at < end_utc,
        )
        .order_by(Order.created_at.asc())
        .all()
    )

    wb = Workbook()
    ws = wb.active
    _build_report(orders, ws, f"Laporan {target_date.isoformat()}")

    buffer = BytesIO()
    wb.save(buffer)
    buffer.seek(0)

    filename = f"laporan-harian-{target_date.isoformat()}.xlsx"
    return StreamingResponse(
        buffer,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@router.get("/period")
def period_report(
    start_date: str = Query(..., description="Tanggal mulai, YYYY-MM-DD (WITA)"),
    end_date: str = Query(..., description="Tanggal akhir, YYYY-MM-DD (WITA)"),
    status: str = Query(
        "APPROVED",
        description="Status filter, comma-separated. Default APPROVED.",
    ),
    db: Session = Depends(get_db),
    _current_user: dict = Depends(require_manager),
):
    """Generate Excel laporan berdasarkan rentang tanggal. Timezone WITA/UTC+8.

    12 kolom sama dengan laporan harian.
    """
    try:
        start = datetime.strptime(start_date, "%Y-%m-%d").date()
    except ValueError:
        raise HTTPException(status_code=400, detail="Format tanggal mulai harus YYYY-MM-DD")
    try:
        end = datetime.strptime(end_date, "%Y-%m-%d").date()
    except ValueError:
        raise HTTPException(status_code=400, detail="Format tanggal akhir harus YYYY-MM-DD")

    if end < start:
        raise HTTPException(status_code=400, detail="Tanggal akhir tidak boleh sebelum tanggal mulai")

    statuses = [s.strip().upper() for s in status.split(",") if s.strip()]
    if not statuses:
        statuses = ["APPROVED"]

    wita = timezone(timedelta(hours=8))
    start_of_day = datetime.combine(start, datetime.min.time()).replace(tzinfo=wita)
    end_of_day = datetime.combine(end + timedelta(days=1), datetime.min.time()).replace(tzinfo=wita)
    start_utc = start_of_day.astimezone(timezone.utc)
    end_utc = end_of_day.astimezone(timezone.utc)

    orders = (
        db.query(Order)
        .options(
            joinedload(Order.items).joinedload(OrderItem.product),
            joinedload(Order.customer),
            joinedload(Order.sales),
        )
        .filter(
            Order.status.in_(statuses),
            Order.created_at >= start_utc,
            Order.created_at < end_utc,
        )
        .order_by(Order.created_at.asc())
        .all()
    )

    wb = Workbook()
    ws = wb.active
    _build_report(orders, ws, f"Laporan {start_date} sd {end_date}")

    buffer = BytesIO()
    wb.save(buffer)
    buffer.seek(0)

    filename = f"laporan-periode-{start_date}-sd-{end_date}.xlsx"
    return StreamingResponse(
        buffer,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )
