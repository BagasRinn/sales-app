"""Precomputed imported-sales summaries (Phase 2).

The summary endpoint used to aggregate every row of a month on each request
(``GROUP BY`` over ``imported_sales``). This module keeps a small precomputed
table instead:

* ``ImportedSalesMonthlySummary`` holds one ``TOTAL`` row plus the top
  ``SUMMARY_TOP_N`` groups for each breakdown.
* ``ImportedSalesSummaryState`` records the source version the table was built
  from.

Recompute happens in two places:

1. Inside the import transaction, right after the version bump, so a
   successful import immediately refreshes the affected ``(scope, month)``.
2. Lazily on the read path when the state row is missing or its
   ``source_version`` differs from the current version. That backfills data
   imported before this table existed without a separate migration step.

Both paths are serialized per ``(scope, month)`` with a transaction-scoped
Postgres advisory lock, so two concurrent requests cannot double-insert rows.

The read path only ever scans this small table (six sales dimensions × 100
rows, plus up to 200 return-supplier rows), so DB→app egress is bounded even
when the source tables grow.
"""
from __future__ import annotations

from datetime import datetime
from typing import Any, Dict, Iterable, List, Optional, Tuple
from uuid import uuid4

from sqlalchemy import case, func, literal
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.orm import Session

from app.models.models import (
    ImportedSale,
    ImportedReturn,
    ImportedSalesMonthlySummary,
    ImportedSalesSummaryState,
)
from app.services.db_locks import acquire_advisory_xact_lock
from app.services.sales_import_versions import GLOBAL_SCOPE

# The API caps `limit` at 100, so storing the top 100 per dimension is enough
# to satisfy every possible request. Totals are always stored in full.
SUMMARY_TOP_N = 100
RETURN_SUPPLIER_SNAPSHOT_TOP_N = SUMMARY_TOP_N * 2

# Number of sales lines drawn on the multi-series daily chart. Ten is enough to
# compare the top performers without turning the chart into a hairball.
SALES_TREND_TOP_N = 10

TOTAL_DIMENSION = "TOTAL"
PRODUCT_DIMENSION = "PRODUCT"
SALES_DIMENSION = "SALES"
CUSTOMER_DIMENSION = "CUSTOMER"
CHANNEL_DIMENSION = "CHANNEL"
DIVISI_DIMENSION = "DIVISI"
SUPPLIER_DIMENSION = "SUPPLIER"
RETURN_SUPPLIER_DIMENSION = "RETUR_SUP"

DIMENSIONS: Tuple[str, ...] = (
    PRODUCT_DIMENSION,
    SALES_DIMENSION,
    CUSTOMER_DIMENSION,
    CHANNEL_DIMENSION,
    DIVISI_DIMENSION,
    SUPPLIER_DIMENSION,
)

def _scope_query(db: Session, scope: str, start: datetime, month_end: datetime):
    """Rows visible to ``scope`` for the month.

    ``GLOBAL`` sees every row (including legacy ``branch IS NULL`` rows).
    A branch scope sees only rows tagged with that exact branch — NULL rows
    are intentionally excluded so data cannot leak across branches.
    """
    query = db.query(ImportedSale).filter(
        ImportedSale.sale_date >= start,
        ImportedSale.sale_date < month_end,
    )
    if scope != GLOBAL_SCOPE:
        query = query.filter(ImportedSale.branch == scope)
    return query


def _scope_return_query(
    db: Session, scope: str, start: datetime, month_end: datetime
):
    query = db.query(ImportedReturn).filter(
        ImportedReturn.sale_date >= start,
        ImportedReturn.sale_date < month_end,
    )
    if scope != GLOBAL_SCOPE:
        query = query.filter(ImportedReturn.branch == scope)
    return query


def _as_text(value: Any, limit: int) -> str:
    if value is None:
        return ""
    return str(value)[:limit]


def _normalized_key(value: Any) -> str:
    if value is None:
        return ""
    return " ".join(str(value).strip().upper().split())[:100]


def _distinct_identity_count(column):
    """Count non-empty branch + source-code identities without null collapsing."""
    identity = func.concat(
        func.coalesce(ImportedSale.branch, ""),
        "|",
        column,
    )
    return func.count(
        func.distinct(
            case(
                (column.isnot(None) & (column != ""), identity),
                else_=None,
            )
        )
    )


