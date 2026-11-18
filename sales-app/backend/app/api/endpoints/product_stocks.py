"""Endpoint snapshot stok produk (Value Good) untuk dashboard analytics.

* ``POST /product-stocks/import-excel`` — global MANAGER only.
* ``GET  /product-stocks/summary`` — agregasi per scope pemanggil.
* ``DELETE /product-stocks/month`` — hapus snapshot satu bulan (opsional
  per cabang / semua cabang), global MANAGER only.
"""
import tempfile
from pathlib import Path
from typing import Optional

from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile
from sqlalchemy.orm import Session

from app.core.branch import is_valid_branch
from app.core.security import CurrentUser, require_manager_global
from app.api.endpoints.import_progress import import_progress_reporter
from app.models.database import get_db
from app.models.models import ImportLog, ImportedProductStock
from app.services.import_progress import ImportProgressReporter
from app.services.product_stock_import_service import (
    IMPORT_TYPE_PRODUCT_STOCK,
    import_product_stock_from_excel,
    read_product_stock_summary,
)
from app.services.sales_import_versions import parse_month, resolve_scope

router = APIRouter(prefix="/product-stocks", tags=["Product Stocks"])

MAX_STOCK_UPLOAD_BYTES = 30 * 1024 * 1024


@router.post("/import-excel")
def import_product_stock_excel(
    month: str = Query(..., description="Bulan snapshot (YYYY-MM) dari month picker"),
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_manager_global),
    progress: ImportProgressReporter = Depends(import_progress_reporter),
):
    """Upload file Excel laporan stok gudang → tabel `imported_product_stocks`.

    Global MANAGER only. Bulan dari parameter ``month`` (month picker), bukan
    dari file. Cabang per baris diambil dari kolom `Cabang` file (case
    normalization + validasi daftar cabang). Re-import bulan yang sama untuk
    cabang yang sama mengganti seluruh data lama cabang itu (replace penuh).
    """
    data = file.file.read()
    if len(data) > MAX_STOCK_UPLOAD_BYTES:
        raise HTTPException(
            status_code=413,
            detail="File terlalu besar (maksimal 30 MB).",
        )
    if not data:
        raise HTTPException(status_code=400, detail="File kosong.")

    suffix = Path(file.filename or "stocks.xlsx").suffix
    with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
        tmp.write(data)
        tmp_path = Path(tmp.name)

    try:
        result = import_product_stock_from_excel(
            file_bytes=data,
            file_name=file.filename,
            month=month,
            db=db,
            current_user=current_user,
            progress=progress,
        )
    finally:
        tmp_path.unlink(missing_ok=True)
    return result


@router.get("/summary")
def product_stock_summary(
    month: str = Query(..., description="Bulan snapshot (YYYY-MM)"),
    branch: str | None = Query(None, description="Filter cabang (global manager saja)"),
    limit: int = Query(5000, ge=1, le=5000),
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_manager_global),
):
    """Agregasi Value Good per produk/supplier/divisi untuk scope pemanggil."""
    scope = resolve_scope(current_user, branch)
    return read_product_stock_summary(db, scope, month, limit)


@router.delete("/month")
def delete_product_stock_month(
    month: str = Query(..., description="Bulan snapshot (YYYY-MM)"),
    branch: Optional[str] = Query(None),
    all_branches: bool = Query(False),
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_manager_global),
):
    """Hapus permanen snapshot stok satu bulan (opsional per cabang / semua).

    Global MANAGER only. Isi ``branch`` ATAU ``all_branches=true`` — jangan
    keduanya. Snapshot stok tidak punya tabel precompute, jadi tidak ada
    recompute ringkasan setelahnya.
    """
    normalized, _, _ = parse_month(month)
    if bool(branch) == bool(all_branches):
        raise HTTPException(
            status_code=400,
            detail="Isi branch atau all_branches=true, tetapi jangan keduanya",
        )
    normalized_branch = branch.strip().upper() if branch else None
    if normalized_branch and not is_valid_branch(normalized_branch):
        raise HTTPException(status_code=400, detail="Cabang tidak dikenal")

    query = db.query(ImportedProductStock).filter(
        ImportedProductStock.month == normalized
    )
    if normalized_branch:
        query = query.filter(
            ImportedProductStock.branch == normalized_branch
        )

    deleted = query.delete(synchronize_session=False)
    db.add(
        ImportLog(
            user_id=current_user.get("user_id"),
            nama=current_user.get("nama"),
            import_type=IMPORT_TYPE_PRODUCT_STOCK,
            total_rows=deleted,
            file_name=f"delete:{normalized}",
            branch=normalized_branch,
        )
    )
    db.commit()
    return {
        "success": True,
        "month": normalized,
        "branch": normalized_branch,
        "all_branches": all_branches,
        "deleted": int(deleted),
    }
