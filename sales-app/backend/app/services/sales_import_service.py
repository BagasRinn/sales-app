"""Import laporan penjualan dari file Excel (template sistem utama).

Membaca file .xlsx dengan kolom laporan penjualan:
- Trans No, Penjualan (tanggal), Kode (customer), Nama Pelanggan, Channel,
  Kategori, Group, Area, Alamat, Kode Item, Nama Item, Qty, Satuan Jual, Qtyi,
  Satuani, Diskon, N. Jual - Discount, Total Hela Harga Jual (Total Harga Jual),
  Kode Sales, Sales, Supplier.

Semua field keuangan disimpan apa adanya dari file: `net_per_unit` (N. Jual -
Discount per satuan) dan `total_amount` (Total Harga Jual). Status pada file
(bermaksud posted) tidak diproses.
"""
import logging
import re
from io import BytesIO
from typing import Any, Dict, List, Optional
from datetime import date, datetime

from sqlalchemy.orm import Session

from app.models.models import ImportLog, ImportedSale, SyncValidationError

logger = logging.getLogger(__name__)

try:
    import openpyxl
    OPENPYXL_AVAILABLE = True
except ImportError:
    OPENPYXL_AVAILABLE = False

IMPORT_TYPE_SALES = "SALES"


def _norm_header(value: Any) -> str:
    """Normalize header cell: lowercase, non-alnum -> space, collapse space."""
    if value is None:
        return ""
    s = str(value).replace("\ufeff", "").strip().lower()
    s = re.sub(r"[^a-z0-9]+", " ", s)
    return " ".join(s.split())


# Canonical field -> accepted normalized aliases.
SALES_FIELD_ALIASES: Dict[str, List[str]] = {
    "trans_no": ["trans no", "transno", "transaksi", "transaction", "trans penjualan"],
    "sale_date": ["penjualan", "tanggal", "tarikh", "date", "created", "order date", "created date"],
    "customer_kode": ["kode pelanggan", "kodecustomer", "kode customer", "kode", "customer kode"],
    "customer_nama": ["nama pelanggan", "namapelanggan", "nama toko", "customer", "nama pelanggan toko"],
    "channel": ["channel", "tipe langganan", "tipelangganan", "langganan", "subscription", "tipe langganan "],
    "kategori": ["kategori", "category"],
    "customer_group": ["group", "grup", "grouping"],
    "area": ["area", "rayon", "kode area", "areacustomer", "wilayah", "area rayon"],
    "alamat": ["alamat", "address", "alamat pelanggan", "alamat toko"],
    "product_kode": ["kode item", "kodeitem", "item kode", "sku", "kodeproduk", "kode barang", "itemcode"],
    "product_nama": ["nama item", "namaitem", "item name", "namaproduk", "nama barang", "itemname"],
    "qty": ["qty", "quantity", "jumlah", "qty sold", "jumlah terjual"],
    "satuan_jual": ["satuan jual", "satuanjual", "jual", "selling unit", "satuan"],
    "qtyi": ["qtyi", "qty in", "qtyin", "base qty", "qty base"],
    "satuani": ["satuani", "satuan i", "satuanin", "unit i", "base unit", "satuanbase"],
    "diskon": ["diskon", "discount"],
    "net_per_unit": ["n jual discount", "njual discount", "jual discount", "net jual", "net jual discount", "n jual"],
    "total_amount": ["total harga jual", "total hela harga jual", "total jual", "total harga", "total penjualan", "total revenue", "total amount", "total"],
    "sales_kode": ["kode sales", "kodesales", "sales kode", "kode salesman", "salesman kode"],
    "sales_nama": ["sales", "nama sales", "namasales", "salesman", "nama salesman", "nama sales man"],
    "supplier": ["supplier", "last supplier", "namasupplier", "supplier nama"],
}