def _dimension_columns(dimension: str, returns: bool = False):
    if returns:
        model = ImportedReturn
        if dimension == PRODUCT_DIMENSION:
            return (
                func.coalesce(
                    func.nullif(model.mother_sku, ""),
                    model.product_kode,
                ),
                func.max(model.product_nama),
            )
        if dimension == SALES_DIMENSION:
            return (
                func.concat(func.coalesce(model.branch, ""), "|", func.coalesce(model.sales_nama, "")),
                func.max(model.sales_nama),
            )
        if dimension == CUSTOMER_DIMENSION:
            return model.customer_kode, func.max(model.customer_nama)
        if dimension == DIVISI_DIMENSION:
            return model.divisi, func.max(model.divisi)
        if dimension == SUPPLIER_DIMENSION:
            return model.supplier, func.max(model.supplier)
        return None, None

    model = ImportedSale
    if dimension == PRODUCT_DIMENSION:
        return (
            func.coalesce(
                func.nullif(model.mother_sku, ""),
                model.product_kode,
            ),
            func.max(model.product_nama),
        )
    if dimension == SALES_DIMENSION:
        return (
            func.concat(
                func.coalesce(model.branch, ""),
                "|",
                func.coalesce(
                    func.nullif(model.sales_kode, ""),
                    model.sales_nama,
                ),
            ),
            func.max(model.sales_nama),
        )
    if dimension == CUSTOMER_DIMENSION:
        return model.customer_kode, func.max(model.customer_nama)
    if dimension == CHANNEL_DIMENSION:
        return model.channel, func.max(model.channel)
    if dimension == DIVISI_DIMENSION:
        return model.divisi, func.max(model.divisi)
    return model.supplier, func.max(model.supplier)


def _dimension_rows(
    db: Session,
    scope: str,
    start: datetime,
    month_end: datetime,
    dimension: str,
) -> List[Dict[str, Any]]:
    """Aggregate gross sales and returns, then net before top-N ordering."""
    sales_key, sales_label = _dimension_columns(dimension)
    sales_query = _scope_query(db, scope, start, month_end)
    sales_groups = (
        sales_query.with_entities(
            sales_key.label("dim_key"),
            sales_label.label("dim_label"),
            func.coalesce(func.sum(ImportedSale.qty), 0).label("qty"),
            func.coalesce(func.sum(ImportedSale.total_amount), 0).label(
                "revenue"
            ),
            func.coalesce(func.sum(ImportedSale.margin), 0).label("margin"),
            (
                func.max(ImportedSale.product_kode).label("product_kode")
                if dimension == PRODUCT_DIMENSION
                else literal(None).label("product_kode")
            ),
            (
                func.max(ImportedSale.mother_sku).label("mother_sku")
                if dimension == PRODUCT_DIMENSION
                else literal(None).label("mother_sku")
            ),
        )
        .group_by(sales_key)
        .order_by(sales_key.asc())
        .all()
    )
    merged: Dict[str, Dict[str, Any]] = {}
    sales_keys_by_name: Dict[str, str] = {}

    def item_for(key_value: Any, label_value: Any) -> Dict[str, Any]:
        key = _normalized_key(key_value)
        item = merged.setdefault(
            key,
            {
                "dim_key": key,
                "dim_label": "",
                "qty": 0,
                "revenue": 0,
                "margin": 0,
                "retur_revenue": 0,
                "retur_margin": 0,
                "retur_rows": 0,
                "product_kode": None,
                "mother_sku": None,
            },
        )
        label = _as_text(label_value, 200)
        if label and label > item["dim_label"]:
            item["dim_label"] = label
        return item

    for group in sales_groups:
        item = item_for(group.dim_key, group.dim_label)
        if dimension == SALES_DIMENSION and group.dim_label:
            branch_key = _normalized_key(group.dim_key).split("|", 1)[0]
            sales_keys_by_name.setdefault(
                f"{branch_key}|{_normalized_key(group.dim_label)}",
                item["dim_key"],
            )
        item["qty"] += int(group.qty or 0)
        item["revenue"] += int(group.revenue or 0)
        item["margin"] += int(group.margin or 0)
        if dimension == PRODUCT_DIMENSION:
            item["product_kode"] = max(
                filter(None, (item["product_kode"], group.product_kode)),
                default=None,
            )
            item["mother_sku"] = max(
                filter(None, (item["mother_sku"], group.mother_sku)),
                default=None,
            )

    return_key, return_label = _dimension_columns(dimension, returns=True)
    if return_key is not None:
        return_groups = (
            _scope_return_query(db, scope, start, month_end)
            .with_entities(
                return_key.label("dim_key"),
                return_label.label("dim_label"),
                func.coalesce(func.sum(ImportedReturn.revenue), 0).label(
                    "revenue"
                ),
                func.coalesce(func.sum(ImportedReturn.margin), 0).label(
                    "margin"
                ),
                func.count(ImportedReturn.id).label("row_count"),
                (
                    func.max(ImportedReturn.product_kode).label("product_kode")
                    if dimension == PRODUCT_DIMENSION
                    else literal(None).label("product_kode")
                ),
                (
                    func.max(ImportedReturn.mother_sku).label("mother_sku")
                    if dimension == PRODUCT_DIMENSION
                    else literal(None).label("mother_sku")
                ),
            )
            .group_by(return_key)
            .all()
        )
        for group in return_groups:
            return_key_value = group.dim_key
            if dimension == SALES_DIMENSION:
                return_parts = _normalized_key(group.dim_key).split("|", 1)
                return_branch = return_parts[0]
                return_name = _normalized_key(group.dim_label or (return_parts[1] if len(return_parts) > 1 else ""))
                return_key_value = sales_keys_by_name.get(
                    f"{return_branch}|{return_name}",
                    group.dim_key,
                )
            item = item_for(return_key_value, group.dim_label)
            item["retur_revenue"] += int(group.revenue or 0)
            item["retur_margin"] += int(group.margin or 0)
            item["retur_rows"] += int(group.row_count or 0)
            if dimension == PRODUCT_DIMENSION:
                item["product_kode"] = max(
                    filter(None, (item["product_kode"], group.product_kode)),
                    default=None,
                )
                item["mother_sku"] = max(
                    filter(None, (item["mother_sku"], group.mother_sku)),
                    default=None,
                )

    for item in merged.values():
        item["revenue"] -= item["retur_revenue"]
        item["margin"] -= item["retur_margin"]
    return sorted(
        merged.values(),
        key=lambda item: (
            -item["revenue"],
            item["dim_label"].casefold(),
            item["dim_key"],
        ),
    )


