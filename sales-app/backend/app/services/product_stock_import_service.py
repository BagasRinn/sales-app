"""Import & ringkasan snapshot stok produk (Value Good) dari file Excel.

Berbeda dari `/products/import-excel` (sinkronisasi master produk ke tabel
`products`), modul ini menyimpan snapshot stok ke tabel terpisah
`imported_product_stocks` untuk analisa Value Good di dashboard analytics:

* `POST /product-stocks/import-excel` — global MANAGER only; snapshot per
  (bulan dari month picker, cabang dari kolom `Cabang` file). Re-import
  bulan yang sama untuk cabang yang sama = replace penuh.
* `GET  /product-stocks/summary` — agregasi Value Good per produk/supplier/
  divisi untuk scope pemanggil.

Value Good per item diambil langsung dari kolom GOOD AMOUNT file (value
barang berstatus baik untuk dijual), bukan dihitung sistem.
"""
from __future__ import annotations

import logging
from typing import Any, Dict, List, Optional, Tuple

from fastapi import HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.core.branch import is_valid_branch
from app.models.models import ImportLog, ImportedProductStock
from app.services.sales_import_service import (
    _add_error,
    _clean_identifier,
    _clean_str,
    _detect_excel_format,
    _norm_header,
    _read_xls_matrices,
    _read_xlsx_matrices,
    _resolve_row_branch,
    _to_int,
)
from app.services.sales_import_versions import (
    GLOBAL_SCOPE,
    parse_month,
)

logger = logging.getLogger(__name__)

IMPORT_TYPE_PRODUCT_STOCK = "PRODUCT_STOCK"

# Canonical field -> accepted normalized header aliases. More specific
# aliases first so "kode barang" never steals from "kode cabang".
# Catatan pemetaan file Master Stock: kode produk = kolom CCODE; Mother SKU
# hanya untuk generalisasi (kunci penggabung), bukan kode produk.
STOCK_FIELD_ALIASES: Dict[str, List[str]] = {
    "branch": ["kode cabang", "cabang", "branch"],
    "product_kode": [
        "ccode", "kode barang", "kodebarang", "kode item", "kodeitem",
        "item code",
    ],
    "product_nama": [
        "nama barang", "namabarang", "nama item", "namaitem", "item name",
        "nama produk", "deskripsi", "description",
    ],
    "mother_sku": ["mother sku", "mothersku", "sku induk", "kode induk", "parent sku"],
    "divisi": ["divisi", "devisi", "division"],
    "supplier": ["supplier", "last supplier", "nama supplier", "namasupplier"],
    "satuan": ["satuan"],
    "stok_good": ["stok good", "stokgood", "stock good", "good", "stok baik"],
    "good_amount": [
        "good amount", "goodamount", "value good", "nilai good",
        "nilai stock good", "amount good",
    ],
}

# Kolom wajib: tanpa salah satu dari ini impor ditolak dengan pesan jelas.
REQUIRED_STOCK_FIELDS = ("branch", "product_kode", "good_amount")

_MAX_HEADER_SCAN_ROWS = 10


def _score_stock_header_row(row: List[Any]) -> Tuple[int, Dict[str, int]]:
    """Skor baris header stok: jumlah field canonical yang ketemu."""
    headers = [_norm_header(c) for c in row]
    col_map: Dict[str, int] = {}
    for field, aliases in STOCK_FIELD_ALIASES.items():
        for idx, header in enumerate(headers):
            if header in aliases:
                col_map[field] = idx
                break
    return len(col_map), col_map


def _find_stock_header_row_index(rows: List[List[Any]]) -> int:
    """Baris header stok = baris dengan skor field canonical tertinggi."""
    best: Optional[Tuple[int, int]] = None
    for i, row in enumerate(rows[:_MAX_HEADER_SCAN_ROWS]):
        score, fields = _score_stock_header_row(row)
        has_identity = bool({"branch", "product_kode"} <= set(fields))
        if has_identity and score > (best[0] if best else 0):
            best = (score, i)
    if best is None:
        raise ValueError("Header laporan stok tidak ditemukan.")
    return best[1]


