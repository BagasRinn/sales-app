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
import tempfile
from pathlib import Path
from typing import Any, Dict, Optional, Set

from fastapi import APIRouter, Depends, File, HTTPException, Query, Response, UploadFile
from sqlalchemy.orm import Session

from app.core.branch import get_valid_branch_codes, is_valid_branch
from app.core.security import (
    CurrentUser,
    require_manager_global,
    require_supervisor_or_manager_global,
)
from app.models.database import get_db
from app.models.models import ImportLog, ImportedReturn, ImportedSale
from app.schemas.schemas import (
    SalesImportResultResponse,
    SalesImportVersionResponse,
)
from app.services.sales_import_service import import_sales_from_excel
from app.services.sales_import_versions import (
    bump_versions,
    get_range_version,
    get_version,
    months_before,
    months_in_range,
    parse_month,
    resolve_scope,
)
from app.services.sales_summary_service import (
    ensure_summary,
    read_daily_series,
    read_monthly_comparison,
    read_sales_daily_series,
    recompute_summary,
    read_summary,
    read_summary_range,
)
from app.services.db_locks import acquire_advisory_xact_locks
from app.services.sales_target_import_service import (
    import_sales_targets_from_excel,
    read_sales_target_summary,
    read_sales_target_updated_at,
)
from app.services.sales_return_import_service import import_returns_from_excel
from app.services.import_progress import ImportProgressReporter
from app.api.endpoints.import_progress import import_progress_reporter

router = APIRouter(prefix="/sales-imports", tags=["Sales Imports"])

# Stream uploads to disk; the parser processes .xlsx rows incrementally.
MAX_EXCEL_UPLOAD_BYTES = 70 * 1024 * 1024
MAX_XLS_UPLOAD_BYTES = 20 * 1024 * 1024
MAX_TARGET_UPLOAD_BYTES = 10 * 1024 * 1024
MAX_RETURN_UPLOAD_BYTES = 10 * 1024 * 1024

_VALID_SECTIONS = {
    "product",
    "sales",
    "all_sales",
    "customer",
    "channel",
    "divisi",
    "supplier",
    "supplier_retur",
    "day",
    "sales_day",
}


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
    current_user: CurrentUser = Depends(require_manager_global),
    progress: ImportProgressReporter = Depends(import_progress_reporter),
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

    with tempfile.TemporaryDirectory(prefix="sales-import-") as temp_dir:
        upload_path = Path(temp_dir) / Path(file.filename or "upload.xlsx").name
        size = 0
        with upload_path.open("wb") as target:
            while True:
                chunk = file.file.read(1024 * 1024)
                if not chunk:
                    break
                size += len(chunk)
                if size > MAX_EXCEL_UPLOAD_BYTES:
                    raise HTTPException(
                        status_code=413,
                        detail=(
                            "File terlalu besar. Maksimal "
                            f"{MAX_EXCEL_UPLOAD_BYTES // (1024 * 1024)} MB."
                        ),
                    )
                target.write(chunk)

        if size == 0:
            raise HTTPException(status_code=400, detail="File kosong")
        if filename.endswith(".xls") and size > MAX_XLS_UPLOAD_BYTES:
            raise HTTPException(
                status_code=413,
                detail="File .xls lebih dari 20 MB; simpan ulang sebagai .xlsx",
            )

        result = import_sales_from_excel(
            upload_path,
            db,
            current_user={
                "user_id": current_user["user_id"],
                "nama": current_user.get("nama"),
                "role": current_user.get("role"),
                "branch": current_user.get("branch"),
            },
            file_name=file.filename,
            progress=progress,
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
        template=result.get("template"),
        missing_mother_sku=int(result.get("missing_mother_sku") or 0),
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


@router.post("/targets/excel")
def import_sales_targets_excel(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_manager_global),
    progress: ImportProgressReporter = Depends(import_progress_reporter),
):
    """Import per-branch monthly targets for the Data Penjualan dashboard."""
    filename = file.filename or ""
    if not filename.lower().endswith((".xlsx", ".xls")):
        raise HTTPException(
            status_code=400,
            detail="Format file harus .xlsx atau .xls",
        )

    content = file.file.read(MAX_TARGET_UPLOAD_BYTES + 1)
    if len(content) > MAX_TARGET_UPLOAD_BYTES:
        raise HTTPException(
            status_code=413,
            detail="File target terlalu besar. Maksimal 10 MB.",
        )
    if not content:
        raise HTTPException(status_code=400, detail="File target kosong")

    return import_sales_targets_from_excel(
        content,
        db,
        current_user={
            "user_id": current_user["user_id"],
            "nama": current_user.get("nama"),
            "role": current_user.get("role"),
            "branch": current_user.get("branch"),
        },
        file_name=filename,
        progress=progress,
    )


