"""
Tambahkan kolom yang ada di Supabase LAMA tapi belum ada di Supabase BARU.
Jalankan SETELAH create_tables jika ada kolom yang missing.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from dotenv import load_dotenv

load_dotenv()

# Supabase BARU (tujuan) — dari .env
DEST_DATABASE_URL = os.getenv("DATABASE_URL", "")

if not DEST_DATABASE_URL:
    print("DATABASE_URL belum diset di .env")
    sys.exit(1)

import psycopg

url = DEST_DATABASE_URL.replace("postgresql+psycopg://", "postgresql://")

# Kolom yang perlu ditambahkan
ADDITIONS = [
    ("orders", "order_discount_type", "VARCHAR(10)", "DEFAULT 'PERCENT'"),
    ("orders", "order_discount_nominal", "INTEGER", "DEFAULT 0"),
    ("customer_registration_submissions", "kode_nama_salesman", "VARCHAR(200)", "NULL"),
]

with psycopg.connect(url) as conn:
    cursor = conn.cursor()

    # Cek kolom yang sudah ada
    cursor.execute("""
        SELECT table_name, column_name
        FROM information_schema.columns
        WHERE table_schema = 'public'
        AND table_name IN ('orders', 'customer_registration_submissions')
    """)
    existing = {(r[0], r[1]) for r in cursor.fetchall()}

    added = []
    skipped = []

    for table, col, col_type, constraint in ADDITIONS:
        if (table, col) in existing:
            skipped.append(f"{table}.{col}")
            continue

        sql = f"ALTER TABLE {table} ADD COLUMN {col} {col_type} {constraint}"
        cursor.execute(sql)
        conn.commit()
        added.append(f"{table}.{col}")
        print(f"  + {table}.{col} ({col_type})")

    if added:
        print(f"\nBerhasil ditambahkan: {len(added)} kolom")
    if skipped:
        print(f"Sudah ada (skip): {len(skipped)}")
    if not added and not skipped:
        print("Tidak ada kolom yang perlu ditambahkan")
