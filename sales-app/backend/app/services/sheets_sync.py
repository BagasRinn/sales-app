import logging
import os
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

from app.models.models import Product, SyncValidationError, ImportLog
from app.services.stock_logger import log_stock_change


EXCEL_COLUMNS = ["CCODE", "KATEGORI", "NAME ITEM", "GOOD", "OUM", "FIX", "LAST SUPPLIER"]


SUPPLIERS_4P = [
    "CANDRA FOOD, CV",
    "CUAN BERKAT BERSAMA, PT",
    "DARMAWAN SUKSES MANDIRI, PT",
    "PANGAN INDUSTRI BANUA, PT",
]


def _get_4p_suppliers() -> list[str]:
    """Return daftar supplier 4P. Prioritas dari env SUPPLIERS_4P, fallback ke hardcoded list."""
    env_raw = os.getenv("SUPPLIERS_4P", "").strip()
    if env_raw:
        return [s.strip() for s in env_raw.split(",") if s.strip()]
    return SUPPLIERS_4P


def _supplier_order_type(nama_supplier: str | None) -> str:
    """Return '4P' if supplier is in SUPPLIERS_4P list, else 'REGULER'."""
    if not nama_supplier:
        return "REGULER"
    suppliers_4p = _get_4p_suppliers()
    if not suppliers_4p:
        return "REGULER"
    return "4P" if nama_supplier in suppliers_4p else "REGULER"


