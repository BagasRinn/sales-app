"""
Customer sync service — Excel import logic untuk tabel customers.

Identity toko = (nama_toko, alamat) keduanya. Boleh ada dua toko dengan
nama sama selama alamatnya beda, dan sebaliknya.

Pola bulk upsert: 1 bulk SELECT + 1 bulk INSERT ON CONFLICT DO UPDATE + 1 commit.
Pattern mirror dari app/services/sheets_sync.py.
"""
import logging
from io import BytesIO
from typing import List, Dict, Any
from uuid import UUID
from sqlalchemy.orm import Session
from sqlalchemy.dialects.postgresql import insert

logger = logging.getLogger(__name__)

try:
    import openpyxl
    OPENPYXL_AVAILABLE = True
except ImportError:
    OPENPYXL_AVAILABLE = False

from app.models.models import Customer, SyncValidationError, ImportLog

EXCEL_COLUMNS = ["kode", "nama_toko", "alamat", "kode_area"]


def _read_excel(file_bytes: bytes) -> List[Dict[str, Any]]:
    """Parse an Excel file (.xlsx) into a list of row dicts."""
    if not OPENPYXL_AVAILABLE:
        raise RuntimeError("openpyxl library not installed. Run: pip install openpyxl")

    wb = openpyxl.load_workbook(BytesIO(file_bytes), data_only=True)
    ws = wb.active

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

    headers = [str(cell.value).strip() if cell.value is not None else "" for cell in ws[header_row_idx]]
    headers_lower = [h.lower() for h in headers]

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


def _normalize(value: Any) -> str:
    """Normalize string for comparison: strip + lowercase. Empty string for None."""
    if value is None:
        return ""
    return str(value).strip().lower()


def _validate_row(row_num: int, nama_toko: Any, alamat: Any, kode: Any) -> str | None:
    """Validate required fields. Return error string or None.

    Identity customer = kode. nama_toko dan alamat tidak harus unik per file —
    banyak toko boleh share nama/alamat selama kode beda. Kode nullable, kalau
    null/empty row di-skip dari validasi kode (akan jadi insert baru tanpa
    konflik).
    """
    if not nama_toko or not str(nama_toko).strip():
        return "Kolom 'nama_toko' kosong. Wajib diisi dengan nama toko."
    if not alamat or not str(alamat).strip():
        return "Kolom 'alamat' kosong. Wajib diisi dengan alamat toko."
    # kode kosong/None → OK (insert baru). kode ada → harus string non-empty.
    if kode is not None and str(kode).strip() == "":
        return "Kolom 'kode' kosong. Isi dengan kode toko atau kosongkan (jangan spasi saja)."
    return None


def _str_or_none(value: Any) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    return text if text else None


# sync_validation_errors.reason is VARCHAR(255) (see models.SyncValidationError).
# SQLAlchemy/psycopg error dumps often exceed 2K chars (full SQL + parameters),
# which would crash the error log itself with StringDataRightTruncation —
# defeating the purpose of logging. Clamp to a safe size with a trailing
# ellipsis so the user-visible error message stays intact.
REASON_MAX_LEN = 240


def _safe_reason(text: Any) -> str:
    s = "" if text is None else str(text).strip()
    if len(s) <= REASON_MAX_LEN:
        return s
    return s[: REASON_MAX_LEN - 3] + "..."


