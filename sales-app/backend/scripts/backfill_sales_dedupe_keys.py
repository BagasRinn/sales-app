"""Assign dedupe keys to legacy ``imported_sales`` rows.

Phase 3 gives every imported row a deterministic ``dedupe_key``. Rows that
were imported before the column existed keep ``dedupe_key IS NULL``. The
import path lazily migrates the ``(branch, month)`` pairs it touches, so this
script is optional; run it once after deploying to migrate everything up
front and keep future imports from doing that work.

Usage (from ``sales-app/backend``)::

    python scripts/backfill_sales_dedupe_keys.py
    python scripts/backfill_sales_dedupe_keys.py --dry-run

It is safe to re-run: only rows with ``dedupe_key IS NULL`` are touched, and
occurrence suffixes continue after any key that already exists for the same
base.
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
from app.services.sales_import_upsert import backfill_dedupe_keys  # noqa: E402


def _pending_pairs(db):
    """Return ``(branch, month)`` pairs that still have unkeyed rows."""
    rows = db.execute(
        text(
            "SELECT DISTINCT branch, to_char(sale_date, 'YYYY-MM') AS month "
            "FROM imported_sales "
            "WHERE dedupe_key IS NULL AND sale_date IS NOT NULL"
        )
    ).all()
    return [(row.branch, row.month) for row in rows]


def _pending_count(db) -> int:
    return int(
        db.execute(
            text(
                "SELECT COUNT(*) FROM imported_sales WHERE dedupe_key IS NULL"
            )
        ).scalar()
        or 0
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print pending work without writing anything.",
    )
    args = parser.parse_args()

    db = SessionLocal()
    try:
        pairs = _pending_pairs(db)
        pending = _pending_count(db)
        if pending == 0:
            print("No legacy rows without dedupe_key; nothing to backfill.")
            return 0

        print(f"Pending rows: {pending} across {len(pairs)} (branch, month) pair(s)")

        if args.dry_run:
            for branch, month in sorted(pairs, key=lambda p: (p[1], p[0] or "")):
                label = f"{month} [{branch or 'GLOBAL'}]"
                print(f"  would key rows in {label}")
            print("Dry run complete; nothing written.")
            return 0

        migrated = 0
        for branch, month in sorted(pairs, key=lambda p: (p[1], p[0] or "")):
            count = backfill_dedupe_keys(db, pairs={(branch, month)})
            db.commit()
            migrated += count
            label = f"{month} [{branch or 'GLOBAL'}]"
            print(f"  keyed {count} row(s) in {label}")

        # Rows without a sale_date cannot be grouped by month; key them by
        # base alone so a future import still cannot duplicate them.
        remaining = _pending_count(db)
        if remaining:
            count = backfill_dedupe_keys(db)
            db.commit()
            migrated += count
            print(f"  keyed {count} row(s) without a sale_date")

        print(f"Backfill complete: {migrated} row(s) keyed.")
        return 0
    finally:
        db.close()


if __name__ == "__main__":
    raise SystemExit(main())
