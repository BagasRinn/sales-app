"""Warm the precomputed imported-sales summary snapshots.

Phase 2 rebuilds the snapshot automatically inside every successful import and
the summary endpoint lazily backfills missing/stale snapshots. This script is
optional: run it once after deploying to warm every existing ``(scope, month)``
so the first dashboard request does not pay the one-time aggregation cost.

Usage (from ``sales-app/backend``)::

    python scripts/backfill_sales_summary.py
    python scripts/backfill_sales_summary.py --month 2026-01
    python scripts/backfill_sales_summary.py --dry-run

It is safe to re-run: each target is recomputed from scratch and committed per
``(scope, month)``.
"""
import argparse
import os
import sys

from dotenv import load_dotenv

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, ROOT)
load_dotenv(os.path.join(ROOT, ".env"))

from sqlalchemy import text  # noqa: E402

from app.models.database import SessionLocal  # noqa: E402
from app.services.sales_import_versions import (  # noqa: E402
    GLOBAL_SCOPE,
    get_version,
    parse_month,
)
from app.services.sales_summary_service import recompute_summary  # noqa: E402


def _collect_targets(db, month_filter):
    """Return ``{month: {scopes}}`` for data + version rows already in the DB."""
    targets: dict[str, set[str]] = {}

    data_rows = db.execute(
        text(
            "SELECT DISTINCT to_char(sale_date, 'YYYY-MM') AS month, branch "
            "FROM imported_sales WHERE sale_date IS NOT NULL"
        )
    ).all()
    for row in data_rows:
        month = row.month
        if month_filter and month != month_filter:
            continue
        scopes = targets.setdefault(month, {GLOBAL_SCOPE})
        if row.branch:
            scopes.add(row.branch)

    version_rows = db.execute(
        text("SELECT DISTINCT month, scope FROM sales_import_versions")
    ).all()
    for row in version_rows:
        if month_filter and row.month != month_filter:
            continue
        # Global MANAGER sees every branch, so GLOBAL is always a target.
        targets.setdefault(row.month, {GLOBAL_SCOPE}).add(row.scope)

    return targets


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--month",
        help="Only backfill one month (YYYY-MM). Default: every month.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print targets without writing anything.",
    )
    args = parser.parse_args()

    if args.month:
        try:
            args.month, _, _ = parse_month(args.month)
        except Exception as exc:  # noqa: BLE001 - CLI feedback
            print(f"Invalid --month: {exc}")
            return 2

    db = SessionLocal()
    try:
        targets = _collect_targets(db, args.month)
        if not targets:
            print("No imported-sales data found; nothing to backfill.")
            return 0

        total = sum(len(scopes) for scopes in targets.values())
        print(f"Targets: {total} (scope, month) pair(s)")

        done = 0
        for month in sorted(targets):
            _, start, month_end = parse_month(month)
            for scope in sorted(targets[month]):
                version, _ = get_version(db, scope, month)
                label = f"{month} [{scope}] version={version}"
                if args.dry_run:
                    print(f"  would recompute {label}")
                    continue
                recompute_summary(db, scope, month, start, month_end, version)
                db.commit()
                done += 1
                print(f"  recomputed {label}")

        if args.dry_run:
            print("Dry run complete; nothing written.")
        else:
            print(f"Backfill complete: {done} snapshot(s) rebuilt.")
        return 0
    finally:
        db.close()


if __name__ == "__main__":
    raise SystemExit(main())