def _return_supplier_groups(
    db: Session,
    scope: str,
    start: datetime,
    month_end: datetime,
) -> List[Dict[str, Any]]:
    groups = _dimension_rows(
        db, scope, start, month_end, SUPPLIER_DIMENSION
    )
    by_revenue = sorted(
        groups,
        key=lambda item: (
            -item["retur_revenue"],
            item["dim_label"].casefold(),
            item["dim_key"],
        ),
    )[:SUMMARY_TOP_N]
    by_margin = sorted(
        groups,
        key=lambda item: (
            -item["retur_margin"],
            item["dim_label"].casefold(),
            item["dim_key"],
        ),
    )[:SUMMARY_TOP_N]
    unique = {item["dim_key"]: item for item in by_revenue + by_margin}
    return list(unique.values())


def _lock_summary(db: Session, scope: str, month: str) -> None:
    """Serialize recomputes for one (scope, month) within this transaction."""
    acquire_advisory_xact_lock(
        db, f"imported-sales-summary:{scope}:{month}"
    )


def recompute_summary(
    db: Session,
    scope: str,
    month: str,
    start: datetime,
    month_end: datetime,
    version: int,
) -> None:
    """Rebuild the precomputed rows for one ``(scope, month)``.

    Must be called inside the caller's transaction. The caller is responsible
    for committing; at import time that is the same commit as the inserted
    rows + version bump, so readers never see a half-built summary.
    """
    _lock_summary(db, scope, month)

    sales_totals = _scope_query(db, scope, start, month_end).with_entities(
        func.coalesce(func.sum(ImportedSale.total_amount), 0),
        func.coalesce(func.sum(ImportedSale.qty), 0),
        func.coalesce(func.sum(ImportedSale.margin), 0),
        func.count(ImportedSale.id),
        _distinct_identity_count(ImportedSale.trans_no),
        _distinct_identity_count(ImportedSale.customer_kode),
    ).one()
    return_totals = _scope_return_query(
        db, scope, start, month_end
    ).with_entities(
        func.coalesce(func.sum(ImportedReturn.revenue), 0),
        func.coalesce(func.sum(ImportedReturn.margin), 0),
        func.count(ImportedReturn.id),
    ).one()
    total_revenue = int(sales_totals[0] or 0) - int(return_totals[0] or 0)
    total_qty = int(sales_totals[1] or 0)
    total_margin = int(sales_totals[2] or 0) - int(return_totals[1] or 0)
    row_count = int(sales_totals[3] or 0)
    effective_call_count = int(sales_totals[4] or 0)
    active_outlet_count = int(sales_totals[5] or 0)

    rows: List[ImportedSalesMonthlySummary] = [
        ImportedSalesMonthlySummary(
            scope=scope,
            month=month,
            dimension=TOTAL_DIMENSION,
            dim_key="",
            dim_label="",
            qty=total_qty,
            revenue=total_revenue,
            margin=total_margin,
            retur_revenue=int(return_totals[0] or 0),
            retur_margin=int(return_totals[1] or 0),
            retur_rows=int(return_totals[2] or 0),
            row_count=row_count,
            effective_call_count=effective_call_count,
            active_outlet_count=active_outlet_count,
        )
    ]

    for dimension in DIMENSIONS:
        for group in _dimension_rows(
            db, scope, start, month_end, dimension
        )[:SUMMARY_TOP_N]:
            rows.append(
                ImportedSalesMonthlySummary(
                    scope=scope,
                    month=month,
                    dimension=dimension,
                    dim_key=group["dim_key"],
                    dim_label=group["dim_label"],
                    product_kode=_as_text(group["product_kode"], 50) or None,
                    mother_sku=_as_text(group["mother_sku"], 100) or None,
                    qty=group["qty"],
                    revenue=group["revenue"],
                    margin=group["margin"],
                    row_count=0,
                )
            )

    return_supplier_groups = _return_supplier_groups(
        db, scope, start, month_end
    )
    for group in return_supplier_groups:
        if not group["retur_rows"]:
            continue
        rows.append(
            ImportedSalesMonthlySummary(
                scope=scope,
                month=month,
                dimension=RETURN_SUPPLIER_DIMENSION,
                dim_key=group["dim_key"],
                dim_label=group["dim_label"],
                revenue=group["retur_revenue"],
                margin=group["retur_margin"],
                row_count=group["retur_rows"],
                supplier_net_revenue=group["revenue"],
            )
        )

    # Replace the previous snapshot atomically within the transaction.
    (
        db.query(ImportedSalesMonthlySummary)
        .filter(
            ImportedSalesMonthlySummary.scope == scope,
            ImportedSalesMonthlySummary.month == month,
        )
        .delete(synchronize_session=False)
    )
    db.add_all(rows)

    stmt = pg_insert(ImportedSalesSummaryState).values(
        id=uuid4(),
        scope=scope,
        month=month,
        source_version=int(version or 0),
    )
    stmt = stmt.on_conflict_do_update(
        index_elements=[
            ImportedSalesSummaryState.scope,
            ImportedSalesSummaryState.month,
        ],
        set_={
            "source_version": int(version or 0),
            "computed_at": func.now(),
        },
    )
    db.execute(stmt)