def _read_excel(file_bytes: bytes) -> List[Dict[str, Any]]:
    """Parse an Excel file (.xlsx) into a list of row dicts using openpyxl."""
    if not OPENPYXL_AVAILABLE:
        raise RuntimeError("openpyxl library not installed. Run: pip install openpyxl")

    wb = openpyxl.load_workbook(BytesIO(file_bytes), data_only=True)
    ws = wb.active

    # Find header row by scanning for "ccode" in first 10 rows
    header_row_idx = None
    for i, row in enumerate(ws.iter_rows(min_row=1, max_row=10, values_only=True), start=1):
        if any(str(cell).strip().lower() == "ccode" for cell in row if cell is not None):
            header_row_idx = i
            break

    if header_row_idx is None:
        raise ValueError(
            "Kolom 'CCODE' tidak ditemukan di 10 baris pertama. "
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

    # Debug: log detected headers and first 3 rows
    logger.info(f"[DEBUG] Headers found at row {header_row_idx}: {headers}")
    logger.info(f"[DEBUG] Column mapping: {col_map}")
    if rows:
        logger.info(f"[DEBUG] First row: ccode={rows[0].get('CCODE')} good={rows[0].get('GOOD')}")

    return rows


def _validate_row(row_num: int, sku: str, nama_produk: str, harga: Any, good: Any) -> str | None:
    if not sku or not str(sku).strip():
        return "Kolom 'CCODE' kosong. Wajib diisi dengan kode produk unik."
    if not nama_produk or not str(nama_produk).strip():
        return "Kolom 'NAME ITEM' kosong. Wajib diisi dengan nama produk."
    if harga is not None:
        try:
            int(harga)
        except (ValueError, TypeError):
            return f"Kolom 'FIX' berisi '{harga}' bukan angka. Gunakan bilangan bulat."
    if good is not None:
        try:
            good_val = int(good)
            if good_val < 0:
                return f"Kolom 'GOOD' berisi {good_val}. Stok tidak boleh negatif."
        except (ValueError, TypeError):
            return f"Kolom 'GOOD' berisi '{good}' bukan angka. Gunakan bilangan bulat."
    return None


def sync_products_from_excel(
    file_bytes: bytes,
    db: Session,
    current_user: Dict[str, Any],
    file_name: str,
) -> Dict[str, Any]:
    """
    Read product data from an uploaded Excel file and upsert into the database.
    Creates an ImportLog row and persists per-row validation errors with FK
    so the admin Riwayat Error panel can show context (file name, type, time).
    All changes happen inside a single transaction — rollback on any error.
    """
    validation_errors: List[Dict[str, str]] = []
    skipped = 0
    seen_skus: set[str] = set()
    validated_rows: List[Dict[str, Any]] = []

    import_log = ImportLog(
        user_id=current_user.get("user_id"),
        nama=current_user.get("nama"),
        import_type="PRODUCT",
        file_name=file_name,
    )
    db.add(import_log)
    db.flush()

    try:
        raw_rows = _read_excel(file_bytes)
    except Exception as e:
        logger.error(f"Excel read failed: {e}")
        db.add(SyncValidationError(
            import_log_id=import_log.id,
            row_number=0,
            sku="",
            reason=f"Gagal membaca file Excel: {str(e)}",
        ))
        db.commit()
        return {
            "success": False,
            "total_rows": 0,
            "inserted": 0,
            "updated": 0,
            "skipped": 0,
            "errors": [{"row": 0, "sku": "", "reason": f"Gagal membaca file Excel: {str(e)}"}],
            "needs_review": False,
        }

    total_rows = len(raw_rows)

    for row_num, row in enumerate(raw_rows, start=2):
        sku = str(row.get("CCODE") or "").strip()
        nama_produk = str(row.get("NAME ITEM") or "").strip()
        harga_raw = row.get("FIX")
        good_raw = row.get("GOOD")
        kategori = str(row.get("KATEGORI") or "").strip() or None
        satuan = str(row.get("OUM") or "").strip() or None

        nama_supplier = str(row.get("LAST SUPPLIER") or "").strip() or None

        error = _validate_row(row_num, sku, nama_produk, harga_raw, good_raw)
        if error:
            validation_errors.append({"row": row_num, "sku": sku, "reason": error})
            skipped += 1
            if len(validation_errors) <= 5:
                logger.warning(f"[DEBUG] Row {row_num} validation failed: {error} | sku='{sku}' harga='{harga_raw}' good='{good_raw}'")
            continue

        if sku.lower() in seen_skus:
            validation_errors.append({"row": row_num, "sku": sku, "reason": f"SKU '{sku}' muncul lebih dari sekali di file ini. Setiap SKU harus unik."})
            skipped += 1
            continue
        seen_skus.add(sku.lower())

        harga = int(harga_raw) if harga_raw else 0
        stok = int(good_raw) if good_raw else 0
        order_type = _supplier_order_type(nama_supplier)
        validated_rows.append({
            "sku": sku,
            "nama_barang": nama_produk,
            "harga": harga,
            "stok": stok,
            "kategori": kategori,
            "satuan": satuan,
            "nama_supplier": nama_supplier,
            "order_type": order_type,
        })

    inserted = updated = 0
    if validated_rows:
        inserted, updated = _bulk_upsert(db, validated_rows, current_user.get("branch"))

    for err in validation_errors:
        db.add(SyncValidationError(
            import_log_id=import_log.id,
            row_number=err["row"],
            sku=err["sku"],
            reason=err["reason"],
        ))

    import_log.total_rows = total_rows
    import_log.inserted = inserted
    import_log.updated = updated
    import_log.skipped = skipped
    db.commit()

    # Compute needs_review (products where stok_sistem < stok_booking + stok_diterima)
    needs_review_count = db.query(Product).filter(
        Product.stok_sistem < (Product.stok_booking + Product.stok_diterima)
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


def _bulk_upsert(db: Session, rows: List[Dict[str, Any]], branch: str | None = None) -> Tuple[int, int]:
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
             "stok_booking": 0, "stok_diterima": 0,
             "kategori": r.get("kategori"),
             "satuan": r.get("satuan"), "nama_supplier": r.get("nama_supplier"),
             "order_type": r.get("order_type", "REGULER"),
             "branch": branch}
            for r in to_insert
        ])
        db.execute(stmt)
        logger.info(f"[SYNC] Bulk inserted {len(to_insert)} products")

    if to_update:
        def _stock_changed(existing_val, excel_val):
            return (existing_val or 0) != (excel_val or 0)
        changed = [r for r in to_update if _stock_changed(existing[r["sku"]], r["stok"])]
        unchanged = [r for r in to_update if not _stock_changed(existing[r["sku"]], r["stok"])]

        if changed:
            stmt = insert(Product).values([
                {"id": r["sku"], "nama_barang": r["nama_barang"],
                 "harga": r["harga"], "stok_sistem": r["stok"],
                 "stok_booking": 0, "stok_diterima": 0,  # reset saat sync Excel baru
                 "kategori": r.get("kategori"), "satuan": r.get("satuan"),
                 "nama_supplier": r.get("nama_supplier"),
                 "order_type": r.get("order_type", "REGULER"),
                 "branch": branch}
                for r in changed
            ])
            stmt = stmt.on_conflict_do_update(
                index_elements=["id"],
                set_={"nama_barang": stmt.excluded.nama_barang,
                      "harga": stmt.excluded.harga,
                      "stok_sistem": stmt.excluded.stok_sistem,
                      "stok_booking": 0,  # reset saat sync Excel baru
                      "stok_diterima": 0,  # reset saat sync Excel baru
                      "kategori": stmt.excluded.kategori,
                      "satuan": stmt.excluded.satuan,
                      "nama_supplier": stmt.excluded.nama_supplier,
                      "order_type": stmt.excluded.order_type},
            )
            db.execute(stmt)
            for r in changed:
                log_stock_change(
                    db=db, product_id=r["sku"], sumber="SYNC",
                    field_terdampak="stok_sistem",
                    delta=r["stok"] - existing[r["sku"]],
                    nilai_sebelum=existing[r["sku"]], nilai_sesudah=r["stok"],
                    actor_id=None, order_id=None,
                    branch=branch,
                )
        if unchanged:
            stmt = insert(Product).values([
                {"id": r["sku"], "nama_barang": r["nama_barang"],
                 "harga": r["harga"],
                 "kategori": r.get("kategori"), "satuan": r.get("satuan"),
                 "nama_supplier": r.get("nama_supplier"),
                 "order_type": r.get("order_type", "REGULER")}
                for r in unchanged
            ])
            stmt = stmt.on_conflict_do_update(
                index_elements=["id"],
                set_={"nama_barang": stmt.excluded.nama_barang,
                      "harga": stmt.excluded.harga,
                      "kategori": stmt.excluded.kategori,
                      "satuan": stmt.excluded.satuan,
                      "nama_supplier": stmt.excluded.nama_supplier,
                      "order_type": stmt.excluded.order_type},
            )
            db.execute(stmt)
        logger.info(f"[SYNC] Bulk updated {len(to_update)} products ({len(changed)} stock changes)")

    return len(to_insert), len(to_update)