def _bulk_upsert_customers(
    db: Session,
    rows: List[Dict[str, Any]],
    branch: str | None = None,
) -> tuple[int, int]:
    """
    Bulk upsert customers using PostgreSQL ON CONFLICT DO UPDATE.

    Branch is taken from the caller (the JWT-authenticated user). The
    Composite unique key (branch, kode, kode_area) means a customer
    `OUT001/MULIA2` in BATULICIN is distinct from `OUT001/MULIA2` in
    BANJARMASIN — cross-branch upserts are independent.

    `branch` MUST be non-None for new inserts (customers.branch is NOT NULL).
    Re-activation path (existing soft-deleted rows) is unaffected because
    it loads the row first.

    Returns (inserted_count, updated_count).
    """
    if not rows:
        return 0, 0

    # Normalize: attach branch to every row so downstream code can use r["branch"].
    if branch is not None:
        for r in rows:
            r["branch"] = branch

    # Lookup existing customers by (branch, kode, kode_area) triple. Rows
    # with NULL kode or NULL kode_area skip the lookup (non-partial UNIQUE
    # index treats NULL as distinct → no conflict possible).
    triples_in_file = sorted({
        (r["branch"], r["kode"], r["kode_area"])
        for r in rows
        if r.get("kode") and r.get("kode_area") and r.get("branch")
    })
    from sqlalchemy import and_, or_
    existing_rows = []
    if triples_in_file:
        if len(triples_in_file) == 1:
            br, k, a = triples_in_file[0]
            existing_rows = (
                db.query(Customer.id, Customer.kode, Customer.kode_area, Customer.branch, Customer.deleted_at)
                .filter(and_(Customer.branch == br, Customer.kode == k, Customer.kode_area == a))
                .all()
            )
        else:
            conditions = [
                and_(Customer.branch == br, Customer.kode == k, Customer.kode_area == a)
                for br, k, a in triples_in_file
            ]
            existing_rows = (
                db.query(Customer.id, Customer.kode, Customer.kode_area, Customer.branch, Customer.deleted_at)
                .filter(or_(*conditions))
                .all()
            )
    # Build lookup: (branch, kode, kode_area) -> (customer_id, is_deleted)
    existing_map: Dict[tuple, tuple] = {}
    for row in existing_rows:
        if row.kode and row.kode_area and row.branch:
            existing_map[(row.branch, row.kode, row.kode_area)] = (
                str(row.id), row.deleted_at is not None
            )

    to_insert = []   # new customers (no existing triple, or NULL kode/area)
    to_update = []  # re-activate deleted customers

    for r in rows:
        kode = r.get("kode")
        kode_area = r.get("kode_area")
        # NULL/empty kode atau kode_area → always insert (no conflict possible)
        if not kode or not kode_area:
            to_insert.append(r)
            continue
        key = (r["branch"], kode, kode_area)
        if key in existing_map:
            cid, is_deleted = existing_map[key]
            if is_deleted:
                to_update.append((cid, r))
            # else: active customer exists — ON CONFLICT DO UPDATE will refresh
            # other fields (nama_toko/alamat/kode_area) below.
        else:
            to_insert.append(r)

    inserted = len(to_insert)
    updated = len(to_update)

    if to_insert:
        stmt = insert(Customer).values([
            {
                "branch": r["branch"],
                "kode": r.get("kode"),
                "nama_toko": r["nama_toko"],
                "alamat": r["alamat"],
                "kode_area": r.get("kode_area"),
            }
            for r in to_insert
        ])
        # ON CONFLICT must match the actual unique constraint
        # (branch, kode, kode_area) per models.Customer.__table_args__.
        # NOT updating `branch` on conflict — if a customer already exists
        # in this branch with same (kode, kode_area), keep its branch.
        stmt = stmt.on_conflict_do_update(
            index_elements=[Customer.branch, Customer.kode, Customer.kode_area],
            set_={
                "kode_area": stmt.excluded.kode_area,
                "kode": stmt.excluded.kode,
                "nama_toko": stmt.excluded.nama_toko,
                "alamat": stmt.excluded.alamat,
                "deleted_at": None,
            },
        )
        db.execute(stmt)
        logger.info(f"[SYNC] Bulk inserted {len(to_insert)} customers")

    if to_update:
        # Re-activate deleted customers by id
        for customer_id_str, r in to_update:
            kode_val = r.get("kode")
            kode_area_val = r.get("kode_area")
            result = db.query(Customer).filter(Customer.id == UUID(customer_id_str)).with_for_update().first()
            if result:
                if kode_val is not None:
                    result.kode = kode_val
                if kode_area_val is not None:
                    result.kode_area = kode_area_val
                result.deleted_at = None
        logger.info(f"[SYNC] Re-activated {len(to_update)} deleted customers")

    return inserted, updated