def ensure_summary(
    db: Session,
    scope: str,
    month: str,
    start: datetime,
    month_end: datetime,
    version: int,
) -> bool:
    """Recompute when the stored snapshot is missing or stale.

    Returns ``True`` when a recompute ran. Commits the lazy-backfill write so
    the read dependency (which does not commit) does not roll it back.
    """
    state = (
        db.query(ImportedSalesSummaryState)
        .filter(
            ImportedSalesSummaryState.scope == scope,
            ImportedSalesSummaryState.month == month,
        )
        .first()
    )
    if state is not None and int(state.source_version or 0) == int(version or 0):
        has_snapshot = (
            db.query(ImportedSalesMonthlySummary.id)
            .filter(
                ImportedSalesMonthlySummary.scope == scope,
                ImportedSalesMonthlySummary.month == month,
                ImportedSalesMonthlySummary.dimension == TOTAL_DIMENSION,
            )
            .first()
            is not None
        )
        if has_snapshot:
            return False

    recompute_summary(db, scope, month, start, month_end, version)
    db.commit()
    return True


def read_daily_series(
    db: Session,
    scope: str,
    start: datetime,
    month_end: datetime,
) -> List[Dict[str, Any]]:
    """Revenue/qty per day for the month (for the analytics trend chart).

    Only the requested month is scanned and at most ~31 rows are returned, so
    this stays cheap. It is called from the summary endpoint, which the client
    only requests when the version probe reports a change.
    """
    day_col = func.date(ImportedSale.sale_date)
    rows = (
        _scope_query(db, scope, start, month_end)
        .with_entities(
            day_col.label("day"),
            func.coalesce(func.sum(ImportedSale.qty), 0).label("qty"),
            func.coalesce(func.sum(ImportedSale.margin), 0).label("margin"),
            func.coalesce(func.sum(ImportedSale.total_amount), 0).label(
                "revenue"
            ),
        )
        .group_by(day_col)
        .order_by(day_col.asc())
        .all()
    )
    returns = (
        _scope_return_query(db, scope, start, month_end)
        .with_entities(
            func.date(ImportedReturn.sale_date).label("day"),
            func.coalesce(func.sum(ImportedReturn.margin), 0).label("margin"),
            func.coalesce(func.sum(ImportedReturn.revenue), 0).label("revenue"),
        )
        .group_by(func.date(ImportedReturn.sale_date))
        .all()
    )
    returns_by_day = {
        row.day: (int(row.revenue or 0), int(row.margin or 0))
        for row in returns
    }

    series: List[Dict[str, Any]] = []
    for row in rows:
        day = row.day
        returned_revenue, returned_margin = returns_by_day.pop(day, (0, 0))
        series.append(
            {
                "date": day.isoformat() if hasattr(day, "isoformat") else str(day),
                "qty": int(row.qty or 0),
                "margin": int(row.margin or 0) - returned_margin,
                "revenue": int(row.revenue or 0) - returned_revenue,
            }
        )
    for day, (returned_revenue, returned_margin) in returns_by_day.items():
        series.append({
            "date": day.isoformat() if hasattr(day, "isoformat") else str(day),
            "qty": 0,
            "margin": -returned_margin,
            "revenue": -returned_revenue,
        })
    series.sort(key=lambda item: item["date"])
    return series


