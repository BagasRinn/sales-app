"""Import laporan penjualan dari file Excel (.xlsx atau .xls).

Mendukung dua bentuk file:

1. Template sistem utama — kolom: Trans No, Penjualan (tanggal), Kode
   (customer), Nama Pelanggan, Channel, Kategori, Group, Area, Alamat,
   Kode Item, Nama Item, Qty, Satuan Jual, Qtyi, Satuani, Diskon,
   N. Jual - Discount, Total Hela Harga Jual, Kode Sales, Sales, Supplier.
2. Laporan bawaan aplikasi (reports.py) — kolom: Tanggal, Cabang,
   Kode Pelanggan, Nama Pelanggan, Kode Item, Nama Item, Qty, Satuan,
   Harga Satuan, Total Harga Sebelum Diskon, Diskon Layer 1..3,
   Total Diskon, Up Price, Total Harga Setelah Diskon, Tipe Order,
   Nama Sales, Supplier.

Semua field keuangan disimpan apa adanya dari file: `net_per_unit` (harga
per satuan setelah diskon) dan `total_amount` (total akhir baris). Kolom
`TOTAL` selalu diprioritaskan sebagai `total_amount` karena itu total baris
final pada ekspor sistem utama (termasuk `PPN Head`); bila kolom itu tidak ada,
dipakai kolom total lain seperti `Total Harga Jual` / `Total Harga Setelah
Diskon`.

Import bersifat **idempotent**: setiap baris punya `dedupe_key` deterministik
(lihat ``sales_import_keys``), jadi file yang sama boleh di-import ulang tanpa
menggandakan data. Baris yang isinya berubah akan di-update, baris identik
hanya dihitung sebagai ``updated`` tanpa menulis ulang. Versi ringkasan dan
snapshot precomputed hanya di-refresh untuk ``(branch, month)`` yang benar-
benar berubah, dan semuanya dalam transaksi yang sama dengan baris data —
import gagal tidak pernah mengubah versi maupun snapshot.
"""
import logging
import re
from dataclasses import dataclass
from datetime import date, datetime, timedelta
from io import BytesIO
from itertools import islice
from pathlib import Path
from typing import Any, Callable, Dict, Iterable, Iterator, List, Optional, Set, Tuple, Union

from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.core.branch import get_branch_nama, get_valid_branch_codes
from app.core.security import is_global_manager
from app.models.models import ImportLog, SyncValidationError
from app.services.sales_import_upsert import SalesRow, upsert_sales_rows
from app.services.sales_import_versions import (
    GLOBAL_SCOPE,
    bump_versions_for_changes,
    parse_month,
)
from app.services.sales_summary_service import recompute_summary
from app.services.import_progress import ImportProgressReporter

logger = logging.getLogger(__name__)

try:
    import openpyxl
    OPENPYXL_AVAILABLE = True
except ImportError:
    OPENPYXL_AVAILABLE = False

try:
    import xlrd
    XLRD_AVAILABLE = True
except ImportError:
    XLRD_AVAILABLE = False

# Excel file signatures. Detecting by content (not just the extension) keeps
# renamed/corrupt files from being parsed by the wrong reader.
_XLSX_MAGIC = b"PK\x03\x04"  # ZIP container
_XLS_MAGIC = b"\xd0\xcf\x11\xe0\xa1\xb1\x1a\xe1"  # OLE2 compound document

IMPORT_TYPE_SALES = "SALES"

# Cap stored row-level errors so a fully malformed 10k-row file does not
# create 10k validation rows (DB egress + storage). The skipped count still
# reflects every rejected row.
MAX_ROW_ERRORS = 50


def _norm_header(value: Any) -> str:
    """Normalize header cell: lowercase, non-alnum -> space, collapse space."""
    if value is None:
        return ""
    s = str(value).replace("\ufeff", "").strip().lower()
    s = s.replace("%", " persen ")
    s = re.sub(r"[^a-z0-9]+", " ", s)
    return " ".join(s.split())


# Canonical field -> accepted normalized aliases.
# More specific aliases are intentionally listed first; matching below scores
# exact matches higher than prefix matches and longer aliases higher than
# shorter ones, so "Kode Item" never steals "Kode Pelanggan".
SALES_FIELD_ALIASES: Dict[str, List[str]] = {
    "trans_no": [
        "trans no", "transno", "no transaksi", "nomor transaksi",
        "trans penjualan", "transaksi", "transaction", "no invoice",
        "invoice",
    ],
    "sale_date": [
        "tanggal retur", "tgl retur", "tanggal penjualan", "tanggal order",
        "retur", "penjualan", "tanggal",
        "tgl", "tarikh", "order date", "created date", "date", "created",
    ],
    "customer_kode": [
        "kode pelanggan", "kodecustomer", "kode customer", "customer kode",
        "kode",
    ],
    "customer_nama": [
        "nama pelanggan", "namapelanggan", "nama pelanggan toko",
        "nama toko", "customer", "namacustomer",
    ],
    "channel": [
        "channel", "tipe langganan", "tipelangganan", "langganan",
        "subscription", "tipe pelanggan",
    ],
    "branch": ["kode cabang", "cabang", "branch"],
    "kategori": ["kategori", "category"],
    "customer_group": ["group", "grup", "grouping"],
    "area": ["area rayon", "kode area", "areacustomer", "area", "rayon", "wilayah"],
    "alamat": ["alamat pelanggan", "alamat toko", "alamat", "address"],
    "product_kode": [
        "kode item", "kodeitem", "item kode", "kode barang", "kodeproduk",
        "itemcode", "sku",
    ],
    "product_nama": [
        "nama item", "namaitem", "item name", "nama barang", "namaproduk",
        "itemname",
    ],
    "qty": ["qty sold", "jumlah terjual", "quantity", "jumlah", "qty"],
    "satuan_jual": [
        "satuan jual", "satuanjual", "selling unit", "satuan", "jual",
    ],
    "qtyi": ["qtyi", "qty in", "qtyin", "base qty", "qty base"],
    "satuani": ["satuani", "satuan i", "satuanin", "unit i", "base unit", "satuanbase"],
    "diskon": [
        "total diskon", "total discount", "diskon total", "diskon",
        "discount",
    ],
    "net_per_unit": [
        "n jual discount", "njual discount", "jual discount",
        "net jual discount", "net jual", "n jual", "harga satuan",
        "harga jual", "harga",
    ],
    "total_amount": [
        "total harga setelah diskon", "total harga sesudah diskon",
        "total setelah diskon", "total hela harga jual", "total harga jual",
        "total jual", "total penjualan", "total revenue", "total amount",
        "grand total", "total bayar", "total harga", "total",
    ],
    "margin": [
        "margin rupiah", "nilai margin", "margin rp", "margin",
    ],
    "mother_sku": [
        "mother sku", "mothersku", "sku induk", "kode induk", "parent sku",
    ],
    "divisi": ["devisi", "divisi", "division"],
    "sales_kode": ["kode sales", "kodesales", "sales kode", "kode salesman", "salesman kode"],
    "sales_nama": [
        "nama sales", "namasales", "nama salesman", "nama sales man",
        "salesman", "sales",
    ],
    "supplier": ["last supplier", "nama supplier", "namasupplier", "supplier"],
}


def _match_score(header: str, alias: str) -> int:
    """Score how well a normalized header matches an alias.

    Exact match beats prefix match; longer aliases beat shorter ones. Prefix
    matching requires a token boundary (space), so "sales" does not match
    "salesman" unless that alias is listed explicitly.
    """
    if not header or not alias:
        return 0
    if alias == "margin" and header.startswith(
        ("margin persen", "margin percent", "margin percentage")
    ):
        return 0
    if header == alias:
        # A bare "TOTAL" column is the final invoice line total in the main
        # system export (TOTAL = Total Harga Jual + PPN Head). Prefer it over
        # other exact aliases such as "total harga jual" so the imported omzet
        # matches the TOTAL column users see and sum in the source file.
        if alias == "total":
            return 200
        # Guard: app report has separate "Diskon Layer N" columns. The plain
        # "diskon" alias must only win on a real total column.
        return 100 + len(alias)
    if header.startswith(alias + " "):
        if alias == "total" and header.startswith("total ppn"):
            return 0
        if alias == "diskon" and header.startswith("diskon layer"):
            return 0
        if alias == "total harga" and header.startswith("total harga sebelum"):
            return 0
        return 50 + len(alias)
    return 0


def _best_field_for_header(header: str) -> Tuple[Optional[str], int]:
    best_field: Optional[str] = None
    best_score = 0
    for field, aliases in SALES_FIELD_ALIASES.items():
        for alias in aliases:
            score = _match_score(header, alias)
            if score > best_score:
                best_field, best_score = field, score
    return best_field, best_score


def _resolve_field(norm: str) -> Optional[str]:
    field, _ = _best_field_for_header(norm.strip())
    return field


def _resolve_columns(headers: List[str]) -> Dict[str, int]:
    """Map canonical field -> column index using the best header match.

    Each header is assigned to at most one field; each field picks its
    highest-scoring header (ties keep the leftmost column).
    """
    best_per_field: Dict[str, Tuple[int, int]] = {}
    for idx, header in enumerate(headers):
        if not header:
            continue
        field, score = _best_field_for_header(header)
        if field is None:
            continue
        current = best_per_field.get(field)
        if current is None or score > current[0]:
            best_per_field[field] = (score, idx)

    col_map = {field: -1 for field in SALES_FIELD_ALIASES}
    for field, (_, idx) in best_per_field.items():
        col_map[field] = idx
    return col_map


# Exports from accounting/ERP systems often put a company block, filter info,
# and several blank rows before the real header, so scan deeper than a handful
# of lines. 200 rows is still cheap because the matrix is already in memory.
_MAX_HEADER_SCAN_ROWS = 200

# A candidate header row must describe at least two of these three groups:
# date, item identity, and amount. This prevents a data row (which may contain
# words like "Sales" or "Total") from being mistaken for the header.
_HEADER_MIN_STRUCTURAL_GROUPS = 2


