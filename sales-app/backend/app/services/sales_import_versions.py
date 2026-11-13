"""Version counters for imported-sales summaries.

Design goals (egress-aware):

* A version row exists per ``(scope, month)``. ``scope`` is a branch code or
  the literal ``GLOBAL`` for a global MANAGER.
* ``GET /sales-imports/version`` is tiny and ``Cache-Control: no-store``.
  Clients call it on tab open/focus, month change, manual refresh and after
  import. They only download the (larger) summary when the version changed.
* A successful import bumps the branch scope **and** ``GLOBAL`` for every
  ``(branch, month)`` where a row was inserted or its data changed. A failed
  import bumps nothing because the bump happens in the same DB transaction as
  the rows. A pure re-import that only matches unchanged rows bumps nothing.

This module deliberately contains no HTTP concerns beyond resolving the
scope from the authenticated user dict.
"""
from __future__ import annotations

from datetime import datetime
from typing import Any, Dict, Iterable, List, Optional, Tuple
from uuid import uuid4

from fastapi import HTTPException, status
from sqlalchemy import func
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.orm import Session

from app.core.branch import is_valid_branch
from app.core.security import is_global_manager
from app.models.models import SalesImportVersion

GLOBAL_SCOPE = "GLOBAL"


def resolve_scope(
    current_user: Dict[str, Any],
    branch: Optional[str] = None,
) -> str:
    """Return the version scope for the current user.

    Global MANAGER -> ``GLOBAL`` by default, or the requested branch when the
    dashboard branch filter is used. Everyone else -> their own branch; a
    branch override is rejected so a branch-scoped user can never read another
    branch's data.

    Fail closed when a non-manager account has no branch.
    """
    requested = branch.strip().upper() if branch and branch.strip() else None

    if is_global_manager(current_user):
        if requested is None or requested == GLOBAL_SCOPE:
            return GLOBAL_SCOPE
        if not is_valid_branch(requested):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Cabang tidak dikenal",
            )
        return requested

    user_branch = current_user.get("branch")
    if not user_branch:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Akun Anda belum memiliki cabang. Hubungi manager.",
        )
    if requested is not None and requested != str(user_branch).upper():
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Anda hanya dapat melihat data cabang sendiri.",
        )
    return user_branch


def parse_month(month: Optional[str]) -> Tuple[str, datetime, datetime]:
    """Validate ``YYYY-MM`` and return (normalized, period_start, period_end)."""
    if not month:
        now = datetime.now()
        month = f"{now.year:04d}-{now.month:02d}"
    try:
        year, month_num = map(int, month.split("-"))
        if not (1 <= month_num <= 12):
            raise ValueError
    except (ValueError, AttributeError):
        raise HTTPException(status_code=400, detail="month harus format YYYY-MM")

    start = datetime(year, month_num, 1)
    month_end = (
        datetime(year + 1, 1, 1)
        if month_num == 12
        else datetime(year, month_num + 1, 1)
    )
    return f"{year:04d}-{month_num:02d}", start, month_end


def get_version(
    db: Session, scope: str, month: str
) -> Tuple[int, Optional[datetime]]:
    """Read the current version without creating a row.

    Missing row means version 0 (nothing imported for that scope/month yet).
    """
    row = (
        db.query(SalesImportVersion)
        .filter(
            SalesImportVersion.scope == scope,
            SalesImportVersion.month == month,
        )
        .first()
    )
    if row is None:
        return 0, None
    return int(row.version or 0), row.updated_at


def months_in_range(end_month: str, range_months: int) -> List[str]:
    """Return ordered YYYY-MM keys for a range ending at ``end_month``."""
    if range_months not in (1, 3, 6, 12):
        raise HTTPException(
            status_code=400,
            detail="range_months harus salah satu dari 1, 3, 6, atau 12",
        )
    year, month = map(int, end_month.split("-"))
    end_index = year * 12 + month - 1
    result = []
    for offset in range(range_months - 1, -1, -1):
        index = end_index - offset
        result.append(f"{index // 12:04d}-{index % 12 + 1:02d}")
    return result


def months_before(end_month: str, count: int) -> List[str]:
    """Return ``count`` YYYY-MM keys strictly *before* ``end_month``.

    The comparison chips on the dashboard use the N months preceding the
    selected month (the selected month itself is never part of the baseline),
    so this differs from :func:`months_in_range`, which includes ``end_month``.
    """
    year, month = map(int, end_month.split("-"))
    end_index = year * 12 + month - 1
    result = []
    for offset in range(count, 0, -1):
        index = end_index - offset
        result.append(f"{index // 12:04d}-{index % 12 + 1:02d}")
    return result


def get_range_version(
    db: Session,
    scope: str,
    end_month: str,
    range_months: int,
) -> Tuple[int, Optional[datetime]]:
    """Return a cache version that changes when any month in the range changes."""
    months = months_in_range(end_month, range_months)
    version_sum, updated_at = (
        db.query(
            func.coalesce(func.sum(SalesImportVersion.version), 0),
            func.max(SalesImportVersion.updated_at),
        )
        .filter(
            SalesImportVersion.scope == scope,
            SalesImportVersion.month.in_(months),
        )
        .one()
    )
    return int(version_sum or 0), updated_at


def bump_versions(
    db: Session,
    scopes: Iterable[str],
    months: Iterable[str],
) -> List[Dict[str, Any]]:
    """Atomically increment version rows for every (scope, month).

    Uses PostgreSQL ``INSERT ... ON CONFLICT DO UPDATE`` so two concurrent
    imports cannot lose an increment. Must be called inside the import
    transaction; the caller commits once for rows + versions.

    Returns the post-bump values so the import response can include them.
    """
    unique_scopes = [s for s in dict.fromkeys(scopes) if s]
    unique_months = [m for m in dict.fromkeys(months) if m]
    bumped: List[Dict[str, Any]] = []

    for scope in unique_scopes:
        for month in unique_months:
            stmt = pg_insert(SalesImportVersion).values(
                id=uuid4(),
                scope=scope,
                month=month,
                version=1,
            )
            stmt = stmt.on_conflict_do_update(
                index_elements=[
                    SalesImportVersion.scope,
                    SalesImportVersion.month,
                ],
                set_={
                    "version": SalesImportVersion.version + 1,
                    "updated_at": func.now(),
                },
            ).returning(
                SalesImportVersion.version,
                SalesImportVersion.updated_at,
            )
            row = db.execute(stmt).one()
            bumped.append(
                {
                    "month": month,
                    "scope": scope,
                    "version": int(row.version or 0),
                    "updated_at": row.updated_at,
                }
            )

    return bumped


def bump_versions_for_changes(
    db: Session,
    changes: Iterable[Tuple[Optional[str], str]],
) -> List[Dict[str, Any]]:
    """Bump only the ``(scope, month)`` pairs affected by real changes.

    ``changes`` contains ``(branch_or_None, month)`` for rows that were
    inserted or whose data changed. For every such month we bump ``GLOBAL``
    once plus each affected branch, instead of the full scope × month
    cross-product. A pure re-import (no data changes) passes an empty set and
    bumps nothing.
    """
    by_month: Dict[str, set[str]] = {}
    for branch, month in changes:
        if not month:
            continue
        scopes = by_month.setdefault(month, {GLOBAL_SCOPE})
        if branch:
            scopes.add(branch)

    bumped: List[Dict[str, Any]] = []
    for month in sorted(by_month):
        bumped.extend(bump_versions(db, sorted(by_month[month]), [month]))
    return bumped