def read_sales_daily_series(
    db: Session,
    scope: str,
    start: datetime,
    month_end: datetime,
    limit: int = SALES_TREND_TOP_N,
) -> List[Dict[str, Any]]:
    """Daily NET revenue for the top sales people in the selected month."""
    sales_dimension_key, _ = _dimension_columns(SALES_DIMENSION)
    sales_rows = (
        _scope_query(db, scope, start, month_end)
        .with_entities(
            func.date(ImportedSale.sale_date).label("day"),
            ImportedSale.branch.label("branch"),
            ImportedSale.sales_kode.label("kode"),
            ImportedSale.sales_nama.label("nama"),
            func.coalesce(func.sum(ImportedSale.total_amount), 0).label(
                "revenue"
            ),
        )
        .group_by(
            func.date(ImportedSale.sale_date),
            ImportedSale.branch,
            ImportedSale.sales_kode,
            ImportedSale.sales_nama,
        )
        .order_by(sales_dimension_key.asc())
        .all()
    )
    return_rows = (
        _scope_return_query(db, scope, start, month_end)
        .with_entities(
            func.date(ImportedReturn.sale_date).label("day"),
            ImportedReturn.branch.label("branch"),
            ImportedReturn.sales_nama.label("nama"),
            func.coalesce(func.sum(ImportedReturn.revenue), 0).label("revenue"),
        )
        .group_by(
            func.date(ImportedReturn.sale_date),
            ImportedReturn.branch,
            ImportedReturn.sales_nama,
        )
        .all()
    )
    sales_by_key: Dict[str, Dict[Any, int]] = {}
    sales_keys_by_name: Dict[str, str] = {}
    for row in sales_rows:
        key = _normalized_key(f"{row.branch or ''}|{row.kode or row.nama}")
        if not key:
            continue
        sales_by_key.setdefault(key, {})[row.day] = (
            sales_by_key.setdefault(key, {}).get(row.day, 0)
            + int(row.revenue or 0)
        )
        name_key = _normalized_key(f"{row.branch or ''}|{row.nama}")
        if name_key:
            sales_keys_by_name.setdefault(name_key, key)
    returns_by_key: Dict[str, Dict[Any, int]] = {}
    for row in return_rows:
        name_key = _normalized_key(f"{row.branch or ''}|{row.nama}")
        key = sales_keys_by_name.get(name_key, name_key)
        if not key:
            continue
        returns_by_key.setdefault(key, {})[row.day] = (
            returns_by_key.setdefault(key, {}).get(row.day, 0)
            + int(row.revenue or 0)
        )

    top_rows = _dimension_rows(
        db, scope, start, month_end, SALES_DIMENSION
    )[:limit]
    series: List[Dict[str, Any]] = []
    for row in top_rows:
        key = _normalized_key(row["dim_key"])
        if not key:
            continue
        daily_sales = sales_by_key.get(key, {})
        daily_returns = returns_by_key.get(key, {})
        days = sorted(set(daily_sales) | set(daily_returns))
        points = [
            {
                "date": day.isoformat() if hasattr(day, "isoformat") else str(day),
                "revenue": daily_sales.get(day, 0) - daily_returns.get(day, 0),
            }
            for day in days
        ]
        series.append(
            {
                "sales_kode": _as_text(row["dim_key"], 100),
                "sales_nama": _as_text(row["dim_label"], 200),
                "revenue": int(row["revenue"]),
                "points": points,
            }
        )
    return series