@router.post("/returns/excel", response_model=SalesImportResultResponse)
def import_sales_returns_excel(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_manager_global),
    progress: ImportProgressReporter = Depends(import_progress_reporter),
):
    """Import an Excel return report; only a global MANAGER may write it."""
    filename = file.filename or ""
    if not filename.lower().endswith((".xlsx", ".xls")):
        raise HTTPException(
            status_code=400,
            detail="Format file harus .xlsx atau .xls",
        )
    content = file.file.read(MAX_RETURN_UPLOAD_BYTES + 1)
    if len(content) > MAX_RETURN_UPLOAD_BYTES:
        raise HTTPException(
            status_code=413,
            detail="File retur terlalu besar. Maksimal 10 MB.",
        )
    if not content:
        raise HTTPException(status_code=400, detail="File retur kosong")

    result = import_returns_from_excel(
        content,
        db,
        current_user={
            "user_id": current_user["user_id"],
            "nama": current_user.get("nama"),
            "role": current_user.get("role"),
            "branch": current_user.get("branch"),
        },
        file_name=filename,
        progress=progress,
    )
    return SalesImportResultResponse(
        success=result["success"],
        total_rows=result["total_rows"],
        inserted=result["inserted"],
        updated=result["updated"],
        skipped=result["skipped"],
        errors=[
            {
                "row": error.get("row") or 0,
                "sku": error.get("sku") or "",
                "reason": error.get("reason") or "",
            }
            for error in result["errors"]
        ],
        versions=[
            SalesImportVersionResponse(
                month=item["month"],
                scope=item["scope"],
                version=item["version"],
                updated_at=item.get("updated_at"),
            )
            for item in result["versions"]
        ],
        unmatched_suppliers=result.get("unmatched_suppliers", []),
    )


@router.get("/version", response_model=SalesImportVersionResponse)
def imported_sales_version(
    response: Response,
    month: Optional[str] = None,
    branch: Optional[str] = None,
    range_months: int = Query(1, ge=1, le=12),
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_supervisor_or_manager_global),
):
    """Return the current summary version for (scope, month).

    A global MANAGER may pass ``branch`` to probe a single branch instead of
    GLOBAL. Branch-scoped users can only pass their own branch.

    Must never be cached by browsers/proxies — it is the freshness signal.
    """
    normalized, _, _ = parse_month(month)
    scope = resolve_scope(current_user, branch)
    if range_months not in (1, 3, 6, 12):
        raise HTTPException(
            status_code=400,
            detail="range_months harus salah satu dari 1, 3, 6, atau 12",
        )
    if range_months == 1:
        version, updated_at = get_version(db, scope, normalized)
    else:
        version, updated_at = get_range_version(
            db, scope, normalized, range_months
        )
    target_updated_at = read_sales_target_updated_at(
        db, scope, months_in_range(normalized, range_months)
    )

    if response is not None:
        response.headers["Cache-Control"] = "no-store"

    return SalesImportVersionResponse(
        month=normalized,
        scope=scope,
        version=version,
        updated_at=updated_at,
        target_updated_at=target_updated_at,
        range_months=range_months,
    )


@router.get("/summary")
def imported_sales_summary(
    response: Response,
    month: Optional[str] = None,
    branch: Optional[str] = None,
    range_months: int = Query(1, ge=1, le=12),
    limit: int = Query(10, ge=1, le=100),
    include: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_supervisor_or_manager_global),
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
    normalized, _, month_end = parse_month(month)
    if range_months not in (1, 3, 6, 12):
        raise HTTPException(
            status_code=400,
            detail="range_months harus salah satu dari 1, 3, 6, atau 12",
        )
    range_month_keys = months_in_range(normalized, range_months)
    _, start, _ = parse_month(range_month_keys[0])
    scope = resolve_scope(current_user, branch)
    if range_months == 1:
        version, updated_at = get_version(db, scope, normalized)
    else:
        version, updated_at = get_range_version(
            db, scope, normalized, range_months
        )
    sections = _parse_include(include)
    include_all_sales = "all_sales" in sections
    if include_all_sales:
        sections.discard("all_sales")
        sections.add("sales")

    if response is not None:
        response.headers["Cache-Control"] = "no-store"

    if range_months == 1:
        ensure_summary(db, scope, normalized, start, month_end, version)
        summary = read_summary(
            db,
            scope,
            normalized,
            sections,
            limit,
            include_all_sales=include_all_sales,
        )
    else:
        summary = read_summary_range(
            db,
            scope,
            start,
            month_end,
            sections,
            limit,
            include_all_sales=include_all_sales,
        )
    (
        sales_targets,
        supplier_targets,
        divisi_targets,
        target_updated_at,
    ) = read_sales_target_summary(db, scope, range_month_keys)
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
        "range_months": range_months,
        "scope": scope,
        "version": version,
        "updated_at": updated_at,
        "target_updated_at": target_updated_at,
        "period_start": start,
        "period_end": month_end,
        "limit": limit,
        "include": sorted(sections),
        "total_revenue": summary["total_revenue"],
        "total_qty": summary["total_qty"],
        "total_margin": summary["total_margin"],
        "total_retur_revenue": summary["total_retur_revenue"],
        "total_retur_margin": summary["total_retur_margin"],
        "total_retur_rows": summary["total_retur_rows"],
        "imported_rows": summary["imported_rows"],
        "by_product": summary["by_product"],
        "by_sales": summary["by_sales"],
        "by_customer": summary["by_customer"],
        "by_channel": summary["by_channel"],
        "by_divisi": summary["by_divisi"],
        "by_supplier": summary["by_supplier"],
        "by_supplier_retur": summary["by_supplier_retur"],
        "sales_targets": sales_targets,
        "supplier_targets": supplier_targets,
        "divisi_targets": divisi_targets,
        "by_day": by_day,
        "by_sales_day": by_sales_day,
    }


