import os
from typing import List, Tuple, Dict, Any
from sqlalchemy.orm import Session
from sqlalchemy.dialects.postgresql import insert
from uuid import uuid4

try:
    import gspread
    from google.oauth2 import service_account
    GSPREAD_AVAILABLE = True
except ImportError:
    GSPREAD_AVAILABLE = False

from app.models.models import Product
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
    errors: List[Dict[str, str]] = []
    inserted = 0
    updated = 0
    skipped = 0
    seen_skus: set[str] = set()

    try:
        worksheet = _get_worksheet()
        rows = worksheet.get_all_records(expected_headers=SHEETS_COLUMNS)
    except Exception as e:
        return {
            "success": False,
            "total_rows": 0,
            "inserted": 0,
            "updated": 0,
            "skipped": 0,
            "errors": [{"row": 0, "sku": "", "reason": str(e)}],
        }

    total_rows = len(rows)

    for row_num, row in enumerate(rows, start=2):
        sku = str(row.get("SKU", "")).strip()
        nama_barang = str(row.get("Nama Barang", "")).strip()
        harga_raw = row.get("Harga")
        stok_raw = row.get("Stok")

        error = _validate_row(row_num, sku, nama_barang, harga_raw, stok_raw)
        if error:
            errors.append({"row": row_num, "sku": sku, "reason": error})
            skipped += 1
            continue

        if sku.lower() in seen_skus:
            errors.append({"row": row_num, "sku": sku, "reason": "SKU duplikat dalam sheet"})
            skipped += 1
            continue
        seen_skus.add(sku.lower())

        harga = int(harga_raw) if harga_raw else 0
        stok = int(stok_raw) if stok_raw else 0

        existing = db.query(Product).filter(Product.id == sku).first()

        if existing:
            old_stok = existing.stok_sistem or 0
            if old_stok != stok:
                delta = stok - old_stok
                existing.nama_barang = nama_barang
                existing.harga = harga
                existing.stok_sistem = stok

                log_stock_change(
                    db=db,
                    product_id=sku,
                    sumber="SYNC",
                    field_terdampak="stok_sistem",
                    delta=delta,
                    nilai_sebelum=old_stok,
                    nilai_sesudah=stok,
                    actor_id=None,
                    order_id=None,
                )
                updated += 1
            else:
                existing.nama_barang = nama_barang
                existing.harga = harga
                updated += 1
        else:
            new_product = Product(
                id=sku,
                nama_barang=nama_barang,
                harga=harga,
                stok_sistem=stok,
                stok_booking=0,
            )
            db.add(new_product)
            log_stock_change(
                db=db,
                product_id=sku,
                sumber="SYNC",
                field_terdampak="stok_sistem",
                delta=stok,
                nilai_sebelum=0,
                nilai_sesudah=stok,
                actor_id=None,
                order_id=None,
            )
            inserted += 1

    db.commit()

    return {
        "success": True,
        "total_rows": total_rows,
        "inserted": inserted,
        "updated": updated,
        "skipped": skipped,
        "errors": errors,
    }


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
        print("Satu baris pesanan baru berhasil ditambahkan ke Google Sheets.")
        return True
    except Exception as e:
        print(f"Gagal append ke sheets: {e}")
        return False


def update_order_status_in_sheets(order_id: str, new_status: str):
    try:
        worksheet = get_sheet()
        kolom_id = worksheet.col_values(1)
        if str(order_id) in kolom_id:
            baris_ke = kolom_id.index(str(order_id)) + 1
            worksheet.update_cell(baris_ke, 4, new_status)
            print(f"Status pesanan di baris {baris_ke} berhasil diperbarui menjadi {new_status}.")
            return True
        else:
            print(f"ID Order {order_id} tidak ditemukan di Google Sheets.")
            return False
    except Exception as e:
        print(f"Gagal update status di sheets: {e}")
        return False