def _or_none(value: str) -> Optional[str]:
    return value if value else None


def read_summary(
    db: Session,
    scope: str,
    month: str,
    dimensions: Iterable[str],
    limit: int,
    include_all_sales: bool = False,
) -> Dict[str, Any]:
    """Read the precomputed snapshot in the original endpoint response shape.

    ``dimensions`` are the lowercase sections requested via ``include``.
    """
    normalized_dimensions = {d.lower() for d in dimensions}
    wanted = {TOTAL_DIMENSION}
    wanted.update(d.upper() for d in normalized_dimensions)
    if "supplier_retur" in normalized_dimensions:
        wanted.add(RETURN_SUPPLIER_DIMENSION)

    rows = (
        db.query(ImportedSalesMonthlySummary)
        .filter(
            ImportedSalesMonthlySummary.scope == scope,
            ImportedSalesMonthlySummary.month == month,
            ImportedSalesMonthlySummary.dimension.in_(sorted(wanted)),
        )
        .order_by(
            ImportedSalesMonthlySummary.dimension.asc(),
            ImportedSalesMonthlySummary.revenue.desc(),
            func.coalesce(ImportedSalesMonthlySummary.dim_label, "").asc(),
            ImportedSalesMonthlySummary.dim_key.asc(),
        )
        .all()
    )

    result: Dict[str, Any] = {
        "total_revenue": 0,
        "total_qty": 0,
        "total_margin": 0,
        "total_retur_revenue": 0,
        "total_retur_margin": 0,
        "total_retur_rows": 0,
        "imported_rows": 0,
        "effective_calls": 0,
        "active_outlets": 0,
        "by_product": [],
        "by_sales": [],
        "by_customer": [],
        "by_channel": [],
        "by_divisi": [],
        "by_supplier": [],
        "by_supplier_retur": [],
    }

    for row in rows:
        if row.dimension == TOTAL_DIMENSION:
            result["total_revenue"] = int(row.revenue or 0)
            result["total_qty"] = int(row.qty or 0)
            result["total_margin"] = int(row.margin or 0)
            result["total_retur_revenue"] = int(row.retur_revenue or 0)
            result["total_retur_margin"] = int(row.retur_margin or 0)
            result["total_retur_rows"] = int(row.retur_rows or 0)
            result["imported_rows"] = int(row.row_count or 0)
            result["effective_calls"] = int(row.effective_call_count or 0)
            result["active_outlets"] = int(row.active_outlet_count or 0)
            continue

        # Per-dimension rows are already ordered by revenue; enforce the
        # request's top-N without another query.
        if row.dimension == PRODUCT_DIMENSION:
            bucket = result["by_product"]
            if len(bucket) >= limit:
                continue
            bucket.append(
                {
                    "product_nama": _or_none(row.dim_label),
                    "mother_sku": _or_none(row.mother_sku),
                    "product_kode": _or_none(row.product_kode),
                    "qty": int(row.qty or 0),
                    "revenue": int(row.revenue or 0),
                    "margin": int(row.margin or 0),
                }
            )
        elif row.dimension == SALES_DIMENSION:
            bucket = result["by_sales"]
            if not include_all_sales and len(bucket) >= limit:
                continue
            bucket.append(
                {
                    "sales_kode": _or_none(row.dim_key.split("|", 1)[1] if "|" in row.dim_key else row.dim_key),
                    "sales_nama": _or_none(row.dim_label),
                    "qty": int(row.qty or 0),
                    "revenue": int(row.revenue or 0),
                    "margin": int(row.margin or 0),
                }
            )
        elif row.dimension == CUSTOMER_DIMENSION:
            bucket = result["by_customer"]
            if len(bucket) >= limit:
                continue
            bucket.append(
                {
                    "customer_kode": _or_none(row.dim_key),
                    "customer_nama": _or_none(row.dim_label),
                    "qty": int(row.qty or 0),
                    "revenue": int(row.revenue or 0),
                    "margin": int(row.margin or 0),
                }
            )
        elif row.dimension == CHANNEL_DIMENSION:
            bucket = result["by_channel"]
            if len(bucket) >= limit:
                continue
            bucket.append(
                {
                    "channel": _or_none(row.dim_key),
                    "qty": int(row.qty or 0),
                    "revenue": int(row.revenue or 0),
                    "margin": int(row.margin or 0),
                }
            )
        elif row.dimension == DIVISI_DIMENSION:
            bucket = result["by_divisi"]
            if len(bucket) >= limit:
                continue
            bucket.append(
                {
                    "divisi": _or_none(row.dim_label) or _or_none(row.dim_key),
                    "qty": int(row.qty or 0),
                    "revenue": int(row.revenue or 0),
                    "margin": int(row.margin or 0),
                }
            )
        elif row.dimension == SUPPLIER_DIMENSION:
            bucket = result["by_supplier"]
            if len(bucket) >= limit:
                continue
            bucket.append(
                {
                    "supplier": _or_none(row.dim_label) or _or_none(row.dim_key),
                    "qty": int(row.qty or 0),
                    "revenue": int(row.revenue or 0),
                    "margin": int(row.margin or 0),
                }
            )
        elif row.dimension == RETURN_SUPPLIER_DIMENSION:
            bucket = result["by_supplier_retur"]
            if len(bucket) >= RETURN_SUPPLIER_SNAPSHOT_TOP_N:
                continue
            bucket.append(
                {
                    "supplier": _or_none(row.dim_label) or _or_none(row.dim_key),
                    "revenue": int(row.revenue or 0),
                    "margin": int(row.margin or 0),
                    "row_count": int(row.row_count or 0),
                    "supplier_net_revenue": int(
                        row.supplier_net_revenue or 0
                    ),
                }
            )

    return result


