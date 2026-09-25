"""Daily order report — Excel export untuk admin & manager."""
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


def _harga_setelah(harga_satuan: int, qty: int, discount_type: str,
                   discount_percent: int, discount_nominal: int) -> int:
    """Hitung harga per-unit setelah diskon. Duplikat dari orders.py agar
    reports.py berdiri sendiri — kalau orders.py refactor nanti bisa di-extract."""
    if (discount_type or "PERCENT").upper() == "NOMINAL":
        nominal = max(0, discount_nominal or 0)
        return max(0, harga_satuan - nominal)
    pct = max(0, min(100, discount_percent or 0))
    return int(harga_satuan * (100 - pct) / 100)


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

    Satu baris per item pesanan. Kolom sesuai requirement PM:
    Kode Barang, Nama Barang, Nama Toko, Jumlah, Kode Toko,
    Harga Awal, Diskon, Harga Final, Sales.
    """
    try:
        target_date = datetime.strptime(date, "%Y-%m-%d").date()
    except ValueError:
        raise HTTPException(status_code=400, detail="Format tanggal harus YYYY-MM-DD")

    statuses = [s.strip().upper() for s in status.split(",") if s.strip()]
    if not statuses:
        statuses = ["APPROVED"]

    # WITA timezone untuk konsistensi dengan sales app
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
    ws.title = f"Laporan {target_date.isoformat()}"

    headers = [
        "Kode Toko",
        "Kode Barang",
        "Nama Toko",
        "Nama Barang",
        "Jumlah",
        "Harga satuan",
        "Harga Total",
        "Diskon",
        "Harga Final",
        "Sales",
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
            nama_barang = product.nama_barang if product else ""
            kode_barang = item.product_id or ""
            harga_per_unit = _harga_setelah(
                harga_satuan,
                item.qty,
                item.discount_type or "PERCENT",
                item.discount_percent or 0,
                item.discount_nominal or 0,
            )
            harga_final = harga_per_unit * item.qty
            diskon_str = (
                f"{item.discount_percent}%"
                if (item.discount_type or "PERCENT") == "PERCENT"
                else f"Rp {item.discount_nominal or 0}"
            )
            ws.append([
                customer.kode if customer else "",
                kode_barang,
                customer.nama_toko if customer else "",
                nama_barang,
                item.qty,
                harga_satuan,
                harga_satuan * item.qty,
                diskon_str,
                harga_final,
                sales_name,
            ])
            total_rows += 1

    # Footer summary
    ws.append([])  # empty row
    total_row = ws.max_row + 1
    ws.cell(row=total_row, column=1, value=f"Total baris: {total_rows}").font = Font(bold=True)

    # Auto-width columns (capped supaya tidak terlalu lebar)
    widths = [14, 16, 28, 32, 8, 14, 14, 16, 14, 24]
    for i, w in enumerate(widths, 1):
        ws.column_dimensions[get_column_letter(i)].width = w

    buffer = BytesIO()
    wb.save(buffer)
    buffer.seek(0)

    filename = f"laporan-harian-{target_date.isoformat()}.xlsx"
    return StreamingResponse(
        buffer,
        media_type="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )
