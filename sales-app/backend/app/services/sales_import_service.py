"""Import laporan penjualan dari file Excel.

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
per satuan setelah diskon) dan `total_amount` (total akhir baris).

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
from datetime import date, datetime, timedelta
from io import BytesIO
from typing import Any, Dict, List, Optional, Tuple

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

logger = logging.getLogger(__name__)

try:
    import openpyxl
    OPENPYXL_AVAILABLE = True
except ImportError:
    OPENPYXL_AVAILABLE = False

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
        "tanggal penjualan", "tanggal order", "penjualan", "tanggal",
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
    if header == alias:
        # Guard: app report has separate "Diskon Layer N" columns. The plain
        # "diskon" alias must only win on a real total column.
        return 100 + len(alias)
    if header.startswith(alias + " "):
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


def _find_header_row(ws) -> int:
    """Cari baris header laporan penjualan di 15 baris pertama.

    Mendeteksi template utama (`Penjualan`, `Trans No`, ...) maupun laporan
    aplikasi (`Tanggal`, `Kode Item`, `Qty`, ...) tanpa bergantung pada satu
    nama kolom saja.
    """
    for i, row in enumerate(ws.iter_rows(min_row=1, max_row=15, values_only=True), start=1):
        norms = [_norm_header(c) for c in row]
        fields = {f for f in (_resolve_field(n) for n in norms if n) if f}
        has_date = "sale_date" in fields
        has_item = bool({"product_kode", "product_nama"} & fields)
        has_amount = bool({"qty", "total_amount"} & fields)
        if has_date and (has_item or has_amount):
            return i
    raise ValueError("Header laporan penjualan tidak ditemukan di 15 baris pertama.")


def _read_sales_excel(file_bytes: bytes) -> List[Dict[str, Any]]:
    """Parse file .xlsx laporan penjualan ke list of row dicts (field -> value)."""
    if not OPENPYXL_AVAILABLE:
        raise RuntimeError("openpyxl library not installed. Run: pip install openpyxl")

    wb = openpyxl.load_workbook(BytesIO(file_bytes), data_only=True)
    ws = wb.active
    header_row_idx = _find_header_row(ws)

    headers = [
        _norm_header(c)
        for c in next(
            ws.iter_rows(
                min_row=header_row_idx,
                max_row=header_row_idx,
                values_only=True,
            )
        )
    ]
    col_map = _resolve_columns(headers)

    rows: List[Dict[str, Any]] = []
    for row in ws.iter_rows(min_row=header_row_idx + 1, values_only=True):
        if all(cell is None for cell in row):
            continue
        row_dict: Dict[str, Any] = {}
        for field, idx in col_map.items():
            row_dict[field] = row[idx] if 0 <= idx < len(row) else None
        rows.append(row_dict)

    logger.info("[SALES-IMPORT] headers resolved: %s", col_map)
    return rows


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

    s = str(value).strip()
    if not s:
        return None

    # ISO datetime (also handles a trailing Z / offset).
    try:
        return datetime.fromisoformat(s.replace("Z", "+00:00")).date()
    except ValueError:
        pass

    # Indonesian month names -> English, then retry common text formats.
    normalized = s.lower()
    for indo, english in _INDONESIAN_MONTHS.items():
        normalized = re.sub(rf"\b{indo}\b", english, normalized)

    formats = (
        "%Y-%m-%d",
        "%Y/%m/%d",
        "%Y%m%d",
        "%d/%m/%Y",
        "%m/%d/%Y",
        "%d-%m-%Y",
        "%d-%b-%Y",
        "%d %b %Y",
        "%d-%B-%Y",
        "%d %B %Y",
        "%b %d, %Y",
        "%B %d, %Y",
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
    file_bytes: bytes,
    db: Session,
    current_user: Dict[str, Any],
    file_name: str,
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
    rows: List[SalesRow] = []

    try:
        raw_rows = _read_sales_excel(file_bytes)
    except Exception as e:
        logger.error("[SALES-IMPORT] Excel read failed: %s", e)
        reason = f"Gagal membaca file Excel: {str(e)}"
        db.add(
            SyncValidationError(
                import_log_id=import_log.id,
                row_number=0,
                sku="",
                reason=reason[:255],
            )
        )
        db.commit()
        return {
            "success": False,
            "total_rows": 0,
            "inserted": 0,
            "updated": 0,
            "skipped": 0,
            "errors": [{"row": 0, "sku": "", "reason": reason}],
            "versions": [],
        }

    total_rows = len(raw_rows)
    for row_num, row in enumerate(raw_rows, start=2):
        sale_date = _to_date(row.get("sale_date"))
        qty = _to_int(row.get("qty"))
        qtyi = _to_int(row.get("qtyi"))
        diskon = _to_int(row.get("diskon"))
        net_per_unit = _to_int(row.get("net_per_unit"))
        total_amount = _to_int(row.get("total_amount"))

        # Baris tanpa transaksi/qty utama dianggap tidak valid → skipped.
        if not row.get("trans_no") and qty is None and total_amount is None:
            skipped += 1
            _add_error(validation_errors, row_num, row, "Baris kosong/tanpa transaksi")
            continue

        # Tanpa tanggal, baris tidak akan pernah muncul di ringkasan bulanan.
        # Tolak sejak import supaya data tidak "hilang" secara diam-diam.
        if sale_date is None:
            skipped += 1
            _add_error(
                validation_errors,
                row_num,
                row,
                "Tanggal penjualan tidak valid atau kosong",
            )
            continue

        # Branch attribution:
        # - Branch-scoped users always import into their own branch.
        # - Global MANAGER uses the file's "Cabang" column when present;
        #   an empty cell leaves the row unattributed (NULL = global only).
        row_branch = account_branch
        if global_manager:
            row_branch = _resolve_row_branch(row.get("branch"))

        rows.append(
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
                product_kode=_clean_str(row.get("product_kode")),
                product_nama=_clean_str(row.get("product_nama")),
                qty=qty,
                satuan_jual=_clean_str(row.get("satuan_jual")),
                qtyi=qtyi,
                satuani=_clean_str(row.get("satuani")),
                diskon=diskon,
                net_per_unit=net_per_unit,
                total_amount=total_amount,
                sales_kode=_clean_str(row.get("sales_kode")),
                sales_nama=_clean_str(row.get("sales_nama")),
                supplier=_clean_str(row.get("supplier")),
            )
        )

    success = bool(rows)
    if not success and total_rows == 0:
        _add_error(validation_errors, 0, {}, "File tidak berisi baris data")
    elif not success and not validation_errors:
        _add_error(validation_errors, 0, {}, "Tidak ada baris valid untuk diimport")

    # Dedupe/upsert: re-imported rows match their deterministic key, so the
    # same file cannot append duplicates. Only real data changes are flagged
    # for version bumps / summary rebuilds below.
    upsert = upsert_sales_rows(db, import_log.id, rows)
    inserted = upsert.inserted
    updated = upsert.updated

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
    if upsert.changed_pairs:
        # Bump only the (scope, month) pairs whose data really moved. A pure
        # re-import of an unchanged file has an empty set and bumps nothing.
        versions = bump_versions_for_changes(db, upsert.changed_pairs)

        # Rebuild the precomputed snapshot in the same transaction as the rows
        # and the version bump. The summary endpoint then only needs a small
        # indexed read, and readers never observe a version/snapshot mismatch
        # after commit.
        version_by_key = {
            (v["scope"], v["month"]): int(v["version"] or 0) for v in versions
        }
        affected: set[Tuple[str, str]] = set()
        for branch, month in upsert.changed_pairs:
            affected.add((GLOBAL_SCOPE, month))
            if branch:
                affected.add((branch, month))
        for scope, month in sorted(affected):
            _, start, month_end = parse_month(month)
            recompute_summary(
                db,
                scope,
                month,
                start,
                month_end,
                version=version_by_key.get((scope, month), 0),
            )

    db.commit()

    return {
        "success": success,
        "total_rows": total_rows,
        "inserted": inserted,
        "updated": updated,
        "skipped": skipped,
        "errors": validation_errors,
        "versions": versions,
    }
