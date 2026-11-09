"""Import & ringkasan laporan penjualan dari file Excel (admin_web import feature).

Endpoint:

* ``POST /sales-imports/excel`` - upload .xlsx/.xls, upsert rows, bump versions
  only for data that actually changed.
* ``GET  /sales-imports/version`` — tiny, no-store version probe.
* ``GET  /sales-imports/summary`` — reads the precomputed top-N snapshot.

The client probes the version on tab open/focus, month change, manual
refresh, and after import; the summary is only downloaded when the version
changed. This keeps DB→app and app→client egress low even when the table
grows to thousands of rows.
"""
from typing import Optional, Set

from fastapi import APIRouter, Depends, File, HTTPException, Query, Response, UploadFile
from sqlalchemy.orm import Session

from app.core.security import CurrentUser, require_write_access
from app.models.database import get_db
from app.schemas.schemas import (
    SalesImportResultResponse,
    SalesImportVersionResponse,
)
from app.services.sales_import_service import import_sales_from_excel
from app.services.sales_import_versions import (
    get_version,
    parse_month,
    resolve_scope,
)
from app.services.sales_summary_service import (
    ensure_summary,
    read_daily_series,
    read_sales_daily_series,
    read_summary,
)

router = APIRouter(prefix="/sales-imports", tags=["Sales Imports"])

# Hard cap for uploaded Excel files (10 MiB) to avoid memory-exhaustion DoS.
MAX_EXCEL_UPLOAD_BYTES = 10 * 1024 * 1024

_VALID_SECTIONS = {"product", "sales", "customer", "channel", "day", "sales_day"}


def _parse_include(include: Optional[str]) -> Set[str]:
    """Parse ``include=product,sales,...``; empty means all sections."""
    if not include or not include.strip():
        return set(_VALID_SECTIONS)
    sections = {part.strip().lower() for part in include.split(",") if part.strip()}
    unknown = sections - _VALID_SECTIONS
    if unknown:
        raise HTTPException(
            status_code=400,
            detail=f"include tidak dikenal: {', '.join(sorted(unknown))}",
        )
    return sections


@router.post("/excel", response_model=SalesImportResultResponse)
def import_sales_excel(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_write_access),
):
    """
    Upload file Excel (.xlsx atau .xls) berisi laporan penjualan → import ke
    tabel `imported_sales`.

    Import bersifat idempotent: baris yang sudah ada dicocokkan lewat
    `dedupe_key`, sehingga file yang sama tidak menggandakan data. Baris yang
    berubah di-update; baris identik hanya dihitung `updated` tanpa write.

    Semua perubahan dalam 1 transaksi database (ImportLog + baris transaksi +
    versi ringkasan). Import gagal tidak menaikkan versi, dan re-import yang
    tidak mengubah data tidak menaikkan versi sama sekali.
    """
    filename = (file.filename or "").lower()
    if not (filename.endswith(".xlsx") or filename.endswith(".xls")):
        raise HTTPException(
            status_code=400,
            detail="Format file harus .xlsx atau .xls",
        )

    contents = file.file.read(MAX_EXCEL_UPLOAD_BYTES + 1)
    if len(contents) > MAX_EXCEL_UPLOAD_BYTES:
        raise HTTPException(
            status_code=413,
            detail=(
                "File terlalu besar. Maksimal "
                f"{MAX_EXCEL_UPLOAD_BYTES // (1024 * 1024)} MB."
            ),
        )
    if len(contents) == 0:
        raise HTTPException(status_code=400, detail="File kosong")

    result = import_sales_from_excel(
        contents,
        db,
        current_user={
            "user_id": current_user["user_id"],
            "nama": current_user.get("nama"),
            "role": current_user.get("role"),
            "branch": current_user.get("branch"),
        },
        file_name=file.filename,
    )

    return SalesImportResultResponse(
        success=result.get("success", False),
        total_rows=int(result.get("total_rows") or 0),
        inserted=int(result.get("inserted") or 0),
        updated=int(result.get("updated") or 0),
        skipped=int(result.get("skipped") or 0),
        errors=[
            {
                "row": e.get("row") or 0,
                "sku": e.get("sku") or "",
                "reason": e.get("reason") or "",
            }
            for e in (result.get("errors") or [])
        ],
        versions=[
            SalesImportVersionResponse(
                month=v.get("month"),
                scope=v.get("scope"),
                version=int(v.get("version") or 0),
                updated_at=v.get("updated_at"),
            )
            for v in (result.get("versions") or [])
        ],
    )


