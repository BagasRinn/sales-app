import logging
import os
from typing import List, Tuple, Dict, Any
from sqlalchemy.orm import Session
from sqlalchemy.dialects.postgresql import insert
from uuid import uuid4

logger = logging.getLogger(__name__)

try:
    import gspread
    from google.oauth2 import service_account
    GSPREAD_AVAILABLE = True
except ImportError:
    GSPREAD_AVAILABLE = False

from app.models.models import Product, SyncValidationError, SyncValidationError
from app.services.stock_logger import log_stock_change

BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CREDENTIALS_PATH = os.path.join(BASE_DIR, "credentials.json")
SPREADSHEET_NAME = os.getenv("GOOGLE_SHEETS_NAME", "Test-sheets")

SHEETS_COLUMNS = ["SKU", "Nama Barang", "Harga", "Stok"]


def _get_worksheet():
    if not GSPREAD_AVAILABLE:
        raise RuntimeError("gspread library not installed")

    scope = ["https://www.googleapis.com/auth/spreadsheets.readonly"]
    credentials = service_account.Credentials.from_service_account_file(
        CREDENTIALS_PATH, scopes=scope
    )
    gc = gspread.Client(auth=credentials)
    sh = gc.open(SPREADSHEET_NAME)
    return sh.sheet1


def _validate_row(row_num: int, sku: str, nama_barang: str, harga: Any, stok: Any) -> str | None:
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


def sync_products_from_sheets(db: Session) -> Dict[str, Any]:
    validation_errors: List[Dict[str, str]] = []
    skipped = 0
    seen_skus: set[str] = set()
    validated_rows: List[Dict[str, Any]] = []

    try:
        worksheet = _get_worksheet()
        rows = worksheet.get_all_records(expected_headers=SHEETS_COLUMNS)
    except Exception as e:
        logger.error(f"Google Sheets fetch failed: {e}")
        return {
            "success": False,
            "total_rows": 0,
            "inserted": 0,
            "updated": 0,
            "skipped": 0,
            "errors": [{"row": 0, "sku": "", "reason": str(e)}],
            "needs_review": False,
        }

    total_rows = len(rows)

    for row_num, row in enumerate(rows, start=2):
        sku = str(row.get("SKU", "")).strip()
        nama_barang = str(row.get("Nama Barang", "")).strip()
        harga_raw = row.get("Harga")
        stok_raw = row.get("Stok")

        error = _validate_row(row_num, sku, nama_barang, harga_raw, stok_raw)
        if error:
            validation_errors.append({"row": row_num, "sku": sku, "reason": error})
            skipped += 1
            continue

        if sku.lower() in seen_skus:
            validation_errors.append({"row": row_num, "sku": sku, "reason": "SKU duplikat dalam sheet"})
            skipped += 1
            continue
        seen_skus.add(sku.lower())

        harga = int(harga_raw) if harga_raw else 0
        stok = int(stok_raw) if stok_raw else 0
        validated_rows.append({
            "sku": sku,
            "nama_barang": nama_barang,
            "harga": harga,
            "stok": stok,
        })

    inserted = updated = 0
    if validated_rows:
        inserted, updated = _bulk_upsert(db, validated_rows)

    # Persist validation errors so /sync/errors can return them later
    for err in validation_errors:
        db.merge(SyncValidationError(
            id=str(uuid4()),
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
    Reads existing SKUs in one query, then issues two statements (insert / update).
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
             "harga": r["harga"], "stok_sistem": r["stok"], "stok_booking": 0}
            for r in to_insert
        ])
        db.execute(stmt)
        logger.info(f"[SYNC] Bulk inserted %d products", len(to_insert))

    if to_update:
        # Track how many actually had a stock change (for audit)
        changed = [r for r in to_update if existing[r["sku"]] != r["stok"]]
        unchanged = [r for r in to_update if existing[r["sku"]] == r["stok"]]

        if changed:
            stmt = insert(Product).values([
                {"id": r["sku"], "nama_barang": r["nama_barang"],
                 "harga": r["harga"], "stok_sistem": r["stok"]}
                for r in changed
            ])
            stmt = stmt.on_conflict_do_update(
                index_elements=["id"],
                set_={"nama_barang": stmt.excluded.nama_barang,
                      "harga": stmt.excluded.harga,
                      "stok_sistem": stmt.excluded.stok_sistem},
            )
            db.execute(stmt)
            # Audit log for stock changes
            for r in changed:
                log_stock_change(
                    db=db, product_id=r["sku"], sumber="SYNC",
                    field_terdampak="stok_sistem",
                    delta=r["stok"] - existing[r["sku"]],
                    nilai_sebelum=existing[r["sku"]], nilai_sesudah=r["stok"],
                    actor_id=None, order_id=None,
                )
        if unchanged:
            # Name/price only update
            stmt = insert(Product).values([
                {"id": r["sku"], "nama_barang": r["nama_barang"], "harga": r["harga"]}
                for r in unchanged
            ])
            stmt = stmt.on_conflict_do_update(
                index_elements=["id"],
                set_={"nama_barang": stmt.excluded.nama_barang,
                      "harga": stmt.excluded.harga},
            )
            db.execute(stmt)
        logger.info(f"[SYNC] Bulk updated %d products (%d stock changes)", len(to_update), len(changed))

    return len(to_insert), len(to_update)


# ==================== ORDER SHEETS SYNC (existing logic) ====================

def get_sheet():
    if not GSPREAD_AVAILABLE:
        raise RuntimeError("gspread library not installed")
    scope = ["https://www.googleapis.com/auth/spreadsheets"]
    credentials = service_account.Credentials.from_service_account_file(
        CREDENTIALS_PATH, scopes=scope
    )
    gc = gspread.Client(auth=credentials)
    sh = gc.open(SPREADSHEET_NAME)
    return sh.sheet1


def append_new_order_to_sheets(order_id: str, db: Session):
    try:
        worksheet = get_sheet()
        from app.models.models import Order
        order = db.query(Order).filter(Order.id == order_id).first()
        if not order:
            return False

        total = 0
        for item in order.items:
            if item.product:
                total += item.qty * (item.product.harga or 0)

        baris_baru = [
            str(order.id),
            str(order.sales_id),
            str(total),
            str(order.status),
            str(order.created_at),
            str(order.expired_at),
        ]
        worksheet.append_row(baris_baru)
        logger.info("Satu baris pesanan baru berhasil ditambahkan ke Google Sheets.")
        return True
    except Exception as e:
        logger.error(f"Gagal append ke sheets: {e}")
        return False


def update_order_status_in_sheets(order_id: str, new_status: str):
    try:
        worksheet = get_sheet()
        kolom_id = worksheet.col_values(1)
        if str(order_id) in kolom_id:
            baris_ke = kolom_id.index(str(order_id)) + 1
            worksheet.update_cell(baris_ke, 4, new_status)
            logger.info(f"Status pesanan di baris {baris_ke} berhasil diperbarui menjadi {new_status}.")
            return True
        else:
            logger.warning(f"ID Order {order_id} tidak ditemukan di Google Sheets.")
            return False
    except Exception as e:
        logger.error(f"Gagal update status di sheets: {e}")
        return False