@router.get("/comparison")
def imported_sales_comparison(
    response: Response,
    month: Optional[str] = None,
    branch: Optional[str] = None,
    months: int = Query(3, ge=1, le=12),
    include: Optional[str] = None,
    limit: int = Query(10, ge=1, le=100),
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_supervisor_or_manager_global),
):
    """Net omzet per bulan untuk N bulan *sebelum* bulan terpilih.

    Digunakan chip pembanding di dashboard (Bulanan / 3 / 6 / 12). Bulan
    yang tidak punya data sama sekali tidak dikembalikan, sehingga rata-rata
    di frontend hanya dibagi dengan jumlah bulan yang berdata.

    Saat ``include`` diisi (mis. ``product,customer,divisi``), response juga
    menyertakan agregasi dimensi untuk periode pembanding. Setiap item
    diberikan field tambahan ``average_revenue`` = total ÷ jumlah bulan
    berdata, bukan total kasar.
    """
    normalized, _, month_end = parse_month(month)
    scope = resolve_scope(current_user, branch)
    month_keys = months_before(normalized, months)
    _, start, _ = parse_month(month_keys[0])
    _, selected_start, _ = parse_month(normalized)
    monthly = read_monthly_comparison(db, scope, start, selected_start)
    total = sum(int(item["net_revenue"] or 0) for item in monthly)
    count = len(monthly)

    sections = {d.strip().lower() for d in (include or "").split(",") if d.strip()}
    detail: Dict[str, Any] = {}
    if sections:
        # read_summary_range mengembalikan total kasar (net) untuk seluruh
        # rentang pembanding. Kita turunkan jadi rata-rata per item di sini.
        range_summary = read_summary_range(
            db,
            scope,
            start,
            selected_start,
            sections,
            limit,
            include_all_sales=False,
        )
        # section name ("product") → result key ("by_product")
        section_to_key = {
            "product": "by_product",
            "customer": "by_customer",
            "divisi": "by_divisi",
            "sales": "by_sales",
            "channel": "by_channel",
            "supplier": "by_supplier",
        }
        for section, result_key in section_to_key.items():
            if section not in sections:
                continue
            items = range_summary.get(result_key, [])
            detail[result_key] = [
                {
                    **item,
                    "average_revenue": (
                        int(item.get("revenue") or 0) // count
                    )
                    if count
                    else 0,
                    "average_margin": (
                        int(item.get("margin") or 0) // count
                    )
                    if count
                    else 0,
                }
                for item in items
            ]

    if response is not None:
        response.headers["Cache-Control"] = "no-store"
    return {
        "month": normalized,
        "months": months,
        "scope": scope,
        "month_keys": month_keys,
        "months_with_data": count,
        "total_revenue": total,
        "average_revenue": (total // count) if count else 0,
        "monthly": monthly,
        **detail,
    }


@router.delete("/month")
def delete_imported_sales_month(
    month: str = Query(...),
    branch: Optional[str] = None,
    all_branches: bool = False,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_manager_global),
):
    """Permanently delete imported rows for one month and optional branch."""
    normalized, start, month_end = parse_month(month)
    if bool(branch) == bool(all_branches):
        raise HTTPException(
            status_code=400,
            detail="Isi branch atau all_branches=true, tetapi jangan keduanya",
        )
    normalized_branch = branch.strip().upper() if branch else None
    if normalized_branch and not is_valid_branch(normalized_branch):
        raise HTTPException(status_code=400, detail="Cabang tidak dikenal")

    start_date = start.date()
    end_date = month_end.date()
    query = db.query(ImportedSale).filter(
        ImportedSale.sale_date >= start_date,
        ImportedSale.sale_date < end_date,
    )
    if normalized_branch:
        query = query.filter(ImportedSale.branch == normalized_branch)

    if all_branches:
        existing_branches = {
            value
            for (value,) in db.query(ImportedSale.branch)
            .filter(
                ImportedSale.sale_date >= start_date,
                ImportedSale.sale_date < end_date,
            )
            .distinct()
            .all()
            if value
        }
        lock_scopes = set(get_valid_branch_codes()) | existing_branches | {"GLOBAL"}
    else:
        lock_scopes = {normalized_branch, "GLOBAL"}
    acquire_advisory_xact_locks(
        db,
        (
            f"sales-import:{scope}:{normalized}"
            for scope in lock_scopes
        ),
    )

    branches = {
        value
        for (value,) in query.with_entities(ImportedSale.branch).distinct().all()
        if value
    }
    deleted = query.delete(synchronize_session=False)
    db.add(
        ImportLog(
            user_id=current_user.get("user_id"),
            nama=current_user.get("nama"),
            import_type="SALES_DELETE",
            total_rows=deleted,
            inserted=0,
            updated=0,
            skipped=0,
            file_name=f"delete:{normalized}",
            branch=normalized_branch,
        )
    )

    versions = []
    if deleted:
        scopes = {"GLOBAL"} | branches
        if normalized_branch:
            scopes.add(normalized_branch)
        versions = bump_versions(db, sorted(scopes), [normalized])
        version_by_scope = {
            row["scope"]: int(row["version"] or 0) for row in versions
        }
        for scope in sorted(scopes):
            recompute_summary(
                db,
                scope,
                normalized,
                start,
                month_end,
                version_by_scope.get(scope, 0),
            )

    db.commit()
    return {
        "success": True,
        "month": normalized,
        "branch": normalized_branch,
        "all_branches": all_branches,
        "deleted": int(deleted),
        "versions": versions,
    }