def _score_header_row(row: List[Any]) -> Tuple[int, Dict[str, int]]:
    """Score a candidate header row; return ``(score, field -> column)``.

    ``score`` is 0 when the row does not look like a sales header at all.
    """
    norms = [_norm_header(c) for c in row]
    best_per_field: Dict[str, Tuple[int, int]] = {}
    for idx, header in enumerate(norms):
        if not header:
            continue
        field, match = _best_field_for_header(header)
        if field is None:
            continue
        current = best_per_field.get(field)
        if current is None or match > current[0]:
            best_per_field[field] = (match, idx)

    fields = set(best_per_field)
    has_date = "sale_date" in fields
    has_item = bool({"product_kode", "product_nama"} & fields)
    has_amount = bool({"qty", "total_amount"} & fields)
    structural = int(has_date) + int(has_item) + int(has_amount)
    if structural < _HEADER_MIN_STRUCTURAL_GROUPS:
        return 0, {}

    score = (
        len(fields)
        + (5 if has_date else 0)
        + (2 if has_item else 0)
        + (2 if has_amount else 0)
    )
    return score, {field: idx for field, (_, idx) in best_per_field.items()}


def _find_header_row_index(rows: List[List[Any]]) -> int:
    """Cari indeks baris header laporan penjualan (0-based).

    Mendeteksi template utama (`Penjualan`, `Trans No`, ...) maupun laporan
    aplikasi (`Tanggal`, `Kode Item`, `Qty`, ...) tanpa bergantung pada satu
    nama kolom saja. Baris pertama yang cocok penuh (tanggal + item/total)
    langsung dipakai; jika tidak ada, baris dengan skor tertinggi dipilih
    sebagai fallback (mis. header dua tingkat atau kolom tanggal tanpa judul).
    """
    best: Optional[Tuple[int, int]] = None
    for i, row in enumerate(rows[:_MAX_HEADER_SCAN_ROWS]):
        score, fields = _score_header_row(row)
        if score <= 0:
            continue

        has_date = "sale_date" in fields
        has_item = bool({"product_kode", "product_nama"} & set(fields))
        has_amount = bool({"qty", "total_amount"} & set(fields))
        if has_date and (has_item or has_amount):
            return i

        if best is None or score > best[0]:
            best = (score, i)

    if best is not None:
        return best[1]

    raise ValueError(
        "Header laporan penjualan tidak ditemukan di "
        f"{_MAX_HEADER_SCAN_ROWS} baris pertama."
    )


def _detect_excel_format(file_bytes: bytes, file_name: Optional[str] = None) -> str:
    """Return ``"xlsx"`` or ``"xls"`` based on content, then filename."""
    head = file_bytes[:8]
    if head.startswith(_XLSX_MAGIC):
        return "xlsx"
    if head.startswith(_XLS_MAGIC):
        return "xls"

    # Content signature is authoritative, but a truncated/test buffer may not
    # have one. Fall back to the uploaded filename so error messages stay clear.
    lower = (file_name or "").lower()
    if lower.endswith(".xlsx"):
        return "xlsx"
    if lower.endswith(".xls"):
        return "xls"
    raise ValueError("Format file harus .xlsx atau .xls")


def _read_xlsx_matrices(
    file_bytes: bytes,
) -> List[Tuple[str, List[List[Any]]]]:
    if not OPENPYXL_AVAILABLE:
        raise RuntimeError("openpyxl library not installed. Run: pip install openpyxl")
    wb = openpyxl.load_workbook(BytesIO(file_bytes), data_only=True)
    return [
        (ws.title, [list(row) for row in ws.iter_rows(values_only=True)])
        for ws in wb.worksheets
    ]


def _read_xls_matrices(
    file_bytes: bytes,
) -> List[Tuple[str, List[List[Any]]]]:
    if not XLRD_AVAILABLE:
        raise RuntimeError("xlrd library not installed. Run: pip install xlrd")
    book = xlrd.open_workbook(file_contents=file_bytes)
    matrices: List[Tuple[str, List[List[Any]]]] = []
    for sheet in book.sheets():
        matrix: List[List[Any]] = []
        for r in range(sheet.nrows):
            row: List[Any] = []
            for c in range(sheet.ncols):
                cell = sheet.cell(r, c)
                value = cell.value
                if cell.ctype == xlrd.XL_CELL_DATE:
                    # xlrd returns raw serial floats for date-formatted cells.
                    try:
                        row.append(xlrd.xldate_as_datetime(value, book.datemode))
                    except Exception:
                        # Out-of-range/corrupt serial: keep the raw value so the
                        # row is rejected later with a readable message instead
                        # of aborting the whole file.
                        row.append(value)
                elif cell.ctype == xlrd.XL_CELL_BOOLEAN:
                    row.append(bool(value))
                elif cell.ctype in (xlrd.XL_CELL_EMPTY, xlrd.XL_CELL_BLANK):
                    row.append(None)
                elif isinstance(value, str) and not value.strip():
                    row.append(None)
                else:
                    row.append(value)
            matrix.append(row)
        matrices.append((sheet.name, matrix))
    return matrices


