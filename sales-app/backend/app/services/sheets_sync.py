import logging
import os
import re
from io import BytesIO
from typing import List, Tuple, Dict, Any
from sqlalchemy import func
from sqlalchemy.orm import Session
from sqlalchemy.dialects.postgresql import insert

logger = logging.getLogger(__name__)

try:
    import openpyxl
    OPENPYXL_AVAILABLE = True
except ImportError:
    OPENPYXL_AVAILABLE = False

from app.models.models import Product, SyncValidationError, ImportLog, Supplier
from app.services.stock_logger import log_stock_change


EXCEL_COLUMNS = ["CCODE", "KATEGORI", "NAME ITEM", "GOOD", "OUM", "FIX", "LAST SUPPLIER"]


def normalize_supplier_name(raw: str | None) -> str | None:
    """Normalize supplier name string: strip zero-width & invisible unicode chars,
    collapse whitespace, trim, uppercase."""
    if not raw:
        return None
    # Strip ZWSP, NBSP, BOM, soft hyphen, etc.
    cleaned = re.sub(r"[\u200b-\u200d\ufeff\xa0]", "", raw)
    # Collapse multiple whitespace
    cleaned = re.sub(r"\s+", " ", cleaned).strip().upper()
    return cleaned if cleaned else None


def _get_supplier_order_type_map(db: Session, raw_suppliers: set[str]) -> dict[str, str]:
    """Map normalized supplier names to order_type.
    Looks up in DB `suppliers` table first. For unknown suppliers, auto-inserts them
    with order_type='REGULER' into `suppliers` table."""
    norm_set = {s for s in (normalize_supplier_name(x) for x in raw_suppliers) if s}
    if not norm_set:
        return {}

    existing = db.query(Supplier).filter(Supplier.name.in_(norm_set)).all()
    out = {s.name: s.order_type for s in existing}

    missing = norm_set - set(out.keys())
    for name in missing:
        sup = Supplier(name=name, is_active=True, order_type="REGULER")
        db.add(sup)
        out[name] = "REGULER"

    if missing:
        db.flush()

    return out


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


