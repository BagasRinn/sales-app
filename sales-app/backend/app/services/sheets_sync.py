import logging
from io import BytesIO
from typing import List, Tuple, Dict, Any
from sqlalchemy.orm import Session
from sqlalchemy.dialects.postgresql import insert

logger = logging.getLogger(__name__)

try:
    import openpyxl
    OPENPYXL_AVAILABLE = True
except ImportError:
    OPENPYXL_AVAILABLE = False

from app.models.models import Product, SyncValidationError
from app.services.stock_logger import log_stock_change

EXCEL_COLUMNS = ["code", "KATEGORI", "NAME ITEM", "STOK", "OUM", "FIX"]


def _read_excel(file_bytes: bytes) -> List[Dict[str, Any]]:
    """Parse an Excel file (.xlsx) into a list of row dicts using openpyxl."""
    if not OPENPYXL_AVAILABLE:
        raise RuntimeError("openpyxl library not installed. Run: pip install openpyxl")

    wb = openpyxl.load_workbook(BytesIO(file_bytes), data_only=True)
    ws = wb.active

    # Find header row by scanning for "code" in first 10 rows
    header_row_idx = None
    for i, row in enumerate(ws.iter_rows(min_row=1, max_row=10, values_only=True), start=1):
        if any(str(cell).strip().lower() == "code" for cell in row if cell is not None):
            header_row_idx = i
            break

    if header_row_idx is None:
        raise ValueError("Kolom 'code' tidak ditemukan di 10 baris pertama. Pastikan header ada di baris 1-10.")

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

    # Debug: log detected headers and first 3 rows
    logger.info(f"[DEBUG] Headers found at row {header_row_idx}: {headers}")
    logger.info(f"[DEBUG] Column mapping: {col_map}")
    if rows:
        logger.info(f"[DEBUG] First row sample: {rows[0]}")

    return rows


def _validate_row(row_num: int, sku: str, nama_produk: str, harga: Any, stok: Any) -> str | None:
    if not sku or not str(sku).strip():
        return "SKU kosong"
    if harga is not None:
        try:
            int(harga)
        except (ValueError, TypeError):
            return f"Harga bukan angka: {harga}"
    if stok is not None:
        try:
            stok_val = int(stok)
            if stok_val < 0:
                return f"Stok negatif: {stok_val}"
        except (ValueError, TypeError):
            return f"Stok bukan angka: {stok}"
    return None


def _parse_stok(value: Any) -> int:
    """Parse stok value like '880 Pcs' or '3 Ktn, 2 Reg' -> integer."""
    if value is None:
        return 0
    text = str(value).strip()
    if not text:
        return 0
    # Extract leading integer
    import re
    match = re.match(r"(\d+)", text)
    if match:
        return int(match.group(1))
    return 0


def sync_products_from_excel(file_bytes: bytes, db: Session) -> Dict[str, Any]:
    """
    Read product data from an uploaded Excel file and upsert into the database.
    All changes happen inside a single transaction — rollback on any error.
    """
    validation_errors: List[Dict[str, str]] = []
    skipped = 0
    seen_skus: set[str] = set()
    validated_rows: List[Dict[str, Any]] = []

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
            "needs_review": False,
        }

    total_rows = len(raw_rows)

    for row_num, row in enumerate(raw_rows, start=2):
        sku = str(row.get("code") or "").strip()
        nama_produk = str(row.get("NAME ITEM") or "").strip()
        harga_raw = row.get("FIX")
        stok_raw = row.get("STOK")
        kategori = str(row.get("KATEGORI") or "").strip() or None
        satuan = str(row.get("OUM") or "").strip() or None

        error = _validate_row(row_num, sku, nama_produk, harga_raw, stok_raw)
        if error:
            validation_errors.append({"row": row_num, "sku": sku, "reason": error})
            skipped += 1
            if len(validation_errors) <= 5:
                logger.warning(f"[DEBUG] Row {row_num} validation failed: {error} | sku='{sku}' harga='{harga_raw}' stok='{stok_raw}'")
            continue

        if sku.lower() in seen_skus:
            validation_errors.append({"row": row_num, "sku": sku, "reason": "SKU duplikat dalam file"})
            skipped += 1
            continue
        seen_skus.add(sku.lower())

        harga = int(harga_raw) if harga_raw else 0
        stok = _parse_stok(stok_raw)
        validated_rows.append({
            "sku": sku,
            "nama_barang": nama_produk,
            "harga": harga,
            "stok": stok,
            "kategori": kategori,
            "satuan": satuan,
        })

    inserted = updated = 0
    if validated_rows:
        inserted, updated = _bulk_upsert(db, validated_rows)

    # Persist validation errors so /sync/errors can return them later
    for err in validation_errors:
        db.add(SyncValidationError(
            row_number=err["row"],
            sku=err["sku"],
            reason=err["reason"],
        ))
    db.commit()

    # Compute needs_review (products where stok_sistem < stok_booking)
    needs_review_count = db.query(Product).filter(
        Product.stok_sistem < Product.stok_booking
    ).count()

    return {
        "success": True,
        "total_rows": total_rows,
        "inserted": inserted,
        "updated": updated,
        "skipped": skipped,
        "errors": validation_errors,
        "needs_review": needs_review_count > 0,
    }


