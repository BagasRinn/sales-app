"""Precomputed imported-sales summaries (Phase 2).

The summary endpoint used to aggregate every row of a month on each request
(``GROUP BY`` over ``imported_sales``). This module keeps a small precomputed
table instead:

* ``ImportedSalesMonthlySummary`` holds one ``TOTAL`` row plus the top
  ``SUMMARY_TOP_N`` groups for each breakdown (product/sales/customer/channel).
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

The read path only ever scans this small table (at most 5 dimensions × 100
rows), so DB→app egress is bounded even when ``imported_sales`` grows.
"""
from __future__ import annotations

from datetime import datetime
from typing import Any, Dict, Iterable, List, Optional, Tuple
from uuid import uuid4

from sqlalchemy import func
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.orm import Session

from app.models.models import (
    ImportedSale,
    ImportedSalesMonthlySummary,
    ImportedSalesSummaryState,
)
from app.services.db_locks import acquire_advisory_xact_lock
from app.services.sales_import_versions import GLOBAL_SCOPE

# The API caps `limit` at 100, so storing the top 100 per dimension is enough
# to satisfy every possible request. Totals are always stored in full.
SUMMARY_TOP_N = 100

# Number of sales lines drawn on the multi-series daily chart. Ten is enough to
# compare the top performers without turning the chart into a hairball.
SALES_TREND_TOP_N = 10

TOTAL_DIMENSION = "TOTAL"
PRODUCT_DIMENSION = "PRODUCT"
SALES_DIMENSION = "SALES"
CUSTOMER_DIMENSION = "CUSTOMER"
CHANNEL_DIMENSION = "CHANNEL"

DIMENSIONS: Tuple[str, ...] = (
    PRODUCT_DIMENSION,
    SALES_DIMENSION,
    CUSTOMER_DIMENSION,
    CHANNEL_DIMENSION,
)

# Grouping columns per dimension. The last column is used as the label
# (display name); the first as the key (code).
_GROUP_COLUMNS = {
    PRODUCT_DIMENSION: (ImportedSale.product_kode, ImportedSale.product_nama),
    SALES_DIMENSION: (ImportedSale.sales_kode, ImportedSale.sales_nama),
    CUSTOMER_DIMENSION: (ImportedSale.customer_kode, ImportedSale.customer_nama),
    CHANNEL_DIMENSION: (ImportedSale.channel,),
}


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


def _as_text(value: Any, limit: int) -> str:
    if value is None:
        return ""
    return str(value)[:limit]


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

    base = _scope_query(db, scope, start, month_end)
    revenue_sum = func.coalesce(func.sum(ImportedSale.total_amount), 0)
    qty_sum = func.coalesce(func.sum(ImportedSale.qty), 0)

    total_revenue, total_qty, row_count = base.with_entities(
        revenue_sum,
        qty_sum,
        func.count(ImportedSale.id),
    ).one()

    rows: List[ImportedSalesMonthlySummary] = [
        ImportedSalesMonthlySummary(
            scope=scope,
            month=month,
            dimension=TOTAL_DIMENSION,
            dim_key="",
            dim_label="",
            qty=int(total_qty or 0),
            revenue=int(total_revenue or 0),
            row_count=int(row_count or 0),
        )
    ]

    for dimension in DIMENSIONS:
        group_columns = _GROUP_COLUMNS[dimension]
        label_column = group_columns[-1]
        groups = (
            base.with_entities(
                *group_columns,
                qty_sum.label("qty"),
                revenue_sum.label("revenue"),
            )
            .group_by(*group_columns)
            .order_by(
                revenue_sum.desc(),
                func.coalesce(label_column, "").asc(),
                func.coalesce(group_columns[0], "").asc(),
            )
            .limit(SUMMARY_TOP_N)
            .all()
        )
        for group in groups:
            values = list(group)
            key = values[0]
            label = values[1] if len(group_columns) > 1 else None
            rows.append(
                ImportedSalesMonthlySummary(
                    scope=scope,
                    month=month,
                    dimension=dimension,
                    dim_key=_as_text(key, 100),
                    dim_label=_as_text(label, 200),
                    qty=int(group.qty or 0),
                    revenue=int(group.revenue or 0),
                    row_count=0,
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
            func.coalesce(func.sum(ImportedSale.total_amount), 0).label(
                "revenue"
            ),
        )
        .group_by(day_col)
        .order_by(day_col.asc())
        .all()
    )

    series: List[Dict[str, Any]] = []
    for row in rows:
        day = row.day
        series.append(
            {
                "date": day.isoformat() if hasattr(day, "isoformat") else str(day),
                "qty": int(row.qty or 0),
                "revenue": int(row.revenue or 0),
            }
        )
    return series