def sync_customers_from_excel(
    file_bytes: bytes,
    db: Session,
    current_user: Dict[str, Any],
    file_name: str,
) -> Dict[str, Any]:
    """
    Read customer data from uploaded Excel, bulk upsert into customers table.
    Creates an ImportLog row and persists per-row validation errors with FK.
    """
    validation_errors: List[Dict[str, str]] = []
    validated_rows: List[Dict[str, Any]] = []
    skipped = 0

    import_log = ImportLog(
        user_id=current_user.get("user_id"),
        nama=current_user.get("nama"),
        import_type="CUSTOMER",
        file_name=file_name,
    )
    db.add(import_log)
    db.flush()
    # Commit import_log segera — supaya ID-nya persistent di DB dan tidak ikut
    # ter-rollback kalau bulk upsert di bawah gagal. SyncValidationError butuh
    # FK ke import_log.id yang valid.
    db.commit()

    try:
        raw_rows = _read_excel(file_bytes)
    except Exception as e:
        logger.error(f"Excel read failed: {e}")
        reason_text = f"Gagal membaca file Excel: {str(e)}"
        db.add(SyncValidationError(
            import_log_id=import_log.id,
            row_number=0,
            sku="",
            reason=_safe_reason(reason_text),
        ))
        import_log.total_rows = 0
        import_log.skipped = 0
        db.commit()
        return {
            "success": False,
            "total_rows": 0,
            "inserted": 0,
            "updated": 0,
            "skipped": 0,
            "errors": [{"row": 0, "sku": "", "reason": reason_text}],
            "needs_review": False,
        }

    total_rows = len(raw_rows)
    # Identity customer = (branch, kode, kode_area) triple. Same (kode, kode_area)
    # boleh di branch berbeda; dalam satu branch harus unik per area.
    # Null/null pairs di-skip dari unique check.
    seen_keys: set = set()

    for idx, row in enumerate(raw_rows, start=1):
        nama_toko_raw = row.get("nama_toko")
        alamat_raw = row.get("alamat")
        kode_raw = row.get("kode")
        kode_area_raw = row.get("kode_area")

        error = _validate_row(idx, nama_toko_raw, alamat_raw, kode_raw)
        if error:
            validation_errors.append({"row": idx, "sku": str(kode_raw or nama_toko_raw or ""), "reason": error})
            skipped += 1
            continue

        # Kode null/empty atau kode_area null/empty → skip unique check
        # (akan jadi insert baru, no conflict possible).
        kode_norm = _normalize(kode_raw)
        kode_area_norm = _normalize(kode_area_raw)
        if kode_norm and kode_area_norm:
            key = (kode_norm, kode_area_norm)
            if key in seen_keys:
                validation_errors.append({
                    "row": idx,
                    "sku": str(kode_raw),
                    "reason": (
                        f"Kode '{kode_raw}' muncul lebih dari sekali di area '{kode_area_raw}' "
                        "di file ini. Kode yang sama boleh di area berbeda, tapi dalam "
                        "satu area harus unik."
                    ),
                })
                skipped += 1
                continue
            seen_keys.add(key)

        validated_rows.append({
            "kode": _str_or_none(row.get("kode")),
            "nama_toko": str(nama_toko_raw).strip(),
            "alamat": _str_or_none(alamat_raw),
            "kode_area": _str_or_none(row.get("kode_area")),
        })

    inserted = updated = 0
    if validated_rows:
        try:
            inserted, updated = _bulk_upsert_customers(
                db, validated_rows, branch=current_user.get("branch"),
            )
        except Exception as e:
            # PENTING: rollback dulu supaya session tidak tinggal di state aborted.
            # Kalau tidak, command berikutnya (db.add SyncValidationError, db.commit)
            # akan error "current transaction is aborted, commands ignored".
            db.rollback()
            logger.error(f"Bulk upsert failed: {e}")
            reason_text = f"Gagal menyimpan ke database: {str(e)}"
            validation_errors.append({
                "row": 0,
                "sku": "",
                "reason": reason_text,
            })
            skipped = total_rows
            inserted = updated = 0

    for err in validation_errors:
        db.add(SyncValidationError(
            import_log_id=import_log.id,
            row_number=err["row"],
            sku=err["sku"],
            # Clamp to fit VARCHAR(255) — full exception dumps easily exceed
            # 2K chars and would crash the error log itself.
            reason=_safe_reason(err["reason"]),
        ))

    import_log.total_rows = total_rows
    import_log.inserted = inserted
    import_log.updated = updated
    import_log.skipped = skipped

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
            "needs_review": False,
        }

    return {
        "success": True,
        "total_rows": total_rows,
        "inserted": inserted,
        "updated": updated,
        "skipped": skipped,
        "errors": validation_errors,
        "needs_review": len(validation_errors) > 0,
    }