def _looks_like_date(value: Any) -> bool:
    """True when a cell value is very likely a date (used only for inference)."""
    if isinstance(value, datetime):
        return True
    if isinstance(value, date):
        return True
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        # Only modern Excel serials: small numbers are quantities/discounts.
        return 20000 <= float(value) <= 60000
    if isinstance(value, str):
        s = value.strip()
        if not s or not re.search(r"\d", s):
            return False
        if re.search(r"\d{1,4}[-/.]\d{1,2}[-/.]\d{1,4}", s):
            return _to_date(s) is not None
        if re.search(r"[a-z]", s.lower()):
            return _to_date(s) is not None
    return False


def _infer_date_column(
    matrix: List[List[Any]],
    header_row_idx: int,
    used_columns: Set[int],
    sample_limit: int = 100,
) -> Optional[int]:
    """Find the date column when its header is blank/unknown.

    Reports sometimes merge the date header across two rows or leave the
    header cell empty, so the values themselves are inspected instead.
    """
    sample = matrix[header_row_idx + 1: header_row_idx + 1 + sample_limit]
    width = max((len(row) for row in sample), default=0)
    best_col: Optional[int] = None
    best_ratio = 0.0
    best_hits = 0
    for col in range(width):
        if col in used_columns:
            continue
        hits = 0
        nonempty = 0
        for row in sample:
            if col >= len(row):
                continue
            value = row[col]
            if value is None or (isinstance(value, str) and not value.strip()):
                continue
            nonempty += 1
            if _looks_like_date(value):
                hits += 1
        if nonempty == 0 or hits == 0:
            continue
        ratio = hits / nonempty
        if ratio < 0.8:
            continue
        if (ratio, hits) > (best_ratio, best_hits):
            best_col, best_ratio, best_hits = col, ratio, hits
    return best_col


def _preview_sheet(matrix: List[List[Any]], limit: int = 5) -> str:
    lines: List[str] = []
    for row in matrix[:limit]:
        cells = [str(c).strip() for c in row if c is not None and str(c).strip()]
        if cells:
            lines.append(" | ".join(cells)[:120])
    return " / ".join(lines)


def _build_header_error(
    matrices: List[Tuple[str, List[List[Any]]]],
    excel_format: str,
) -> str:
    parts = [
        "Header laporan penjualan tidak ditemukan "
        f"({excel_format.upper()})."
    ]
    for sheet_name, matrix in matrices[:3]:
        preview = _preview_sheet(matrix)
        if preview:
            parts.append(f"Sheet '{sheet_name}': {preview}")
    return " ".join(parts)[:900]


def _read_sales_excel(
    file_bytes: bytes, file_name: Optional[str] = None
) -> List[Dict[str, Any]]:
    """Parse file .xlsx/.xls laporan penjualan ke list of row dicts.

    Semua sheet diperiksa: file ekspor kadang menaruh data di sheet kedua atau
    ketiga. Sheet dengan header paling meyakinkan dan baris data terbanyak
    dipakai.
    """
    excel_format = _detect_excel_format(file_bytes, file_name)
    matrices = (
        _read_xlsx_matrices(file_bytes)
        if excel_format == "xlsx"
        else _read_xls_matrices(file_bytes)
    )

    candidates: List[Tuple[int, int, str, List[List[Any]], int]] = []
    for sheet_name, matrix in matrices:
        if not matrix:
            continue
        try:
            header_row_idx = _find_header_row_index(matrix)
        except ValueError:
            continue

        data_rows = sum(
            1
            for row in matrix[header_row_idx + 1:]
            if any(c is not None and str(c).strip() for c in row)
        )
        if data_rows == 0:
            continue
        score, _ = _score_header_row(matrix[header_row_idx])
        candidates.append((score, data_rows, sheet_name, matrix, header_row_idx))

    if not candidates:
        raise ValueError(_build_header_error(matrices, excel_format))

    candidates.sort(key=lambda item: (item[0], item[1]), reverse=True)
    _, _, sheet_name, matrix, header_row_idx = candidates[0]

    headers = [_norm_header(c) for c in matrix[header_row_idx]]
    col_map = _resolve_columns(headers)
    key_mode = _template_key_mode(headers, col_map)

    # Fallback: header exists but the date column name is missing/unknown.
    if col_map.get("sale_date", -1) < 0:
        used = {idx for idx in col_map.values() if idx >= 0}
        inferred = _infer_date_column(matrix, header_row_idx, used)
        if inferred is not None:
            col_map["sale_date"] = inferred
            logger.info(
                "[SALES-IMPORT] inferred sale_date column from values: %s",
                inferred,
            )

    rows: List[Dict[str, Any]] = []
    for row in matrix[header_row_idx + 1:]:
        if all(
            cell is None or (isinstance(cell, str) and not cell.strip())
            for cell in row
        ):
            continue
        row_dict: Dict[str, Any] = {}
        for field, idx in col_map.items():
            row_dict[field] = row[idx] if 0 <= idx < len(row) else None
        row_dict["key_mode"] = key_mode
        rows.append(row_dict)

    logger.info(
        "[SALES-IMPORT] format=%s sheet=%s header_row=%s headers resolved: %s",
        excel_format,
        sheet_name,
        header_row_idx + 1,
        col_map,
    )
    return rows


