"""Generate the legacy .xls fixture used by the parser tests.

Dev-only helper (requires xlwt, not a runtime dependency):

    python tests/fixtures/make_sample_sales_xls.py

The generated ``sample_sales.xls`` is committed so the test suite does not
need xlwt installed.
"""
from datetime import datetime
from pathlib import Path

import xlwt

HEADERS = [
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

ROWS = [
    [
        datetime(2026, 1, 15), "BANJARMASIN", "C001", "Toko A", "P001",
        "Produk A", 2, "pcs", 10000, 20000, 0, 0, 0, 1000, 0,
        19000, "REGULER", "Budi", "Supplier A",
    ],
    [
        datetime(2026, 1, 16), "BANJARMASIN", "C002", "Toko B", "P002",
        "Produk B", 1, "pcs", 15000, 15000, 0, 0, 0, 0, 0,
        15000, "REGULER", "Budi", "Supplier A",
    ],
]


def main() -> None:
    wb = xlwt.Workbook()
    ws = wb.add_sheet("Penjualan")
    date_style = xlwt.easyxf(num_format_str="YYYY-MM-DD")

    for col, header in enumerate(HEADERS):
        ws.write(0, col, header)

    for row_idx, row in enumerate(ROWS, start=1):
        for col, value in enumerate(row):
            if isinstance(value, datetime):
                ws.write(row_idx, col, value, date_style)
            else:
                ws.write(row_idx, col, value)

    target = Path(__file__).with_name("sample_sales.xls")
    wb.save(str(target))
    print(f"WROTE {target}")


if __name__ == "__main__":
    main()
