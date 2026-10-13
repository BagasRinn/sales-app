"""Diagnostic: count customers with empty/null alamat.

Run: venv/Scripts/python.exe scripts/_diag_empty_alamat.py
"""
from app.models.database import engine
from sqlalchemy import text

SQL_COUNT = """
SELECT
    COUNT(*) AS total,
    COUNT(*) FILTER (WHERE alamat IS NULL) AS null_count,
    COUNT(*) FILTER (WHERE alamat = '') AS empty_count,
    COUNT(*) FILTER (WHERE alamat IS NOT NULL AND alamat <> '' AND length(alamat) < 1) AS other_bad
FROM customers
WHERE deleted_at IS NULL
"""

SQL_SAMPLE = """
SELECT id, branch, kode, nama_toko, alamat, created_at
FROM customers
WHERE deleted_at IS NULL AND (alamat IS NULL OR alamat = '')
ORDER BY created_at DESC
LIMIT 12
"""

with engine.connect() as conn:
    row = conn.execute(text(SQL_COUNT)).fetchone()
    print(f"total active customers : {row.total}")
    print(f"  alamat IS NULL        : {row.null_count}")
    print(f"  alamat = '' (empty)   : {row.empty_count}")
    print(f"  other bad             : {row.other_bad}")
    print()
    print("Sample bad rows (up to 12):")
    for r in conn.execute(text(SQL_SAMPLE)).fetchall():
        print(f"  {r.id} | {r.branch} | kode={r.kode!r} | nama_toko={r.nama_toko!r} | alamat={r.alamat!r} | created={r.created_at}")
