"""Import & ringkasan laporan penjualan dari file Excel (admin_web import feature)."""
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from typing import Dict, List, Optional
from datetime import datetime
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.models.database import get_db
from app.models.models import ImportLog, ImportedSale, SyncValidationError
from app.core.security import require_admin_or_supervisor, require_manager_global, require_auth, require_write_access, CurrentUser, apply_branch_filter
from app.schemas.schemas import SyncResultResponse
from app.services.sales_import_service import import_sales_from_excel

router = APIRouter(prefix="/sales-imports", tags=["Sales Imports"])


@router.post("/excel", response_model=SyncResultResponse)
def import_sales_excel(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_write_access),
):
    """
    Upload file Excel (.xlsx) berisi laporan penjualan → import ke tabel `imported_sales`.
    Semua perubahan dalam 1 transaksi database (ImportLog + baris transaksi).
    """
    if not file.filename or not file.filename.lower().endswith(".xlsx"):
        raise HTTPException(status_code=400, detail="Format file harus .xlsx")

    contents = file.file.read()
    if len(contents) == 0:
        raise HTTPException(status_code=400, detail="File kosong")

    result = import_sales_from_excel(
        contents, db,
        current_user={
            "user_id": current_user["user_id"],
            "nama": current_user.get("nama"),
            "branch": current_user.get("branch"),
        },
        file_name=file.filename,
    )

    return SyncResultResponse(
        success=result.get("success", False),
        total_rows=int(result.get("total_rows") or 0),
        inserted=int(result.get("inserted") or 0),
        updated=int(result.get("updated") or 0),
        skipped=int(result.get("skipped") or 0),
        errors=[{"row": e.get("row") or 0, "sku": e.get("sku") or "", "reason": e.get("reason") or ""} for e in (result.get("errors") or [])],
    )


@router.get("/summary")
def imported_sales_summary(
    month: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: CurrentUser = Depends(require_auth),
):
    """Ringkasan data penjualan ter-import per bulan (YYYY-MM) untuk dashboard.

    Admin/Supervisor akses; MANAGER global bisa akses semua cabang.
    """
    if not month:
        now = datetime.now()
        month = f"{now.year:04d}-{now.month:02d}"
    try:
        year, month_num = map(int, month.split("-"))
        if not (1 <= month_num <= 12):
            raise ValueError
    except ValueError:
        raise HTTPException(status_code=400, detail="month harus format YYYY-MM")

    start = datetime(year, month_num, 1)
    month_end = datetime(year + 1, 1, 1) if month_num == 12 else datetime(year, month_num + 1, 1)

    query = db.query(ImportedSale).filter(
        ImportedSale.sale_date >= start,
        ImportedSale.sale_date < month_end,
    )
    scope = current_user.get("branch")
    if scope is not None:
        from sqlalchemy import or_
        query = query.filter(or_(ImportedSale.branch == scope, ImportedSale.branch.is_(None)))

    rows = query.all()

    total_revenue = sum(int(r.total_amount or 0) for r in rows)
    total_qty = sum(int(r.qty or 0) for r in rows)

    by_product: List[dict] = []
    prod_map: Dict[str, dict] = {}
    by_sales: List[dict] = []
    sales_map: Dict[str, dict] = {}
    by_customer: List[dict] = []
    customer_map: Dict[str, dict] = {}
    by_channel: List[dict] = []
    channel_map: Dict[str, dict] = {}

    for r in rows:
        key_p = f"{r.product_kode or ''}|{r.product_nama or ''}"
        p = prod_map.setdefault(key_p, {"product_kode": r.product_kode, "product_nama": r.product_nama, "qty": 0, "revenue": 0})
        p["qty"] += int(r.qty or 0)
        p["revenue"] += int(r.total_amount or 0)

        key_s = f"{r.sales_kode or ''}|{r.sales_nama or ''}"
        s = sales_map.setdefault(key_s, {"sales_kode": r.sales_kode, "sales_nama": r.sales_nama, "qty": 0, "revenue": 0})
        s["qty"] += int(r.qty or 0)
        s["revenue"] += int(r.total_amount or 0)

        key_c = f"{r.customer_kode or ''}|{r.customer_nama or ''}"
        c = customer_map.setdefault(key_c, {"customer_kode": r.customer_kode, "customer_nama": r.customer_nama, "qty": 0, "revenue": 0})
        c["qty"] += int(r.qty or 0)
        c["revenue"] += int(r.total_amount or 0)

        key_ch = (r.channel or "UNKNOWN") or "UNKNOWN"
        ch = channel_map.setdefault(key_ch, {"channel": r.channel, "qty": 0, "revenue": 0})
        ch["qty"] += int(r.qty or 0)
        ch["revenue"] += int(r.total_amount or 0)

    by_product = [
        {"product_kode": v["product_kode"], "product_nama": v["product_nama"], "qty": int(v["qty"]), "revenue": int(v["revenue"])}
        for v in sorted(prod_map.values(), key=lambda x: (-x["revenue"], x["product_nama"] or ""))
    ]
    by_sales = [
        {"sales_kode": v["sales_kode"], "sales_nama": v["sales_nama"], "qty": int(v["qty"]), "revenue": int(v["revenue"])}
        for v in sorted(sales_map.values(), key=lambda x: (-x["revenue"], x["sales_nama"] or ""))
    ]
    by_customer = [
        {"customer_kode": v["customer_kode"], "customer_nama": v["customer_nama"], "qty": int(v["qty"]), "revenue": int(v["revenue"])}
        for v in sorted(customer_map.values(), key=lambda x: (-x["revenue"], x["customer_nama"] or ""))
    ]
    by_channel = [
        {"channel": v["channel"], "qty": int(v["qty"]), "revenue": int(v["revenue"])}
        for v in sorted(channel_map.values(), key=lambda x: (-x["revenue"], (x["channel"] or "")))
    ]

    return {
        "month": month,
        "period_start": start,
        "period_end": month_end,
        "total_revenue": int(total_revenue),
        "total_qty": int(total_qty),
        "imported_rows": len(rows),
        "by_product": by_product,
        "by_sales": by_sales,
        "by_customer": by_customer,
        "by_channel": by_channel,
    }
