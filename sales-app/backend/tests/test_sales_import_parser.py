"""Unit tests for the sales-import Excel parser (no DB required)."""
from datetime import date
from io import BytesIO

from openpyxl import Workbook

from app.services.sales_import_service import (
    _read_sales_excel,
    _resolve_columns,
    _resolve_row_branch,
    _to_date,
    _to_int,
)


def _workbook_bytes(rows, headers):
    wb = Workbook()
    ws = wb.active
    ws.append(headers)
    for row in rows:
        ws.append(row)
    buf = BytesIO()
    wb.save(buf)
    return buf.getvalue()


def test_to_date_accepts_common_formats():
    assert _to_date("2026-01-15") == date(2026, 1, 15)
    assert _to_date("2026-01-15 00:00:00") == date(2026, 1, 15)
    assert _to_date("15-Jan-2026") == date(2026, 1, 15)
    assert _to_date("15 Januari 2026") == date(2026, 1, 15)
    assert _to_date("15/01/2026") == date(2026, 1, 15)
    assert _to_date(46037) == date(2026, 1, 15)


def test_to_int_handles_currency_and_separators():
    assert _to_int("1.234.567") == 1234567
    assert _to_int("Rp 1.234") == 1234
    assert _to_int("1,234") == 1234
    assert _to_int("12,5") == 12
    assert _to_int("(500)") == -500
    assert _to_int(None) is None


def test_resolve_columns_prefers_specific_app_report_columns():
    headers = [
        "tanggal",
        "kode pelanggan",
        "kode item",
        "qty",
        "total harga sebelum diskon",
        "diskon layer 1",
        "total diskon",
        "total harga setelah diskon",
        "nama sales",
    ]
    col = _resolve_columns(headers)
    assert col["sale_date"] == 0
    assert col["customer_kode"] == 1
    assert col["product_kode"] == 2
    assert col["qty"] == 3
    # Must not map the gross column or a discount layer.
    assert col["total_amount"] == 7
    assert col["diskon"] == 6
    assert col["sales_nama"] == 8


def test_resolve_row_branch_normalizes_codes_and_labels():
    assert _resolve_row_branch(None) is None
    assert _resolve_row_branch("") is None
    assert _resolve_row_branch("BANJARMASIN") == "BANJARMASIN"
    assert _resolve_row_branch(" banjarmasin ") == "BANJARMASIN"
    assert _resolve_row_branch("Cabang Banjarmasin") == "BANJARMASIN"
    # Unknown values are kept (uppercased) rather than dropped.
    assert _resolve_row_branch("kandangan") == "KANDANGAN"


def test_read_app_report_format():
    headers = [
        "Tanggal",
        "Cabang",
        "Kode Pelanggan",
        "Nama Pelanggan",
        "Kode Item",
        "Nama Item",
        "Qty",
        "Satuan",
        "Harga Satuan",
        "Total Harga Sebelum Diskon",
        "Diskon Layer 1",
        "Diskon Layer 2",
        "Diskon Layer 3",
        "Total Diskon",
        "Up Price",
        "Total Harga Setelah Diskon",
        "Tipe Order",
        "Nama Sales",
        "Supplier",
    ]
    content = _workbook_bytes(
        [[
            "2026-01-15", "BANJARMASIN", "C001", "Toko A", "P001",
            "Produk A", 2, "pcs", 10000, 20000, 0, 0, 0, 1000, 0,
            19000, "REGULER", "Budi", "Supplier A",
        ]],
        headers,
    )
    row = _read_sales_excel(content)[0]
    assert row["sale_date"] == "2026-01-15"
    assert row["customer_kode"] == "C001"
    assert row["product_kode"] == "P001"
    assert row["qty"] == 2
    assert row["diskon"] == 1000
    assert row["net_per_unit"] == 10000
    assert row["total_amount"] == 19000
    assert row["sales_nama"] == "Budi"


def test_read_main_template_format_with_preamble():
    wb = Workbook()
    ws = wb.active
    ws.append(["Laporan Penjualan"])
    ws.append(["Periode", "Januari 2026"])
    ws.append([
        "Trans No", "Penjualan", "Kode", "Nama Pelanggan", "Channel",
        "Kategori", "Group", "Area", "Alamat", "Kode Item", "Nama Item",
        "Qty", "Satuan Jual", "Qtyi", "Satuani", "Diskon",
        "N. Jual - Discount", "Total Hela Harga Jual", "Kode Sales",
        "Sales", "Supplier",
    ])
    ws.append([
        "T1", "2026-01-15", "C001", "Toko A", "GROSIR", "K1", "G1",
        "AREA1", "Jl", "P001", "Produk A", 2, "pcs", 24, "pcs", 1000,
        9500, 19000, "S1", "Budi", "Supplier A",
    ])
    buf = BytesIO()
    wb.save(buf)

    row = _read_sales_excel(buf.getvalue())[0]
    assert row["trans_no"] == "T1"
    assert row["customer_kode"] == "C001"
    assert row["product_kode"] == "P001"
    assert row["qtyi"] == 24
    assert row["net_per_unit"] == 9500
    assert row["total_amount"] == 19000
    assert row["sales_kode"] == "S1"
