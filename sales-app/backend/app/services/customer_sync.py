"""
Customer sync service — Excel import logic untuk tabel customers.
Prototipe: kolom wajib kode, nama_toko (nama outlet); opsional alamat.
Assignment sales dilakukan manual via endpoint /customers/{id}/assign.

Pattern mirror dari app/services/sheets_sync.py.
"""
import logging
from io import BytesIO
from typing import List, Dict, Any
from sqlalchemy.orm import Session

logger = logging.getLogger(__name__)

try:
    import openpyxl
    OPENPYXL_AVAILABLE = True
except ImportError:
    OPENPYXL_AVAILABLE = False

from app.models.models import Customer

EXCEL_COLUMNS = ["kode", "nama_toko", "alamat"]


def _read_excel(file_bytes: bytes) -> List[Dict[str, Any]]:
    """Parse an Excel file (.xlsx) into a list of row dicts."""
    if not OPENPYXL_AVAILABLE:
        raise RuntimeError("openpyxl library not installed. Run: pip install openpyxl")

    wb = openpyxl.load_workbook(BytesIO(file_bytes), data_only=True)
    ws = wb.active

    # Find header row by scanning for "nama_toko" or "kode" in first 10 rows
    header_row_idx = None
    for i, row in enumerate(ws.iter_rows(min_row=1, max_row=10, values_only=True), start=1):
        cells_lower = [str(cell).strip().lower() for cell in row if cell is not None]
        if "nama_toko" in cells_lower or "kode" in cells_lower:
            header_row_idx = i
            break

    if header_row_idx is None:
        raise ValueError(
            "Kolom 'nama_toko' atau 'kode' tidak ditemukan di 10 baris pertama. "
            "Pastikan header ada di baris 1-10."
        )

    # Read headers from found row
    headers = [str(cell.value).strip() if cell.value is not None else "" for cell in ws[header_row_idx]]
    headers_lower = [h.lower() for h in headers]

    # Build expected index mapping using lowercase match
    col_map = {}
    for col_name in EXCEL_COLUMNS:
        try:
            col_map[col_name] = headers_lower.index(col_name.lower())
        except ValueError:
            col_map[col_name] = -1

    rows = []
    for row in ws.iter_rows(min_row=header_row_idx + 1, values_only=True):
        if all(cell is None for cell in row):
            continue
        row_dict = {}
        for col_name in EXCEL_COLUMNS:
            idx = col_map[col_name]
            row_dict[col_name] = row[idx] if idx >= 0 and idx < len(row) else None
        rows.append(row_dict)

    return rows


def _normalize_nama_toko(value: Any) -> str:
    """Normalize nama_toko for matching: strip + lowercase."""
    if value is None:
        return ""
    return str(value).strip().lower()


def _validate_row(row_num: int, nama_toko: Any) -> str | None:
    """Validate required fields. Return error string or None."""
    if not nama_toko or not str(nama_toko).strip():
        return "nama_toko kosong"
    return None


def _str_or_none(value: Any) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    return text if text else None


def sync_customers_from_excel(file_bytes: bytes, db: Session) -> Dict[str, Any]:
    """
    Read customer data from uploaded Excel, upsert into customers table.
    Returns summary dict. Per-row savepoint so 1 failure doesn't rollback others.
    """
    validation_errors: List[Dict[str, str]] = []
    inserted = 0
    updated = 0
    skipped = 0
    seen_nama_toko: set = set()

    try:
        raw_rows = _read_excel(file_bytes)
    except Exception as e:
        logger.error(f"Excel read failed: {e}")
        return {
            "success": False,
            "total_rows": 0,
            "inserted": 0,
            "updated": 0,
            "skipped": 0,
            "errors": [{"row": 0, "sku": "", "reason": str(e)}],
        }

    total_rows = len(raw_rows)

    for idx, row in enumerate(raw_rows, start=1):
        nama_toko_raw = row.get("nama_toko")
        error = _validate_row(idx, nama_toko_raw)
        if error:
            validation_errors.append({"row": idx, "sku": "", "reason": error})
            skipped += 1
            continue

        normalized = _normalize_nama_toko(nama_toko_raw)
        if normalized in seen_nama_toko:
            validation_errors.append({
                "row": idx,
                "sku": str(nama_toko_raw),
                "reason": f"Duplicate nama_toko '{nama_toko_raw}' dalam file",
            })
            skipped += 1
            continue
        seen_nama_toko.add(normalized)

        kode_value = _str_or_none(row.get("kode"))
        alamat_value = _str_or_none(row.get("alamat"))

        sp = db.begin_nested()
        try:
            existing = (
                db.query(Customer)
                .filter(Customer.nama_toko.ilike(normalized))
                .first()
            )

            if existing:
                # Update hanya kalau Excel ada nilainya, biar tidak overwrite dengan kosong
                if kode_value is not None:
                    existing.kode = kode_value
                if alamat_value is not None:
                    existing.alamat = alamat_value
                if existing.deleted_at is not None:
                    existing.deleted_at = None
                updated += 1
            else:
                db.add(Customer(
                    kode=kode_value,
                    nama_toko=str(nama_toko_raw).strip(),
                    alamat=alamat_value,
                ))
                db.flush()
                inserted += 1

            sp.commit()
        except Exception as e:
            sp.rollback()
            logger.error(f"Row {idx} failed: {e}")
            validation_errors.append({
                "row": idx,
                "sku": str(nama_toko_raw) if nama_toko_raw else "",
                "reason": f"Error: {str(e)}",
            })
            skipped += 1
            continue

    try:
        db.commit()
    except Exception as e:
        db.rollback()
        logger.error(f"Commit failed: {e}")
        return {
            "success": False,
            "total_rows": total_rows,
            "inserted": 0,
            "updated": 0,
            "skipped": total_rows,
            "errors": [{"row": 0, "sku": "", "reason": f"Database error: {str(e)}"}],
        }

    needs_review = len(validation_errors) > 0

    return {
        "success": True,
        "total_rows": total_rows,
        "inserted": inserted,
        "updated": updated,
        "skipped": skipped,
        "errors": validation_errors,
        "needs_review": needs_review,
    }
