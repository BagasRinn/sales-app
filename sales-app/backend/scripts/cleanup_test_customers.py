"""Cleanup customers imported by the test fixture (4 branches).

Menghapus SEMUA customer dengan kode prefix berikut, per branch yang sesuai:

    BATULICIN      BL-C%
    BARABAI        BR-C%
    PALANGKARAYA   PK-C%
    SAMPIT         SP-C%

TIDAK menyentuh customer BANJARMASIN (prefix `BM-C%` atau tanpa prefix) — itu
branch pre-existing yang bukan target test ini.

CARA PAKAI:
    cd sales-app/backend
    python scripts/cleanup_test_customers.py

Script ini IDEMPOTENT — kalau belum ada data test, tidak error. Akan
print "0 rows, skip" dan exit normal.

Untuk safety, by default pakai DRY-RUN supaya Anda bisa preview dulu
jumlah baris yang akan dihapus. Pakai `--apply` untuk benar-benar hapus.

Ref: sales-app/backend/tests/fixtures/README.md
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import text
from app.models.database import engine

# (branch, kode_prefix). Selaras dengan _gen_test_import_fixture.py.
TARGETS = [
    ("BATULICIN",     "BL-C"),
    ("BARABAI",       "BR-C"),
    ("PALANGKARAYA",  "PK-C"),
    ("SAMPIT",        "SP-C"),
]


def _count(conn, branch: str, prefix: str) -> int:
    return conn.execute(
        text(
            "SELECT COUNT(*) FROM customers "
            "WHERE branch = :branch AND kode LIKE :prefix"
        ),
        {"branch": branch, "prefix": f"{prefix}%"},
    ).scalar_one()


def _delete(conn, branch: str, prefix: str) -> int:
    result = conn.execute(
        text(
            "DELETE FROM customers "
            "WHERE branch = :branch AND kode LIKE :prefix"
        ),
        {"branch": branch, "prefix": f"{prefix}%"},
    )
    return result.rowcount


def run(apply: bool):
    verb = "DELETING" if apply else "DRY-RUN (would delete)"
    print(f"[CLEANUP] {verb} test customers across 4 branches\n")

    total = 0
    with engine.connect() as conn:
        for branch, prefix in TARGETS:
            count = _count(conn, branch, prefix)
            if count == 0:
                print(f"  {branch:14s} {prefix}-% → 0 rows, skip")
                continue

            if apply:
                deleted = _delete(conn, branch, prefix)
                conn.commit()
                print(f"  {branch:14s} {prefix}-% → {deleted} rows DELETED")
                total += deleted
            else:
                print(f"  {branch:14s} {prefix}-% → {count} rows (would delete)")
                total += count

    print(f"\n[CLEANUP] Total: {total} rows")
    if not apply:
        print("         Ini DRY-RUN. Jalankan dengan --apply untuk benar-benar hapus.")
    else:
        print("         Done.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Lakukan DELETE. Default: dry-run (preview saja).",
    )
    args = parser.parse_args()
    run(apply=args.apply)