def _is_v2_template(col_map: Dict[str, int]) -> bool:
    return (
        col_map.get("margin", -1) >= 0
        and (
            col_map.get("mother_sku", -1) >= 0
            or col_map.get("devisi", -1) >= 0
        )
        and col_map.get("qty", -1) < 0
    )


def _is_return_template(headers: List[str], col_map: Dict[str, int]) -> bool:
    has_return_date = any(
        header in {"tanggal retur", "tgl retur", "retur"}
        for header in headers
    )
    return (
        has_return_date
        and col_map.get("margin", -1) >= 0
        and col_map.get("product_kode", -1) >= 0
        and col_map.get("qty", -1) < 0
    )


def _template_key_mode(
    headers: List[str], col_map: Dict[str, int]
) -> Optional[str]:
    if _is_return_template(headers, col_map):
        return "return"
    return "v2" if _is_v2_template(col_map) else None


def _iter_sales_excel(
    source: Union[bytes, str, Path],
    file_name: Optional[str] = None,
    on_total: Optional[Callable[[int], None]] = None,
) -> Iterator[Tuple[int, Dict[str, Any]]]:
    """Yield parsed rows without retaining an entire .xlsx workbook in memory."""
    is_path = isinstance(source, (str, Path))
    path = Path(source) if is_path else None
    if path is not None:
        with path.open("rb") as stream:
            signature = stream.read(8)
        excel_format = (
            "xlsx" if signature.startswith(_XLSX_MAGIC)
            else "xls" if signature.startswith(_XLS_MAGIC)
            else _detect_excel_format(b"", file_name or path.name)
        )
    else:
        if not isinstance(source, bytes):
            raise TypeError("source must be bytes or a file path")
        excel_format = _detect_excel_format(source, file_name)

    if excel_format == "xls":
        content = path.read_bytes() if path is not None else source
        if len(content) > 20 * 1024 * 1024:
            raise ValueError("File .xls lebih dari 20 MB; simpan ulang sebagai .xlsx")
        parsed_rows = _read_sales_excel(content, file_name)
        if on_total is not None:
            on_total(len(parsed_rows))
        for row_number, row in enumerate(
            parsed_rows, start=2
        ):
            yield row_number, row
        return

    if not OPENPYXL_AVAILABLE:
        raise RuntimeError("openpyxl library not installed. Run: pip install openpyxl")

    workbook_source = str(path) if path is not None else BytesIO(source)
    workbook = openpyxl.load_workbook(
        workbook_source, read_only=True, data_only=True
    )
    try:
        candidates = []
        for worksheet in workbook.worksheets:
            preview = [
                list(row)
                for row in islice(
                    worksheet.iter_rows(values_only=True),
                    _MAX_HEADER_SCAN_ROWS,
                )
            ]
            try:
                header_row_index = _find_header_row_index(preview)
            except ValueError:
                continue
            score, col_map = _score_header_row(preview[header_row_index])
            candidates.append(
                (score, worksheet, preview, header_row_index, col_map)
            )

        if not candidates:
            raise ValueError(
                "Header laporan penjualan tidak ditemukan di "
                f"{_MAX_HEADER_SCAN_ROWS} baris pertama."
            )

        _, worksheet, preview, header_row_index, col_map = max(
            candidates, key=lambda candidate: candidate[0]
        )
        headers = [_norm_header(cell) for cell in preview[header_row_index]]
        key_mode = _template_key_mode(headers, col_map)
        if col_map.get("sale_date", -1) < 0:
            sample = list(
                islice(
                    worksheet.iter_rows(
                        min_row=header_row_index + 2,
                        max_row=header_row_index + 101,
                        values_only=True,
                    ),
                    100,
                )
            )
            used = {idx for idx in col_map.values() if idx >= 0}
            inferred = _infer_date_column(
                [list(row) for row in sample], -1, used
            )
            if inferred is not None:
                col_map["sale_date"] = inferred

        if on_total is not None:
            on_total(max(0, (worksheet.max_row or 0) - header_row_index - 1))

        for row_number, values in enumerate(
            worksheet.iter_rows(values_only=True), start=1
        ):
            if row_number <= header_row_index + 1:
                continue
            row = list(values)
            if all(
                cell is None or (isinstance(cell, str) and not cell.strip())
                for cell in row
            ):
                continue
            row_dict = {
                field: row[index] if 0 <= index < len(row) else None
                for field, index in col_map.items()
            }
            row_dict["key_mode"] = key_mode
            yield row_number, row_dict
    finally:
        workbook.close()