@router.delete("/returns/month")
def delete_imported_sales_returns_month(
    month: str = Query(...),
    branch: Optional[str] = None,
    all_branches: bool = False,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_manager_global),
):
    """Permanently delete return rows for a month and optional branch."""
    normalized, start, month_end = parse_month(month)
    if bool(branch) == bool(all_branches):
        raise HTTPException(
            status_code=400,
            detail="Isi branch atau all_branches=true, tetapi jangan keduanya",
        )
    normalized_branch = branch.strip().upper() if branch else None
    if normalized_branch and not is_valid_branch(normalized_branch):
        raise HTTPException(status_code=400, detail="Cabang tidak dikenal")

    query = db.query(ImportedReturn).filter(
        ImportedReturn.sale_date >= start.date(),
        ImportedReturn.sale_date < month_end.date(),
    )
    if normalized_branch:
        query = query.filter(ImportedReturn.branch == normalized_branch)

    if all_branches:
        existing_branches = {
            value
            for (value,) in db.query(ImportedReturn.branch)
            .filter(
                ImportedReturn.sale_date >= start.date(),
                ImportedReturn.sale_date < month_end.date(),
            )
            .distinct()
            .all()
            if value
        }
        lock_scopes = set(get_valid_branch_codes()) | existing_branches | {"GLOBAL"}
    else:
        lock_scopes = {normalized_branch, "GLOBAL"}
    acquire_advisory_xact_locks(
        db,
        (f"sales-import:{scope}:{normalized}" for scope in lock_scopes),
    )

    branches = {
        value
        for (value,) in query.with_entities(ImportedReturn.branch).distinct().all()
        if value
    }
    deleted = query.delete(synchronize_session=False)
    db.add(
        ImportLog(
            user_id=current_user.get("user_id"),
            nama=current_user.get("nama"),
            import_type="SALES_RETUR_DELETE",
            total_rows=deleted,
            inserted=0,
            updated=0,
            skipped=0,
            file_name=f"delete-returns:{normalized}",
            branch=normalized_branch,
        )
    )

    versions = []
    if deleted:
        scopes = {"GLOBAL"} | branches
        if normalized_branch:
            scopes.add(normalized_branch)
        versions = bump_versions(db, sorted(scopes), [normalized])
        version_by_scope = {
            row["scope"]: int(row["version"] or 0) for row in versions
        }
        for scope in sorted(scopes):
            recompute_summary(
                db,
                scope,
                normalized,
                start,
                month_end,
                version_by_scope.get(scope, 0),
            )

    db.commit()
    return {
        "success": True,
        "month": normalized,
        "branch": normalized_branch,
        "all_branches": all_branches,
        "deleted": int(deleted),
        "versions": versions,
    }