def read_summary_range(
    db: Session,
    scope: str,
    start: datetime,
    month_end: datetime,
    dimensions: Iterable[str],
    limit: int,
    include_all_sales: bool = False,
) -> Dict[str, Any]:
    """Aggregate a multi-month range from source rows, netting returns first."""
    sales_totals = _scope_query(db, scope, start, month_end).with_entities(
        func.coalesce(func.sum(ImportedSale.total_amount), 0),
        func.coalesce(func.sum(ImportedSale.qty), 0),
        func.coalesce(func.sum(ImportedSale.margin), 0),
        func.count(ImportedSale.id),
        _distinct_identity_count(ImportedSale.trans_no),
        _distinct_identity_count(ImportedSale.customer_kode),
    ).one()
    return_totals = _scope_return_query(
        db, scope, start, month_end
    ).with_entities(
        func.coalesce(func.sum(ImportedReturn.revenue), 0),
        func.coalesce(func.sum(ImportedReturn.margin), 0),
        func.count(ImportedReturn.id),
    ).one()
    result: Dict[str, Any] = {
        "total_revenue": int(sales_totals[0] or 0) - int(return_totals[0] or 0),
        "total_qty": int(sales_totals[1] or 0),
        "total_margin": int(sales_totals[2] or 0) - int(return_totals[1] or 0),
        "total_retur_revenue": int(return_totals[0] or 0),
        "total_retur_margin": int(return_totals[1] or 0),
        "total_retur_rows": int(return_totals[2] or 0),
        "imported_rows": int(sales_totals[3] or 0),
        "effective_calls": int(sales_totals[4] or 0),
        "active_outlets": int(sales_totals[5] or 0),
        "by_product": [],
        "by_sales": [],
        "by_customer": [],
        "by_channel": [],
        "by_divisi": [],
        "by_supplier": [],
        "by_supplier_retur": [],
    }

    dimension_map = {
        "product": (PRODUCT_DIMENSION, "by_product"),
        "sales": (SALES_DIMENSION, "by_sales"),
        "customer": (CUSTOMER_DIMENSION, "by_customer"),
        "channel": (CHANNEL_DIMENSION, "by_channel"),
        "divisi": (DIVISI_DIMENSION, "by_divisi"),
        "supplier": (SUPPLIER_DIMENSION, "by_supplier"),
    }
    requested = {dimension.lower() for dimension in dimensions}
    for normalized, (dimension, bucket_name) in dimension_map.items():
        if normalized not in requested:
            continue
        groups = _dimension_rows(
            db, scope, start, month_end, dimension
        )
        if normalized != "sales" or not include_all_sales:
            groups = groups[:limit]
        for group in groups:
            item = {
                "qty": group["qty"],
                "revenue": group["revenue"],
                "margin": group["margin"],
            }
            if normalized == "product":
                item.update({
                    "product_kode": _or_none(
                        _as_text(group["product_kode"], 50)
                    ),
                    "product_nama": _or_none(
                        _as_text(group["dim_label"], 200)
                    ),
                    "mother_sku": _or_none(
                        _as_text(group["mother_sku"], 100)
                    ),
                })
            elif normalized == "sales":
                item.update({
                    "sales_kode": _or_none(
                        _as_text(group["dim_key"], 100).split("|", 1)[1]
                        if "|" in _as_text(group["dim_key"], 100)
                        else _as_text(group["dim_key"], 100)
                    ),
                    "sales_nama": _or_none(
                        _as_text(group["dim_label"], 200)
                    ),
                })
            elif normalized == "customer":
                item.update({
                    "customer_kode": _or_none(
                        _as_text(group["dim_key"], 100)
                    ),
                    "customer_nama": _or_none(
                        _as_text(group["dim_label"], 200)
                    ),
                })
            elif normalized == "channel":
                item["channel"] = _or_none(
                    _as_text(group["dim_key"], 100)
                )
            elif normalized == "divisi":
                item["divisi"] = _or_none(
                    _as_text(group["dim_label"], 200)
                ) or _or_none(_as_text(group["dim_key"], 100))
            else:
                item["supplier"] = _or_none(
                    _as_text(group["dim_label"], 200)
                ) or _or_none(_as_text(group["dim_key"], 100))
            result[bucket_name].append(item)

    if "supplier_retur" in requested:
        supplier_groups = _return_supplier_groups(
            db, scope, start, month_end
        )
        result["by_supplier_retur"] = [
            {
                "supplier": _or_none(group["dim_label"])
                or _or_none(group["dim_key"]),
                "revenue": group["retur_revenue"],
                "margin": group["retur_margin"],
                "row_count": group["retur_rows"],
                "supplier_net_revenue": group["revenue"],
            }
            for group in supplier_groups
            if group["retur_rows"]
        ]
    return result


