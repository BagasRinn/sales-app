"""Dump the structure of a sales Excel file for import diagnostics.

Usage (from ``sales-app/backend``)::

    python scripts/inspect_excel.py "C:\\path\\laporan.xls"

It prints every sheet, the first rows (with cell types), the detected header
row, and the resulting column mapping. Use this when an import fails with
"Header laporan penjualan tidak ditemukan" or "Tanggal penjualan tidak valid".
"""
from __future__ import annotations

import sys
from pathlib import Path

from app.services.sales_import_service import (
    _detect_excel_format,
    _find_header_row_index,
    _norm_header,
    _read_xls_matrices,
    _read_xlsx_matrices,
    _resolve_columns,
    _score_header_row,
    _to_date,
)


def _describe(value) -> str:
    text = "" if value is None else str(value)
    text = text.replace("\n", "\\n")
    if len(text) > 40:
        text = text[:37] + "..."
    return f"{type(value).__name__}:{text!r}"


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2

    path = Path(sys.argv[1])
    if not path.is_file():
        print(f"File not found: {path}")
        return 2

    raw = path.read_bytes()
    fmt = _detect_excel_format(raw, path.name)
    print(f"File      : {path}")
    print(f"Size      : {len(raw):,} bytes")
    print(f"Format    : {fmt}")

    matrices = _read_xlsx_matrices(raw) if fmt == "xlsx" else _read_xls_matrices(raw)
    print(f"Sheets    : {[name for name, _ in matrices]}")

    for sheet_name, matrix in matrices:
        print()
        print(f"=== Sheet {sheet_name!r} — {len(matrix)} rows ===")
        for row_idx, row in enumerate(matrix[:12]):
            cells = " | ".join(_describe(c) for c in row)
            print(f"  row {row_idx + 1:>3}: {cells[:400]}")

        try:
            header_idx = _find_header_row_index(matrix)
        except ValueError as exc:
            print(f"  HEADER    : NOT FOUND ({exc})")
            continue

        headers = [_norm_header(c) for c in matrix[header_idx]]
        score, fields = _score_header_row(matrix[header_idx])
        print(f"  HEADER    : row {header_idx + 1} (score {score})")
        print(f"  FIELDS    : {fields}")
        print(f"  COLUMNS   : {_resolve_columns(headers)}")

        sample_rows = matrix[header_idx + 1: header_idx + 4]
        for row_idx, row in enumerate(sample_rows, start=header_idx + 2):
            print(f"  sample {row_idx:>3}: " + " | ".join(_describe(c) for c in row)[:400])
            date_col = fields.get("sale_date")
            if date_col is not None and date_col < len(row):
                print(
                    f"           sale_date -> {row[date_col]!r} "
                    f"parsed={_to_date(row[date_col])}"
                )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
