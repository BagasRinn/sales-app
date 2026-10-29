#!/usr/bin/env python3
"""
Migrasi data dari Supabase lama -> Supabase baru via psycopg2 raw.
Hanya copy DATA (bukan schema), urut berdasarkan FK dependency.
Menggunakan psycopg2 langsung dengan autocommit untuk bypass timeout.
"""

import os

import psycopg2
from psycopg2.extras import RealDictCursor

# ====== KONFIGURASI ======
# Kredensial DIBACA DARI ENVIRONMENT — jangan hardcode credential di sini
# (repo ini public; credential yang ter-commit harus dianggap bocor).
# Windows PowerShell:
#   $env:SRC_DATABASE_URL = "postgresql://postgres.<ref>:<password>@aws-0-<region>.pooler.supabase.com:5432/postgres"
#   $env:DST_DATABASE_URL = "postgresql://postgres.<ref>:<password>@aws-0-<region>.pooler.supabase.com:5432/postgres"
SRC_URL = os.environ.get("SRC_DATABASE_URL", "")
DST_URL = os.environ.get("DST_DATABASE_URL", "")

if not SRC_URL or not DST_URL:
    raise SystemExit(
        "Set environment variables SRC_DATABASE_URL dan DST_DATABASE_URL "
        "sebelum menjalankan script ini (lihat komentar di atas)."
    )

# Urutan tabel: parent dulu, child belak (FK safe)
TABLE_ORDER = [
    "branches",
    "users",
    "customers",
    "products",
    "suppliers",
    "customer_assignments",
    "orders",
    "order_items",
    "stok_log",
    "sales_targets",
    "supplier_targets",
    "bulletins",
    "bulletin_dismisses",
]

BATCH_SIZE = 100


def get_conn(url):
    conn = psycopg2.connect(url, connect_timeout=10, options="-c statement_timeout=0")
    conn.autocommit = True  # penting untuk SET session_replication_role
    return conn


def get_columns(src_cur, table_name):
    src_cur.execute(f"""
        SELECT column_name 
        FROM information_schema.columns 
        WHERE table_name = '{table_name}' 
        ORDER BY ordinal_position
    """)
    return [row[0] for row in src_cur.fetchall()]


def copy_table(src_cur, dst_cur, table_name):
    cols = get_columns(src_cur, table_name)
    col_list = ", ".join(f'"{c}"' for c in cols)
    placeholders = ", ".join(["%s"] * len(cols))

    # Get primary key columns for ON CONFLICT
    src_cur.execute(f"""
        SELECT a.attname
        FROM pg_index i
        JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
        WHERE i.indrelid = '{table_name}'::regclass AND i.indisprimary
    """)
    pk_cols = [row[0] for row in src_cur.fetchall()]
    
    # Select dari source
    src_cur.execute(f'SELECT {col_list} FROM "{table_name}"')
    rows = src_cur.fetchall()

    if not rows:
        print(f"  {table_name}: 0 rows")
        return

    # Batch insert with ON CONFLICT DO NOTHING (skip TRUNCATE to avoid timeout)
    inserted = 0
    if pk_cols:
        pk_list = ", ".join(f'"{c}"' for c in pk_cols)
        # Non-PK columns for UPDATE
        non_pk_cols = [c for c in cols if c not in pk_cols]
        if non_pk_cols:
            update_cols = ", ".join(f'"{c}" = EXCLUDED."{c}"' for c in non_pk_cols)
            insert_sql = f'INSERT INTO "{table_name}" ({col_list}) VALUES ({placeholders}) ON CONFLICT ({pk_list}) DO UPDATE SET {update_cols}'
        else:
            insert_sql = f'INSERT INTO "{table_name}" ({col_list}) VALUES ({placeholders}) ON CONFLICT ({pk_list}) DO NOTHING'
    else:
        insert_sql = f'INSERT INTO "{table_name}" ({col_list}) VALUES ({placeholders})'

    for i in range(0, len(rows), BATCH_SIZE):
        batch = rows[i:i + BATCH_SIZE]
        dst_cur.executemany(insert_sql, batch)
        inserted += len(batch)

    print(f"  {table_name}: {inserted} rows")


def main():
    print("Connecting to source & destination...")
    src_conn = get_conn(SRC_URL)
    dst_conn = get_conn(DST_URL)

    src_cur = src_conn.cursor()
    dst_cur = dst_conn.cursor()

    try:
        # Disable FK checks sementara
        dst_cur.execute("SET session_replication_role = replica")

        for tbl in TABLE_ORDER:
            print(f"Copying {tbl}...")
            try:
                copy_table(src_cur, dst_cur, tbl)
            except psycopg2.errors.UndefinedTable:
                print(f"  {tbl}: SKIP (not in source)")

        dst_cur.execute("SET session_replication_role = DEFAULT")
        print("\n✅ Migrasi selesai!")

    except Exception as e:
        dst_cur.execute("SET session_replication_role = DEFAULT")
        raise
    finally:
        src_cur.close()
        dst_cur.close()
        src_conn.close()
        dst_conn.close()


if __name__ == "__main__":
    main()