def read_monthly_comparison(
    db: Session,
    scope: str,
    start: datetime,
    month_end: datetime,
) -> List[Dict[str, Any]]:
    """Net omzet per bulan (omzet − retur) untuk semua bulan dalam rentang.

    Digunakan chip pembanding di dashboard: N bulan *sebelum* bulan terpilih.
    Setiap entri berisi ``month`` (YYYY-MM), ``net_revenue``,
    ``gross_revenue``, ``retur_revenue``, dan ``rows``. Bulan tanpa data
    sama sekali tidak dikembalikan (frontend lewati saat menghitung rata-rata).
    """
    month_expr = func.to_char(ImportedSale.sale_date, "YYYY-MM").label("month")
    sales_rows = (
        _scope_query(db, scope, start, month_end)
        .with_entities(
            month_expr,
            func.coalesce(func.sum(ImportedSale.total_amount), 0).label(
                "gross_revenue"
            ),
            func.count(ImportedSale.id).label("rows"),
        )
        .group_by(month_expr)
        .all()
    )
    retur_expr = func.to_char(ImportedReturn.sale_date, "YYYY-MM").label("month")
    return_rows = (
        _scope_return_query(db, scope, start, month_end)
        .with_entities(
            retur_expr,
            func.coalesce(func.sum(ImportedReturn.revenue), 0).label(
                "retur_revenue"
            ),
        )
        .group_by(retur_expr)
        .all()
    )
    retur_by_month = {str(row[0]): int(row[1] or 0) for row in return_rows}
    result: List[Dict[str, Any]] = []
    for row in sales_rows:
        month_key = str(row[0])
        gross = int(row[1] or 0)
        retur = retur_by_month.get(month_key, 0)
        result.append(
            {
                "month": month_key,
                "gross_revenue": gross,
                "retur_revenue": retur,
                "net_revenue": gross - retur,
                "rows": int(row[2] or 0),
            }
        )
    result.sort(key=lambda item: item["month"])
    return result