def read_sales_daily_series(
    db: Session,
    scope: str,
    start: datetime,
    month_end: datetime,
    limit: int = SALES_TREND_TOP_N,
) -> List[Dict[str, Any]]:
    """Daily revenue for the top ``limit`` sales people (multi-line chart).

    The first query picks the top-N sales by month revenue; the second groups
    the same month's rows per ``(day, sales)``. Only buckets belonging to the
    selected sales are kept, so the payload is bounded by ``limit * 31`` rows
    regardless of how many sales exist. Like the total series, this is only
    fetched when the summary version changes.
    """
    sales_revenue = func.coalesce(func.sum(ImportedSale.total_amount), 0)

    top_rows = (
        _scope_query(db, scope, start, month_end)
        .with_entities(
            ImportedSale.sales_kode.label("kode"),
            ImportedSale.sales_nama.label("nama"),
            sales_revenue.label("revenue"),
        )
        .group_by(ImportedSale.sales_kode, ImportedSale.sales_nama)
        .order_by(
            sales_revenue.desc(),
            func.coalesce(ImportedSale.sales_nama, "").asc(),
        )
        .limit(limit)
        .all()
    )
    if not top_rows:
        return []

    top_keys = [(_as_text(row.kode, 100), _as_text(row.nama, 200)) for row in top_rows]
    wanted = set(top_keys)

    day_col = func.date(ImportedSale.sale_date)
    daily_rows = (
        _scope_query(db, scope, start, month_end)
        .with_entities(
            day_col.label("day"),
            ImportedSale.sales_kode.label("kode"),
            ImportedSale.sales_nama.label("nama"),
            sales_revenue.label("revenue"),
        )
        .group_by(day_col, ImportedSale.sales_kode, ImportedSale.sales_nama)
        .order_by(day_col.asc())
        .all()
    )

    buckets: Dict[Tuple[str, str], List[Dict[str, Any]]] = {
        key: [] for key in top_keys
    }
    for row in daily_rows:
        key = (_as_text(row.kode, 100), _as_text(row.nama, 200))
        bucket = buckets.get(key)
        if bucket is None:
            continue
        day = row.day
        bucket.append(
            {
                "date": day.isoformat() if hasattr(day, "isoformat") else str(day),
                "revenue": int(row.revenue or 0),
            }
        )

    series: List[Dict[str, Any]] = []
    for key, row in zip(top_keys, top_rows):
        series.append(
            {
                "sales_kode": key[0],
                "sales_nama": key[1],
                "revenue": int(row.revenue or 0),
                "points": buckets.get(key, []),
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
) -> Dict[str, Any]:
    """Read the precomputed snapshot in the original endpoint response shape.

    ``dimensions`` are the lowercase sections requested via ``include``.
    """
    wanted = {TOTAL_DIMENSION}
    wanted.update(d.upper() for d in dimensions)

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
        "imported_rows": 0,
        "by_product": [],
        "by_sales": [],
        "by_customer": [],
        "by_channel": [],
    }

    for row in rows:
        if row.dimension == TOTAL_DIMENSION:
            result["total_revenue"] = int(row.revenue or 0)
            result["total_qty"] = int(row.qty or 0)
            result["imported_rows"] = int(row.row_count or 0)
            continue

        # Per-dimension rows are already ordered by revenue; enforce the
        # request's top-N without another query.
        if row.dimension == PRODUCT_DIMENSION:
            bucket = result["by_product"]
            if len(bucket) >= limit:
                continue
            bucket.append(
                {
                    "product_kode": _or_none(row.dim_key),
                    "product_nama": _or_none(row.dim_label),
                    "qty": int(row.qty or 0),
                    "revenue": int(row.revenue or 0),
                }
            )
        elif row.dimension == SALES_DIMENSION:
            bucket = result["by_sales"]
            if len(bucket) >= limit:
                continue
            bucket.append(
                {
                    "sales_kode": _or_none(row.dim_key),
                    "sales_nama": _or_none(row.dim_label),
                    "qty": int(row.qty or 0),
                    "revenue": int(row.revenue or 0),
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
                }
            )

    return result