def _bulk_upsert(db: Session, rows: List[Dict[str, Any]]) -> Tuple[int, int]:
    """
    Bulk upsert using PostgreSQL ON CONFLICT DO UPDATE.
    Returns (inserted_count, updated_count).
    """
    skus = [r["sku"] for r in rows]
    existing = {
        p.id: p.stok_sistem
        for p in db.query(Product).filter(Product.id.in_(skus))
        .with_entities(Product.id, Product.stok_sistem).all()
    }

    to_insert = [r for r in rows if r["sku"] not in existing]
    to_update = [r for r in rows if r["sku"] in existing]

    if to_insert:
        stmt = insert(Product).values([
            {"id": r["sku"], "nama_barang": r["nama_barang"],
             "harga": r["harga"], "stok_sistem": r["stok"],
             "stok_booking": 0, "kategori": r.get("kategori"),
             "satuan": r.get("satuan")}
            for r in to_insert
        ])
        db.execute(stmt)
        logger.info(f"[SYNC] Bulk inserted %d products", len(to_insert))

    if to_update:
        def _stock_changed(existing_val, excel_val):
            return (existing_val or 0) != (excel_val or 0)
        changed = [r for r in to_update if _stock_changed(existing[r["sku"]], r["stok"])]
        unchanged = [r for r in to_update if not _stock_changed(existing[r["sku"]], r["stok"])]

        if changed:
            stmt = insert(Product).values([
                {"id": r["sku"], "nama_barang": r["nama_barang"],
                 "harga": r["harga"], "stok_sistem": r["stok"],
                 "kategori": r.get("kategori"), "satuan": r.get("satuan")}
                for r in changed
            ])
            stmt = stmt.on_conflict_do_update(
                index_elements=["id"],
                set_={"nama_barang": stmt.excluded.nama_barang,
                      "harga": stmt.excluded.harga,
                      "stok_sistem": stmt.excluded.stok_sistem,
                      "kategori": stmt.excluded.kategori,
                      "satuan": stmt.excluded.satuan},
            )
            db.execute(stmt)
            for r in changed:
                log_stock_change(
                    db=db, product_id=r["sku"], sumber="SYNC",
                    field_terdampak="stok_sistem",
                    delta=r["stok"] - existing[r["sku"]],
                    nilai_sebelum=existing[r["sku"]], nilai_sesudah=r["stok"],
                    actor_id=None, order_id=None,
                )
        if unchanged:
            stmt = insert(Product).values([
                {"id": r["sku"], "nama_barang": r["nama_barang"],
                 "harga": r["harga"],
                 "kategori": r.get("kategori"), "satuan": r.get("satuan")}
                for r in unchanged
            ])
            stmt = stmt.on_conflict_do_update(
                index_elements=["id"],
                set_={"nama_barang": stmt.excluded.nama_barang,
                      "harga": stmt.excluded.harga,
                      "kategori": stmt.excluded.kategori,
                      "satuan": stmt.excluded.satuan},
            )
            db.execute(stmt)
        logger.info(f"[SYNC] Bulk updated %d products (%d stock changes)", len(to_update), len(changed))

    return len(to_insert), len(to_update)