def _resolve_field(norm: str) -> Optional[str]:
    n = norm.strip()
    if not n:
        return None
    for field, aliases in SALES_FIELD_ALIASES.items():
        for alias in aliases:
            if n == alias or n.startswith(alias):
                return field
    return None


def _find_header_row(ws) -> int:
    """Cari baris header laporan penjualan di 15 baris pertama."""
    for i, row in enumerate(ws.iter_rows(min_row=1, max_row=15, values_only=True), start=1):
        norms = [_norm_header(c) for c in row]
        has_sale_marker = any(n == "penjualan" or n.startswith("trans") for n in norms if n)
        if has_sale_marker:
            return i
    raise ValueError("Header laporan penjualan tidak ditemukan di 15 baris pertama.")


def _read_sales_excel(file_bytes: bytes) -> List[Dict[str, Any]]:
    """Parse file .xlsx laporan penjualan ke list of row dicts (field -> value)."""
    if not OPENPYXL_AVAILABLE:
        raise RuntimeError("openpyxl library not installed. Run: pip install openpyxl")

    wb = openpyxl.load_workbook(BytesIO(file_bytes), data_only=True)
    ws = wb.active
    header_row_idx = _find_header_row(ws)

    headers = [_norm_header(c) for c in next(ws.iter_rows(min_row=header_row_idx, max_row=header_row_idx, values_only=True))]
    col_map: Dict[str, int] = {}
    for field, aliases in SALES_FIELD_ALIASES.items():
        col_map[field] = -1
        for idx, h in enumerate(headers):
            if h and any(h == alias or h.startswith(alias) for alias in aliases):
                col_map[field] = idx
                break

    rows: List[Dict[str, Any]] = []
    for row in ws.iter_rows(min_row=header_row_idx + 1, values_only=True):
        if all(cell is None for cell in row):
            continue
        row_dict: Dict[str, Any] = {}
        for field, idx in col_map.items():
            row_dict[field] = row[idx] if idx >= 0 and idx < len(row) else None
        rows.append(row_dict)

    logger.info(f"[SALES-IMPORT] headers resolved: {col_map}")
    return rows


def _to_int(value: Any) -> Optional[int]:
    if value is None:
        return None
    if isinstance(value, bool):
        return None
    if isinstance(value, (int, float)):
        return int(value)
    s = str(value).strip()
    if not s:
        return None
    try:
        return int(float(s))
    except (ValueError, TypeError):
        return None


def _to_date(value: Any) -> Optional[date]:
    if value is None:
        return None
    if isinstance(value, datetime):
        return value.date()
    if isinstance(value, date):
        return value
    s = str(value).strip()
    if not s:
        return None
    for fmt in ("%Y-%m-%d", "%d/%m/%Y", "%m/%d/%Y", "%Y/%m/%d", "%d-%m-%Y"):
        try:
            return datetime.strptime(s, fmt).date()
        except ValueError:
            continue
    return None


def _clean_str(value: Any) -> Optional[str]:
    if value is None:
        return None
    s = str(value).strip()
    return s if s else None


def import_sales_from_excel(
    file_bytes: bytes,
    db: Session,
    current_user: Dict[str, Any],
    file_name: str,
) -> Dict[str, Any]:
    """Import baris laporan penjualan dari file Excel → tabel imported_sales."""
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
    inserted = 0
    rows = []

    try:
        raw_rows = _read_sales_excel(file_bytes)
    except Exception as e:
        logger.error(f"[SALES-IMPORT] Excel read failed: {e}")
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
            continue

        inserted += 1
        rows.append(ImportedSale(
            import_log_id=import_log.id,
            branch=current_user.get("branch") or None,
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
        ))

    import_log.total_rows = total_rows
    import_log.inserted = inserted
    import_log.skipped = skipped
    db.add_all(rows)
    db.commit()

    return {
        "success": True,
        "total_rows": total_rows,
        "inserted": inserted,
        "updated": 0,
        "skipped": skipped,
        "errors": validation_errors,
    }