def _to_int(value: Any) -> Optional[int]:
    """Parse integers from Excel cells, including "1.234.567" and "Rp 1.234"."""
    if value is None:
        return None
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return int(value)

    s = str(value).strip()
    if not s:
        return None
    negative = s.startswith("(") and s.endswith(")")
    s = s.strip("()")
    s = re.sub(r"(?i)rp\.?", "", s)
    s = s.replace(" ", "").replace("\u00a0", "")
    if not s:
        return None

    if "." in s and "," in s:
        # Whichever separator comes last is the decimal separator.
        if s.rfind(",") > s.rfind("."):
            s = s.replace(".", "").replace(",", ".")
        else:
            s = s.replace(",", "")
    elif s.count(".") > 1:
        s = s.replace(".", "")
    elif s.count(",") > 1:
        s = s.replace(",", "")
    elif "." in s:
        # Single dot: 3 trailing digits means Indonesian thousands separator
        # ("1.234"), otherwise a decimal point ("1.5").
        decimals = len(s) - s.rfind(".") - 1
        if decimals == 3 and len(s) > 4:
            s = s.replace(".", "")
    elif "," in s:
        # Single comma: decimal if 1-2 trailing digits, else thousands.
        decimals = len(s) - s.rfind(",") - 1
        s = s.replace(",", "." if 1 <= decimals <= 2 else "")

    try:
        result = int(float(s))
    except (ValueError, TypeError):
        return None
    return -result if negative else result


_INDONESIAN_MONTHS = {
    "januari": "january",
    "februari": "february",
    "maret": "march",
    "mei": "may",
    "juni": "june",
    "juli": "july",
    "agustus": "august",
    "oktober": "october",
    "desember": "december",
    "agt": "aug",
    "agu": "aug",
    "okt": "oct",
    "des": "dec",
}

_EXCEL_EPOCH = date(1899, 12, 30)


def _to_date(value: Any) -> Optional[date]:
    """Parse dates from datetime/date cells, Excel serials, and text.

    Supports ISO datetimes ("2026-01-15 00:00:00"), "15-Jan-2026",
    "15 Januari 2026", "15/01/2026", and raw Excel serial numbers.
    """
    if value is None:
        return None
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, date):
        return value
    if isinstance(value, (int, float)) and not isinstance(value, bool):
        # Excel serial date (1900 date system). Keep a sane range so random
        # numeric values in a date column are not silently treated as dates.
        if 1 <= float(value) <= 60000:
            return _EXCEL_EPOCH + timedelta(days=int(value))
        return None

    s = str(value).strip().strip("'\"").strip()
    if not s:
        return None

    # ISO datetime (also handles a trailing Z / offset).
    try:
        return datetime.fromisoformat(s.replace("Z", "+00:00")).date()
    except ValueError:
        pass

    # Numeric text that is really an Excel serial (e.g. "46037").
    if re.fullmatch(r"\d{5}(?:\.0+)?", s):
        serial = float(s)
        if 20000 <= serial <= 60000:
            return _EXCEL_EPOCH + timedelta(days=int(serial))

    # Indonesian month names -> English, then retry common text formats.
    normalized = s.lower()
    for indo, english in _INDONESIAN_MONTHS.items():
        normalized = re.sub(rf"\b{indo}\b", english, normalized)

    formats = (
        "%Y-%m-%d",
        "%Y/%m/%d",
        "%Y.%m.%d",
        "%Y%m%d",
        "%d/%m/%Y",
        "%m/%d/%Y",
        "%d-%m-%Y",
        "%d.%m.%Y",
        "%d-%b-%Y",
        "%d %b %Y",
        "%d-%B-%Y",
        "%d %B %Y",
        "%b %d, %Y",
        "%B %d, %Y",
        # Two-digit years, only after the unambiguous four-digit formats.
        "%d-%b-%y",
        "%d %b %y",
        "%d-%B-%y",
        "%d %B %y",
        "%d/%m/%y",
        "%m/%d/%y",
        "%d-%m-%y",
    )
    for candidate in (normalized, normalized.split(" ")[0] if " " in normalized else ""):
        if not candidate:
            continue
        for fmt in formats:
            try:
                return datetime.strptime(candidate, fmt).date()
            except ValueError:
                continue

    return None


def _clean_str(value: Any) -> Optional[str]:
    if value is None:
        return None
    s = str(value).strip()
    return s if s else None


def _resolve_row_branch(value: Any) -> Optional[str]:
    """Resolve a ``Cabang`` cell to a branch code.

    Accepts a raw code (``BANJARMASIN``), any casing, a label
    (``Cabang Banjarmasin``), or an empty cell (returns ``None``).
    Unknown values are returned uppercased so the row is not silently
    mis-attributed; such rows stay visible only to global MANAGER.
    """
    raw = _clean_str(value)
    if not raw:
        return None

    candidate = " ".join(raw.upper().split())
    if candidate.startswith("CABANG "):
        candidate = candidate[len("CABANG "):].strip()

    codes = get_valid_branch_codes()
    if candidate in codes:
        return candidate

    # Label match, e.g. "Cabang Banjarmasin" -> BANJARMASIN.
    for code in codes:
        label = " ".join((get_branch_nama(code) or "").upper().split())
        if label and label == " ".join(raw.upper().split()):
            return code

    # Unknown branch: keep a bounded value so the DB insert cannot fail.
    return candidate[:20]