@router.get("/version", response_model=SalesImportVersionResponse)
def imported_sales_version(
    response: Response,
    month: Optional[str] = None,
    branch: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_write_access),
):
    """Return the current summary version for (scope, month).

    A global MANAGER may pass ``branch`` to probe a single branch instead of
    GLOBAL. Branch-scoped users can only pass their own branch.

    Must never be cached by browsers/proxies — it is the freshness signal.
    """
    normalized, _, _ = parse_month(month)
    scope = resolve_scope(current_user, branch)
    version, updated_at = get_version(db, scope, normalized)

    if response is not None:
        response.headers["Cache-Control"] = "no-store"

    return SalesImportVersionResponse(
        month=normalized,
        scope=scope,
        version=version,
        updated_at=updated_at,
    )


@router.get("/summary")
def imported_sales_summary(
    response: Response,
    month: Optional[str] = None,
    branch: Optional[str] = None,
    limit: int = Query(10, ge=1, le=100),
    include: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_write_access),
):
    """Ringkasan data penjualan ter-import per bulan (YYYY-MM) untuk dashboard.

    Membaca snapshot precomputed (``imported_sales_monthly_summary``) alih-alih
    meng-agregasi seluruh baris bulan pada tiap request. Jika snapshot belum
    ada atau versinya tertinggal (data lama / import baru), snapshot dibangun
    sekali secara lazy. `limit` membatasi jumlah baris per breakdown (top-N by
    revenue). `include` memilih breakdown yang dikirim (hemat egress).
    ``by_day`` (include=day) menambahkan deret omzet harian untuk grafik tren;
    kuerinya dibatasi ke satu bulan dan mengembalikan maksimal ~31 baris.
    ``by_sales_day`` (include=sales_day) menambahkan deret harian untuk top 10
    sales, dipakai grafik multi-garis "Per Sales".

    ``branch`` hanya berlaku untuk global MANAGER: kosong = agregat GLOBAL,
    kode cabang = data cabang tersebut. Role branch-scoped tidak dapat
    memakainya untuk membaca cabang lain.
    """
    normalized, start, month_end = parse_month(month)
    scope = resolve_scope(current_user, branch)
    version, updated_at = get_version(db, scope, normalized)
    sections = _parse_include(include)

    if response is not None:
        response.headers["Cache-Control"] = "no-store"

    ensure_summary(db, scope, normalized, start, month_end, version)
    summary = read_summary(db, scope, normalized, sections, limit)
    by_day = (
        read_daily_series(db, scope, start, month_end) if "day" in sections else []
    )
    by_sales_day = (
        read_sales_daily_series(db, scope, start, month_end)
        if "sales_day" in sections
        else []
    )

    return {
        "month": normalized,
        "scope": scope,
        "version": version,
        "updated_at": updated_at,
        "period_start": start,
        "period_end": month_end,
        "limit": limit,
        "include": sorted(sections),
        "total_revenue": summary["total_revenue"],
        "total_qty": summary["total_qty"],
        "imported_rows": summary["imported_rows"],
        "by_product": summary["by_product"],
        "by_sales": summary["by_sales"],
        "by_customer": summary["by_customer"],
        "by_channel": summary["by_channel"],
        "by_day": by_day,
        "by_sales_day": by_sales_day,
    }
