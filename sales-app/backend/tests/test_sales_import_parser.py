"""Unit tests for the sales-import Excel parser (no DB required)."""
from datetime import date, datetime
from io import BytesIO
from pathlib import Path

from openpyxl import Workbook

from app.services.sales_import_service import (
    _detect_excel_format,
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


def test_to_date_accepts_more_excel_export_variants():
    # Dates stored as text (not real Excel date cells).
    assert _to_date("46037") == date(2026, 1, 15)
    assert _to_date("2026.09.03") == date(2026, 9, 3)
    assert _to_date("03-Sep-26") == date(2026, 9, 3)
    assert _to_date("03 Sep 26") == date(2026, 9, 3)
    assert _to_date("'2026-09-03'") == date(2026, 9, 3)
    assert _to_date("2026-09-03T00:00:00.000Z") == date(2026, 9, 3)


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


def test_detect_excel_format_uses_magic_bytes_then_filename():
    xlsx = _workbook_bytes([], ["Tanggal"])
    assert _detect_excel_format(xlsx) == "xlsx"

    xls = (Path(__file__).parent / "fixtures" / "sample_sales.xls").read_bytes()
    assert _detect_excel_format(xls) == "xls"

    # Unknown content falls back to the filename so the error stays readable.
    assert _detect_excel_format(b"not-excel", "laporan.xls") == "xls"
    assert _detect_excel_format(b"not-excel", "laporan.XLSX") == "xlsx"


def test_read_legacy_xls_format():
    content = (Path(__file__).parent / "fixtures" / "sample_sales.xls").read_bytes()

    rows = _read_sales_excel(content, "sample_sales.xls")
    assert len(rows) == 2

    first = rows[0]
    assert _to_date(first["sale_date"]) == date(2026, 1, 15)
    assert first["customer_kode"] == "C001"
    assert first["product_kode"] == "P001"
    assert _to_int(first["qty"]) == 2
    assert _to_int(first["diskon"]) == 1000
    assert _to_int(first["net_per_unit"]) == 10000
    assert _to_int(first["total_amount"]) == 19000
    assert first["sales_nama"] == "Budi"

    second = rows[1]
    assert _to_date(second["sale_date"]) == date(2026, 1, 16)
    assert _to_int(second["total_amount"]) == 15000


def test_read_dates_stored_as_text_with_leading_apostrophe():
    """ERP exports often store dates as text with Excel's quote prefix.

    Excel hides the apostrophe and shows "2026-09-03", but the cell value is
    literally "'2026-09-03". This was the real-world import failure.
    """
    headers = [
        "Tanggal", "Kode Item", "Nama Item", "Qty",
        "Total Harga Setelah Diskon",
    ]
    content = _workbook_bytes(
        [["'2026-09-03", "P001", "Produk A", 2, 20000]],
        headers,
    )
    row = _read_sales_excel(content)[0]
    assert _to_date(row["sale_date"]) == date(2026, 9, 3)


def test_read_header_beyond_first_15_rows():
    """Accounting exports often have a long preamble before the header."""
    wb = Workbook()
    ws = wb.active
    for i in range(25):
        ws.append([f"Info laporan {i}"])
    ws.append([
        "Tanggal", "Kode Item", "Nama Item", "Qty",
        "Total Harga Setelah Diskon",
    ])
    ws.append([datetime(2026, 9, 3), "P001", "Produk A", 2, 20000])
    buf = BytesIO()
    wb.save(buf)

    rows = _read_sales_excel(buf.getvalue())
    assert len(rows) == 1
    assert _to_date(rows[0]["sale_date"]) == date(2026, 9, 3)
    assert rows[0]["product_kode"] == "P001"
    assert _to_int(rows[0]["qty"]) == 2
    assert _to_int(rows[0]["total_amount"]) == 20000


def test_read_uses_sheet_that_contains_the_header():
    """A cover sheet before the data sheet must not break the import."""
    wb = Workbook()
    cover = wb.active
    cover.title = "Info"
    cover.append(["Laporan Penjualan"])
    cover.append(["Dicetak oleh", "Admin"])

    data = wb.create_sheet("Penjualan")
    data.append([
        "Tanggal", "Kode Item", "Nama Item", "Qty",
        "Total Harga Setelah Diskon",
    ])
    data.append([datetime(2026, 9, 3), "P001", "Produk A", 2, 20000])
    buf = BytesIO()
    wb.save(buf)

    rows = _read_sales_excel(buf.getvalue())
    assert len(rows) == 1
    assert _to_date(rows[0]["sale_date"]) == date(2026, 9, 3)
    assert rows[0]["product_kode"] == "P001"


def test_infers_date_column_when_header_is_blank():
    """Merged/two-row headers can leave the date column without a title."""
    wb = Workbook()
    ws = wb.active
    ws.append([
        None, "Kode Item", "Nama Item", "Qty",
        "Total Harga Setelah Diskon",
    ])
    ws.append([datetime(2026, 9, 3), "P001", "Produk A", 2, 20000])
    ws.append([datetime(2026, 9, 4), "P002", "Produk B", 1, 15000])
    buf = BytesIO()
    wb.save(buf)

    rows = _read_sales_excel(buf.getvalue())
    assert len(rows) == 2
    assert _to_date(rows[0]["sale_date"]) == date(2026, 9, 3)
    assert _to_date(rows[1]["sale_date"]) == date(2026, 9, 4)
    # The qty column must not be mistaken for dates.
    assert _to_int(rows[0]["qty"]) == 2


def test_infers_date_column_for_two_row_header():
    wb = Workbook()
    ws = wb.active
    ws.append(["Tanggal", None, None, None, None])
    ws.append([
        None, "Kode Item", "Nama Item", "Qty",
        "Total Harga Setelah Diskon",
    ])
    ws.append([datetime(2026, 9, 3), "P001", "Produk A", 2, 20000])
    buf = BytesIO()
    wb.save(buf)

    rows = _read_sales_excel(buf.getvalue())
    assert len(rows) == 1
    assert _to_date(rows[0]["sale_date"]) == date(2026, 9, 3)
    assert rows[0]["product_kode"] == "P001"