def _read_stock_excel(
    file_bytes: bytes, file_name: Optional[str] = None
) -> List[Dict[str, Any]]:
    """Parse file .xlsx/.xls laporan stok ke list of row dicts.

    Semua sheet diperiksa; sheet dengan field terbanyak + baris data
    terbanyak dipakai (pola `_read_sales_excel`).
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
            header_row_idx = _find_stock_header_row_index(matrix)
        except ValueError:
            continue
        data_rows = sum(
            1
            for row in matrix[header_row_idx + 1:]
            if any(c is not None and str(c).strip() for c in row)
        )
        if data_rows == 0:
            continue
        score, _ = _score_stock_header_row(matrix[header_row_idx])
        candidates.append((score, data_rows, sheet_name, matrix, header_row_idx))

    if not candidates:
        raise ValueError(
            "Header laporan stok tidak ditemukan. Kolom wajib: Cabang, "
            "Kode Barang, Good Amount."
        )

    candidates.sort(key=lambda item: (item[0], item[1]), reverse=True)
    _, _, sheet_name, matrix, header_row_idx = candidates[0]
    _, col_map = _score_stock_header_row(matrix[header_row_idx])

    missing = [f for f in REQUIRED_STOCK_FIELDS if f not in col_map]
    if missing:
        raise ValueError(
            "Kolom wajib tidak ditemukan di file: " + ", ".join(missing)
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
        rows.append(row_dict)

    logger.info(
        "[PRODUCT-STOCK-IMPORT] format=%s sheet=%s header_row=%s fields=%s",
        excel_format,
        sheet_name,
        header_row_idx + 1,
        sorted(col_map),
    )
    return rows


def import_product_stock_from_excel(
    file_bytes: bytes,
    file_name: Optional[str],
    month: str,
    db: Session,
    current_user: Dict[str, Any],
) -> Dict[str, Any]:
    """Import snapshot stok: replace penuh per (month, cabang dari file).

    Hanya global MANAGER (divalidasi di endpoint). Satu file boleh berisi
    banyak cabang; setiap cabang yang tersentuh di-replace untuk bulan itu.
    Semua perubahan dalam satu transaksi (ImportLog + baris stok).
    """
    normalized_month, _, _ = parse_month(month)

    import_log = ImportLog(
        user_id=current_user.get("user_id"),
        nama=current_user.get("nama"),
        import_type=IMPORT_TYPE_PRODUCT_STOCK,
        file_name=file_name,
        branch=current_user.get("branch"),
    )
    db.add(import_log)
    db.flush()

    try:
        rows = _read_stock_excel(file_bytes, file_name)
    except ValueError as exc:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(exc))

    validation_errors: List[Dict[str, Any]] = []
    skipped = 0
    total_rows = 0
    # (branch, ccode) -> baris; duplikat CCODE persis: baris terakhir menang.
    by_ccode: Dict[Tuple[str, str], Dict[str, Any]] = {}
    # (branch, grup generalisasi) -> baris agregat.
    by_key: Dict[Tuple[str, str], Dict[str, Any]] = {}
    branches_touched: set[str] = set()

    for row_num, row in enumerate(rows, start=2):
        total_rows += 1
        branch = _resolve_row_branch(row.get("branch"))
        # "Kode barang" di laporan stok bisa berupa deskripsi panjang, dan
        # kunci grup bisa berupa mother_sku; sampai 200 karakter.
        product_kode = _clean_identifier(row.get("product_kode"), 200)
        if not branch or not product_kode:
            skipped += 1
            _add_error(
                validation_errors,
                row_num,
                row,
                "Cabang atau Kode Barang kosong/tidak dikenal",
            )
            continue
        if not is_valid_branch(branch):
            # Berbeda dari impor penjualan (yang menyimpan cabang asing untuk
            # global manager), snapshot stok strict: cabang tak dikenal = skip
            # supaya tidak ada grup hantu di analisa Value Good.
            skipped += 1
            _add_error(
                validation_errors,
                row_num,
                row,
                f"Cabang tidak dikenal: {branch}",
            )
            continue

        good_amount = _to_int(row.get("good_amount"))
        if good_amount is None:
            # Sel kosong -> 0 (stok tetap tercatat); teks bukan angka -> skip.
            raw = _clean_str(row.get("good_amount"))
            if raw:
                skipped += 1
                _add_error(
                    validation_errors,
                    row_num,
                    row,
                    "Good Amount bukan angka valid",
                )
                continue
            good_amount = 0

        mother_sku = _clean_identifier(row.get("mother_sku"), 100)
        group_key = mother_sku or product_kode
        branches_touched.add(branch)
        # Unik per CCODE (item fisik); duplikat CCODE persis = baris terakhir
        # menang. Baris dengan CCODE berbeda tapi Mother SKU sama adalah item
        # berbeda dalam satu grup generalisasi -> value dijumlahkan.
        by_ccode[(branch, product_kode)] = {
            "group_key": group_key,
            "product_nama": _clean_str(row.get("product_nama")) or "",
            "mother_sku": mother_sku,
            "divisi": _clean_str(row.get("divisi")),
            "supplier": _clean_str(row.get("supplier")),
            "satuan": _clean_str(row.get("satuan")),
            "stok_good": _to_int(row.get("stok_good")) or 0,
            "good_amount": good_amount,
            "branch": branch,
        }

    # Agregasi ke grup generalisasi (mother_sku bila ada, else CCODE).
    for ccode_key, item in by_ccode.items():
        branch = item["branch"]
        group = by_key.get((branch, item["group_key"]))
        if group is None:
            by_key[(branch, item["group_key"])] = {
                "branch": branch,
                "month": normalized_month,
                "product_kode": item["group_key"],
                "product_nama": item["product_nama"],
                "mother_sku": item["mother_sku"],
                "divisi": item["divisi"],
                "supplier": item["supplier"],
                "satuan": item["satuan"],
                "stok_good": item["stok_good"],
                "good_amount": item["good_amount"],
            }
        else:
            # Grup generalisasi: jumlahkan value & stok; label/kolom lain
            # dipertahankan dari entri pertama (urutan file).
            group["stok_good"] += item["stok_good"]
            group["good_amount"] += item["good_amount"]

    if not by_key:
        db.rollback()
        raise HTTPException(
            status_code=400,
            detail=(
                "Tidak ada baris stok valid untuk diimpor. "
                f"Total baris dibaca: {total_rows}, dilewati: {skipped}."
            ),
        )

    # Replace penuh per (month, cabang) yang tersentuh.
    for branch in sorted(branches_touched):
        db.query(ImportedProductStock).filter(
            ImportedProductStock.branch == branch,
            ImportedProductStock.month == normalized_month,
        ).delete(synchronize_session=False)

    inserted = 0
    for row in by_key.values():
        db.add(ImportedProductStock(**row, import_log_id=import_log.id))
        inserted += 1

    import_log.total_rows = total_rows
    import_log.inserted = inserted
    import_log.skipped = skipped
    db.commit()

    per_branch = {
        branch: sum(1 for (b, _key) in by_key if b == branch)
        for branch in sorted(branches_touched)
    }
    total_good_amount = sum(row["good_amount"] for row in by_key.values())
    return {
        "success": True,
        "month": normalized_month,
        "total_rows": total_rows,
        "inserted": inserted,
        "skipped": skipped,
        "branches": per_branch,
        "total_good_amount": total_good_amount,
        "errors": validation_errors,
    }


def read_product_stock_summary(
    db: Session,
    scope: str,
    month: str,
    limit: int = 100,
) -> Dict[str, Any]:
    """Agregasi Value Good untuk satu (scope, month): total + top-N per dimensi.

    ``scope`` = kode cabang atau ``GLOBAL``. Global menjumlahkan semua cabang.
    Agregasi langsung GROUP BY (volume baris stok kecil), tanpa precompute.
    """
    normalized_month, _, _ = parse_month(month)
    base_filter = [ImportedProductStock.month == normalized_month]
    if scope != GLOBAL_SCOPE:
        base_filter.append(ImportedProductStock.branch == scope)

    def _bucket(column, limit_: int) -> List[Dict[str, Any]]:
        rows = (
            db.query(
                column.label("dim_key"),
                func.max(
                    func.coalesce(ImportedProductStock.product_nama, "")
                ).label("dim_label"),
                func.coalesce(func.sum(ImportedProductStock.good_amount), 0).label(
                    "good_amount"
                ),
            )
            .filter(*base_filter)
            .group_by(column)
            .order_by(
                func.sum(ImportedProductStock.good_amount).desc(),
                column.asc(),
            )
            .limit(limit_)
            .all()
        )
        return [
            {
                "key": row.dim_key,
                "label": (row.dim_label or "").strip() or row.dim_key,
                "good_amount": int(row.good_amount or 0),
            }
            for row in rows
        ]

    total = (
        db.query(func.coalesce(func.sum(ImportedProductStock.good_amount), 0))
        .filter(*base_filter)
        .scalar()
    )
    sku_count = (
        db.query(func.count(ImportedProductStock.id))
        .filter(*base_filter)
        .scalar()
    )

    return {
        "month": normalized_month,
        "scope": scope,
        "total_good_amount": int(total or 0),
        "sku_count": int(sku_count or 0),
        "by_product": _bucket(ImportedProductStock.product_kode, limit),
        "by_supplier": _bucket(ImportedProductStock.supplier, limit),
        "by_divisi": _bucket(ImportedProductStock.divisi, limit),
    }