def _validate_row(
    row_num: int, sku: str, nama_produk: str, harga: Any, good: Any, supplier: str | None
) -> str | None:
    if not sku or not str(sku).strip():
        return "Kolom 'CCODE' kosong. Wajib diisi dengan kode produk unik."
    if not nama_produk or not str(nama_produk).strip():
        return "Kolom 'NAME ITEM' kosong. Wajib diisi dengan nama produk."
    if not supplier:
        return "Kolom 'LAST SUPPLIER' kosong. Produk tanpa supplier ditolak."
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
        branch=current_user.get("branch"),
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

    # Collect non-empty raw supplier names to bulk-query order_type mapping from DB
    raw_supplier_set = {
        str(row.get("LAST SUPPLIER") or "").strip()
        for row in raw_rows
        if str(row.get("LAST SUPPLIER") or "").strip()
    }
    supplier_ot_map = _get_supplier_order_type_map(db, raw_supplier_set)

    for row_num, row in enumerate(raw_rows, start=2):
        sku = str(row.get("CCODE") or "").strip()
        nama_produk = str(row.get("NAME ITEM") or "").strip()
        harga_raw = row.get("FIX")
        good_raw = row.get("GOOD")
        kategori = str(row.get("KATEGORI") or "").strip() or None
        satuan = str(row.get("OUM") or "").strip() or None

        nama_supplier_norm = normalize_supplier_name(row.get("LAST SUPPLIER"))

        error = _validate_row(row_num, sku, nama_produk, harga_raw, good_raw, nama_supplier_norm)
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
        order_type = supplier_ot_map.get(nama_supplier_norm) if nama_supplier_norm else None
        cabang = current_user.get("branch") or ""
        validated_rows.append({
            "sku": sku,
            "nama_barang": nama_produk,
            "harga": harga,
            "stok": stok,
            "kategori": kategori,
            "satuan": satuan,
            "nama_supplier": nama_supplier_norm,
            "order_type": order_type,
            "branch": cabang,
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
    Bulk upsert using PostgreSQL ON CONFLICT DO UPDATE on (id, branch).
    Returns (inserted_count, updated_count).
    Same SKU can exist in different branches.
    """
    # Query existing products by (sku, branch) — include stok_booking & stok_diterima
    skus = [r["sku"] for r in rows]
    branch_filter = branch if branch else ""
    existing = {
        (p.id, p.branch): {
            "stok_sistem": p.stok_sistem,
            "stok_booking": p.stok_booking,
            "stok_diterima": p.stok_diterima,
            "nama_supplier": p.nama_supplier,
            "order_type": p.order_type,
        }
        for p in db.query(Product).filter(
            Product.id.in_(skus),
            Product.branch == branch_filter,
        ).with_entities(
            Product.id, Product.branch, Product.stok_sistem, Product.stok_booking,
            Product.stok_diterima, Product.nama_supplier, Product.order_type,
        ).all()
    }

    to_insert = [r for r in rows if (r["sku"], branch_filter) not in existing]
    to_update = [r for r in rows if (r["sku"], branch_filter) in existing]

    if to_insert:
        stmt = insert(Product).values([
            {"id": r["sku"], "nama_barang": r["nama_barang"],
             "harga": r["harga"], "stok_sistem": r["stok"],
             "stok_booking": 0, "stok_diterima": 0,
             "kategori": r.get("kategori"),
             "satuan": r.get("satuan"), "nama_supplier": r.get("nama_supplier"),
             "order_type": r.get("order_type") or "REGULER",
             "branch": branch}
            for r in to_insert
        ])
        db.execute(stmt)
        logger.info(f"[SYNC] Bulk inserted {len(to_insert)} products")

    if to_update:
        def _stock_changed(existing_val, excel_val):
            return (existing_val or 0) != (excel_val or 0)
        changed = [r for r in to_update if _stock_changed(existing[(r["sku"], branch_filter)]["stok_sistem"], r["stok"])]
        unchanged = [r for r in to_update if not _stock_changed(existing[(r["sku"], branch_filter)]["stok_sistem"], r["stok"])]

        if changed:
            # Preserve existing stok_booking (and stok_diterima) — don't reset during sync
            insert_vals = []
            for r in changed:
                ex = existing[(r["sku"], branch_filter)]
                insert_vals.append({
                    "id": r["sku"],
                    "nama_barang": r["nama_barang"],
                    "harga": r["harga"],
                    "stok_sistem": r["stok"],
                    "stok_booking": ex["stok_booking"],
                    "stok_diterima": 0,  # reset — Excel GOOD sudah neto
                    "kategori": r.get("kategori"),
                    "satuan": r.get("satuan"),
                    # Resolve against existing row: order_type is NOT NULL and Postgres
                    # checks it before ON CONFLICT resolution.
                    "nama_supplier": r.get("nama_supplier") or ex["nama_supplier"],
                    "order_type": r.get("order_type") or ex["order_type"],
                    "branch": branch,
                })

            stmt = insert(Product).values(insert_vals)
            set_dict = {
                "nama_barang": stmt.excluded.nama_barang,
                "harga": stmt.excluded.harga,
                "stok_sistem": stmt.excluded.stok_sistem,
                "stok_booking": stmt.excluded.stok_booking,
                "stok_diterima": 0,
                "kategori": stmt.excluded.kategori,
                "satuan": stmt.excluded.satuan,
                "branch": stmt.excluded.branch,
            }
            # Only overwrite nama_supplier and order_type if Excel provided non-empty value
            set_dict["nama_supplier"] = func.coalesce(stmt.excluded.nama_supplier, Product.nama_supplier)
            set_dict["order_type"] = func.coalesce(stmt.excluded.order_type, Product.order_type)

            stmt = stmt.on_conflict_do_update(
                index_elements=["id", "branch"],
                set_=set_dict,
            )
            db.execute(stmt)
            for r in changed:
                ex = existing[(r["sku"], branch_filter)]
                log_stock_change(
                    db=db, product_id=r["sku"], sumber="SYNC",
                    field_terdampak="stok_sistem",
                    delta=r["stok"] - ex["stok_sistem"],
                    nilai_sebelum=ex["stok_sistem"], nilai_sesudah=r["stok"],
                    actor_id=None, order_id=None,
                    branch=branch,
                )
                if ex["stok_diterima"] > 0:
                    log_stock_change(
                        db=db, product_id=r["sku"], sumber="SYNC",
                        field_terdampak="stok_diterima",
                        delta=-ex["stok_diterima"],
                        nilai_sebelum=ex["stok_diterima"], nilai_sesudah=0,
                        actor_id=None, order_id=None,
                        branch=branch,
                    )
        if unchanged:
            insert_vals = []
            for r in unchanged:
                ex = existing[(r["sku"], branch_filter)]
                insert_vals.append({
                    "id": r["sku"],
                    "nama_barang": r["nama_barang"],
                    "harga": r["harga"],
                    "kategori": r.get("kategori"),
                    "satuan": r.get("satuan"),
                    # Resolve against existing row: order_type is NOT NULL and Postgres
                    # checks it before ON CONFLICT resolution.
                    "nama_supplier": r.get("nama_supplier") or ex["nama_supplier"],
                    "order_type": r.get("order_type") or ex["order_type"],
                    "branch": branch,
                })

            stmt = insert(Product).values(insert_vals)
            set_dict = {
                "nama_barang": stmt.excluded.nama_barang,
                "harga": stmt.excluded.harga,
                "kategori": stmt.excluded.kategori,
                "satuan": stmt.excluded.satuan,
            }
            set_dict["nama_supplier"] = func.coalesce(stmt.excluded.nama_supplier, Product.nama_supplier)
            set_dict["order_type"] = func.coalesce(stmt.excluded.order_type, Product.order_type)

            stmt = stmt.on_conflict_do_update(
                index_elements=["id", "branch"],
                set_=set_dict,
            )
            db.execute(stmt)
        logger.info(f"[SYNC] Bulk updated {len(to_update)} products ({len(changed)} stock changes)")

    return len(to_insert), len(to_update)