def _add_error(
    errors: List[Dict[str, Any]],
    row_num: int,
    row: Dict[str, Any],
    reason: str,
) -> None:
    if len(errors) >= MAX_ROW_ERRORS:
        return
    errors.append(
        {
            "row": row_num,
            "sku": _clean_str(row.get("product_kode")) or "",
            "reason": reason[:255],
        }
    )


def import_sales_from_excel(
    file_bytes: Union[bytes, str, Path],
    db: Session,
    current_user: Dict[str, Any],
    file_name: str,
    progress: Optional[ImportProgressReporter] = None,
) -> Dict[str, Any]:
    """Import baris laporan penjualan dari file Excel → tabel imported_sales."""
    global_manager = is_global_manager(current_user)
    account_branch = current_user.get("branch") or None
    if not global_manager and not account_branch:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Akun Anda belum memiliki cabang. Hubungi manager.",
        )

    import_log = ImportLog(
        user_id=current_user.get("user_id"),
        nama=current_user.get("nama"),
        import_type=IMPORT_TYPE_SALES,
        file_name=file_name,
        branch=current_user.get("branch"),
    )
    db.add(import_log)
    db.flush()

    validation_errors: List[Dict[str, Any]] = []
    skipped = 0
    total_rows = 0
    inserted = 0
    updated = 0
    missing_mother_sku = 0
    template_v2 = False
    changed_pairs: Set[Tuple[Optional[str], str]] = set()
    occurrence_counters: Dict[str, int] = {}
    batch: List[SalesRow] = []
    expected_rows = 0

    def _set_expected_rows(total: int) -> None:
        nonlocal expected_rows
        expected_rows = max(0, int(total or 0))

    def flush_batch() -> None:
        nonlocal inserted, updated
        if not batch:
            return
        upsert = upsert_sales_rows(
            db,
            import_log.id,
            batch,
            occurrence_counters=occurrence_counters,
        )
        inserted += upsert.inserted
        updated += upsert.updated
        changed_pairs.update(upsert.changed_pairs)
        batch.clear()

    source: Union[bytes, str, Path] = file_bytes
    source_path = Path(file_bytes) if isinstance(file_bytes, (str, Path)) else None
    if source_path is not None and source_path.suffix.lower() == ".xls":
        if source_path.stat().st_size > 20 * 1024 * 1024:
            raise HTTPException(
                status_code=413,
                detail="File .xls lebih dari 20 MB; simpan ulang sebagai .xlsx",
            )

    rows_iterator = iter(
        _iter_sales_excel(source, file_name, on_total=_set_expected_rows)
    )
    if progress:
        progress.update(8, "Membaca file Excel...")
    while True:
        try:
            row_num, row = next(rows_iterator)
        except StopIteration:
            break
        except Exception as e:
            logger.error("[SALES-IMPORT] Excel read failed: %s", e)
            db.rollback()
            failed_log = ImportLog(
                user_id=current_user.get("user_id"),
                nama=current_user.get("nama"),
                import_type=IMPORT_TYPE_SALES,
                file_name=file_name,
                branch=current_user.get("branch"),
            )
            db.add(failed_log)
            db.flush()
            reason = f"Gagal membaca file Excel: {str(e)}"
            db.add(
                SyncValidationError(
                    import_log_id=failed_log.id,
                    row_number=0,
                    sku="",
                    reason=reason[:255],
                )
            )
            db.commit()
            if progress:
                progress.fail(reason)
            return {
                "success": False,
                "total_rows": 0,
                "inserted": 0,
                "updated": 0,
                "skipped": 0,
                "errors": [{"row": 0, "sku": "", "reason": reason}],
                "versions": [],
                "template": None,
                "missing_mother_sku": 0,
            }

        if row.get("key_mode") == "return":
            db.rollback()
            raise HTTPException(
                status_code=400,
                detail="File retur harus diunggah melalui Import Retur.",
            )

        total_rows += 1
        if progress and total_rows % 500 == 0:
            progress.row_progress(
                total_rows, expected_rows, "Memproses baris penjualan", 8, 45
            )
        template_v2 = template_v2 or row.get("key_mode") == "v2"
        sale_date = _to_date(row.get("sale_date"))
        qty = _to_int(row.get("qty"))
        qtyi = _to_int(row.get("qtyi"))
        diskon = _to_int(row.get("diskon"))
        net_per_unit = _to_int(row.get("net_per_unit"))
        total_amount = _to_int(row.get("total_amount"))
        margin = _to_int(row.get("margin"))
        key_mode = row.get("key_mode")

        # Baris tanpa transaksi/qty utama dianggap tidak valid → skipped.
        if (
            key_mode != "v2"
            and not row.get("trans_no")
            and qty is None
            and total_amount is None
        ):
            skipped += 1
            _add_error(validation_errors, row_num, row, "Baris kosong/tanpa transaksi")
            continue

        # Tanpa tanggal, baris tidak akan pernah muncul di ringkasan bulanan.
        # Tolak sejak import supaya data tidak "hilang" secara diam-diam.
        # Sertakan nilai mentahnya agar format yang tidak dikenali mudah
        # didiagnosis dari pesan error.
        if sale_date is None:
            skipped += 1
            raw_date = row.get("sale_date")
            raw_hint = "" if raw_date is None else f" (nilai: {raw_date!r})"
            _add_error(
                validation_errors,
                row_num,
                row,
                f"Tanggal penjualan tidak valid atau kosong{raw_hint}",
            )
            continue

        # Branch attribution:
        # - Branch-scoped users always import into their own branch.
        # - Global MANAGER uses the file's "Cabang" column when present;
        #   an empty cell leaves the row unattributed (NULL = global only).
        row_branch = account_branch
        if global_manager:
            row_branch = _resolve_row_branch(row.get("branch"))
        product_kode = _clean_str(row.get("product_kode"))
        product_nama = _clean_str(row.get("product_nama"))
        if key_mode == "v2":
            if not row_branch or row_branch not in get_valid_branch_codes():
                skipped += 1
                _add_error(
                    validation_errors, row_num, row, "Cabang kosong atau tidak dikenal"
                )
                continue
            if total_amount is None:
                skipped += 1
                _add_error(validation_errors, row_num, row, "TOTAL tidak valid atau kosong")
                continue
            if not product_kode and not product_nama:
                skipped += 1
                _add_error(
                    validation_errors,
                    row_num,
                    row,
                    "Kode Item atau Nama Item wajib diisi",
                )
                continue
            if not _clean_str(row.get("mother_sku")):
                missing_mother_sku += 1

        batch.append(
            SalesRow(
                branch=row_branch,
                trans_no=_clean_str(row.get("trans_no")),
                sale_date=sale_date,
                customer_kode=_clean_str(row.get("customer_kode")),
                customer_nama=_clean_str(row.get("customer_nama")),
                channel=_clean_str(row.get("channel")),
                kategori=_clean_str(row.get("kategori")),
                customer_group=_clean_str(row.get("customer_group")),
                area=_clean_str(row.get("area")),
                alamat=_clean_str(row.get("alamat")),
                product_kode=product_kode,
                product_nama=product_nama,
                qty=qty,
                satuan_jual=_clean_str(row.get("satuan_jual")),
                qtyi=qtyi,
                satuani=_clean_str(row.get("satuani")),
                diskon=diskon,
                net_per_unit=net_per_unit,
                total_amount=total_amount,
                margin=margin,
                mother_sku=_clean_str(row.get("mother_sku")),
                divisi=_clean_str(row.get("divisi")),
                sales_kode=_clean_str(row.get("sales_kode")),
                sales_nama=_clean_str(row.get("sales_nama")),
                supplier=_clean_str(row.get("supplier")),
                key_mode=key_mode,
            )
        )
        if len(batch) >= 5000:
            flush_batch()

    flush_batch()
    if progress:
        progress.update(50, "Menyimpan data ke database...")
    success = bool(inserted or updated)
    if not success and total_rows == 0:
        _add_error(validation_errors, 0, {}, "File tidak berisi baris data")
    elif not success and not validation_errors:
        _add_error(validation_errors, 0, {}, "Tidak ada baris valid untuk diimport")

    import_log.total_rows = total_rows
    import_log.inserted = inserted
    import_log.updated = updated
    import_log.skipped = skipped

    for err in validation_errors:
        db.add(
            SyncValidationError(
                import_log_id=import_log.id,
                row_number=err.get("row") or 0,
                sku=err.get("sku") or "",
                reason=(err.get("reason") or "")[:255],
            )
        )

    versions: List[Dict[str, Any]] = []
    if changed_pairs:
        # Bump only the (scope, month) pairs whose data really moved. A pure
        # re-import of an unchanged file has an empty set and bumps nothing.
        versions = bump_versions_for_changes(db, changed_pairs)

        # Rebuild the precomputed snapshot in the same transaction as the rows
        # and the version bump. The summary endpoint then only needs a small
        # indexed read, and readers never observe a version/snapshot mismatch
        # after commit.
        version_by_key = {
            (v["scope"], v["month"]): int(v["version"] or 0) for v in versions
        }
        affected: set[Tuple[str, str]] = set()
        for branch, month in changed_pairs:
            affected.add((GLOBAL_SCOPE, month))
            if branch:
                affected.add((branch, month))
        ordered_affected = sorted(affected)
        if progress:
            progress.update(60, "Menghitung ulang ringkasan penjualan...")
        for index, (scope, month) in enumerate(ordered_affected, start=1):
            _, start, month_end = parse_month(month)
            recompute_summary(
                db,
                scope,
                month,
                start,
                month_end,
                version=version_by_key.get((scope, month), 0),
            )
            if progress:
                progress.update(
                    60 + int(35 * index / len(ordered_affected)),
                    f"Menghitung ringkasan {scope} {month}...",
                )

    if progress:
        progress.update(97, "Menyelesaikan import...")
    db.commit()
    if progress:
        progress.finish()

    return {
        "success": success,
        "total_rows": total_rows,
        "inserted": inserted,
        "updated": updated,
        "skipped": skipped,
        "errors": validation_errors,
        "versions": versions,
        "template": "v2" if template_v2 else None,
        "missing_mother_sku": missing_mother_sku,
    }
