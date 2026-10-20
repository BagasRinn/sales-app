"""
Migrasi Data dari Supabase LAMA ke Supabase BARU.

Usage:
    # 1. Set SOURCE_DATABASE_URL ke Supabase lama (.env masih menunjuk ke baru)
    $env:SOURCE_DATABASE_URL = "postgresql://postgres.lama:xxx@db.old.supabase.co:6543/postgres"

    # 2. Export dari Supabase lama
    python scripts/migrate_supabase.py --export-only

    # 3. Buat tabel di Supabase baru (jika belum ada)
    python scripts/create_tables_supabase.py

    # 4. Tambah kolom yang mungkin missing
    python scripts/add_missing_columns.py

    # 5. Import ke Supabase baru
    python scripts/migrate_supabase.py --import-only

    # 6. Verifikasi
    python scripts/migrate_supabase.py --verify
"""

import argparse
import json
import os
import sys
from datetime import datetime

# Import dari project
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from dotenv import load_dotenv

# Load .env (DATABASE_URL sekarang menunjuk ke Supabase BARU)
load_dotenv()

# Supabase BARU (tujuan) — dari .env
DEST_DATABASE_URL = os.getenv("DATABASE_URL", "")

# Supabase LAMA (sumber) — dari env variable
SOURCE_DATABASE_URL = os.getenv("SOURCE_DATABASE_URL", "")

EXPORTS_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "exports")


# Urutan tabel sesuai foreign key dependencies
TABLES = [
    ("branches", "code"),
    ("suppliers", "name"),
    ("users", "id"),
    ("products", ("id", "branch")),
    ("customers", "id"),
    ("customer_assignments", ("customer_id", "sales_id")),
    ("area_assignments", ("kode_area", "sales_id", "branch")),
    ("orders", "id"),
    ("order_items", "id"),
    ("stok_log", "id"),
    ("customer_registration_submissions", "id"),
    ("import_logs", "id"),
    ("sync_validation_errors", "id"),
    ("sales_targets", "id"),
    ("supplier_targets", ("branch", "supplier_name", "period")),
    ("bulletins", "id"),
    ("bulletin_dismisses", "id"),
]


def export_table(engine, table_name: str) -> list[dict]:
    """Export satu tabel ke JSON, handle UUID dan datetime."""
    import uuid
    from sqlalchemy import text
    with engine.connect() as conn:
        result = conn.execute(text(f"SELECT * FROM {table_name}"))
        rows = []
        for row in result:
            row_dict = {}
            for i, col in enumerate(result.keys()):
                val = row[i]
                if isinstance(val, uuid.UUID):
                    val = str(val)
                elif isinstance(val, datetime):
                    val = val.isoformat()
                elif isinstance(val, (dict, list)):
                    # JSON/JSONB: keep as Python objects for json.dump
                    pass
                elif val is None:
                    pass
                else:
                    val = str(val)
                row_dict[col] = val
            rows.append(row_dict)
    return rows


def export_all():
    """Export semua tabel dari Supabase LAMA."""
    from sqlalchemy import create_engine

    if not SOURCE_DATABASE_URL:
        print("SOURCE_DATABASE_URL belum diset.")
        print()
        print("Jalankan ini dulu:")
        print('  $env:SOURCE_DATABASE_URL = "postgresql://postgres.lama:xxx@db.old.supabase.co:6543/postgres"')
        print()
        print("Atau tambahin di .env:")
        print("  SOURCE_DATABASE_URL=postgresql://postgres.lama:xxx@db.old.supabase.co:6543/postgres")
        sys.exit(1)

    url = SOURCE_DATABASE_URL
    if "+psycopg" not in url:
        url = url.replace("postgresql://", "postgresql+psycopg://", 1)

    engine = create_engine(url, pool_pre_ping=True)

    os.makedirs(EXPORTS_DIR, exist_ok=True)

    print("📤 Export dari Supabase LAMA...\n")

    for table_name, pk in TABLES:
        try:
            rows = export_table(engine, table_name)
            filepath = os.path.join(EXPORTS_DIR, f"{table_name}.json")
            with open(filepath, "w", encoding="utf-8") as f:
                json.dump(rows, f, ensure_ascii=False, indent=2)
            print(f"  ✅ {table_name}: {len(rows)} rows")
        except Exception as e:
            print(f"  ❌ {table_name}: {e}")

    print(f"\n📁 Export selesai: {EXPORTS_DIR}")


def import_table(conn, table_name: str, pk: tuple | str, batch_size: int = 500):
    """Import satu tabel ke Supabase BARU. Skip kolom yang tidak ada."""
    filepath = os.path.join(EXPORTS_DIR, f"{table_name}.json")
    if not os.path.exists(filepath):
        print(f"  ⚠️  {table_name}: file tidak ditemukan, skip")
        return 0

    with open(filepath, encoding="utf-8") as f:
        rows = json.load(f)

    if not rows:
        print(f"  ✅ {table_name}: 0 rows")
        return 0

    cursor = conn.cursor()

    # Get columns yang ada di destination + data types
    cursor.execute("""
        SELECT column_name, data_type
        FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = %s
    """, (table_name,))
    dest_info = {row[0]: row[1] for row in cursor.fetchall()}
    dest_columns = set(dest_info.keys())

    # Deteksi kolom JSON/JSONB
    json_columns = {col for col, dtype in dest_info.items() if "json" in dtype.lower()}

    # Get PK dari destination
    cursor.execute("""
        SELECT a.attname
        FROM pg_index i
        JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
        WHERE i.indrelid = %s::regclass AND i.indisprimary
    """, (table_name,))
    pk_rows = cursor.fetchall()
    if not pk_rows:
        print(f"  ⚠️  {table_name}: tidak ada PK, skip")
        return 0
    dest_pk = tuple(r[0] for r in pk_rows)
    pk_set = set(dest_pk)

    # Filter hanya kolom yang ada di destination
    exported_cols = list(rows[0].keys())
    valid_cols = [c for c in exported_cols if c in dest_columns]
    skipped_cols = [c for c in exported_cols if c not in dest_columns]

    if skipped_cols:
        print(f"    (skip kolom tidak ada: {skipped_cols})")

    if not valid_cols:
        print(f"  ⚠️  {table_name}: tidak ada kolom yang match, skip")
        return 0

    col_list = ", ".join(valid_cols)
    placeholders = ", ".join([f"%({c})s" for c in valid_cols])

    # Upsert ON CONFLICT
    if isinstance(dest_pk, tuple):
        conflict_cols = ", ".join(dest_pk)
        do_update = ", ".join([f"{c}=EXCLUDED.{c}" for c in valid_cols if c not in pk_set])
    else:
        conflict_cols = dest_pk
        do_update = ", ".join([f"{c}=EXCLUDED.{c}" for c in valid_cols if c != dest_pk])

    upsert_sql = f"""
        INSERT INTO {table_name} ({col_list})
        VALUES ({placeholders})
        ON CONFLICT ({conflict_cols}) DO UPDATE SET {do_update}
    """

    imported = 0
    for i in range(0, len(rows), batch_size):
        batch = rows[i : i + batch_size]
        filtered_batch = []
        for row in batch:
            out = {}
            for c in valid_cols:
                val = row.get(c)
                if c in json_columns and isinstance(val, (dict, list)):
                    val = json.dumps(val)
                out[c] = val
            filtered_batch.append(out)
        cursor.executemany(upsert_sql, filtered_batch)
        imported += len(batch)

    conn.commit()
    return imported


def import_all():
    """Import semua tabel ke Supabase BARU."""
    import psycopg

    if not DEST_DATABASE_URL:
        print("DATABASE_URL belum diset di .env")
        print("Pastikan .env menunjuk ke Supabase BARU")
        sys.exit(1)

    print("📥 Import ke Supabase BARU...\n")

    # Disable prepared statement caching via PostgreSQL session option
    url = DEST_DATABASE_URL.replace("postgresql+psycopg://", "postgresql://")
    url += ("&" if "?" in url else "?") + "options=-c%20plan_cache_mode%3Dforce_custom_plan"

    with psycopg.connect(url) as conn:
        for table_name, pk in TABLES:
            try:
                imported = import_table(conn, table_name, pk)
                print(f"  ✅ {table_name}: {imported} rows")
            except Exception as e:
                print(f"  ❌ {table_name}: {e}")
                conn.rollback()

    print("\n✅ Import selesai.")


def verify():
    """Verifikasi jumlah row di Supabase LAMA vs BARU."""
    from sqlalchemy import create_engine, text as sa_text
    import psycopg

    if not SOURCE_DATABASE_URL or not DEST_DATABASE_URL:
        print("SOURCE_DATABASE_URL dan DATABASE_URL harus sudah diset")
        sys.exit(1)

    # Source engine (Supabase LAMA)
    src_url = SOURCE_DATABASE_URL
    if "+psycopg" not in src_url:
        src_url = src_url.replace("postgresql://", "postgresql+psycopg://", 1)
    src_engine = create_engine(src_url, pool_pre_ping=True)

    # psycopg3: disable prepared statement cache untuk avoid conflict antar tabel
    dest_url = DEST_DATABASE_URL.replace("postgresql+psycopg://", "postgresql://")
    dest_url += ("&" if "?" in dest_url else "?") + "options=-c%20plan_cache_mode%3Dforce_custom_plan"

    print("🔍 Verifikasi: Supabase LAMA vs BARU\n")
    print(f"{'Tabel':<35} {'Lama':>10} {'Baru':>10} {'Status':>10}")
    print("-" * 70)

    with psycopg.connect(dest_url) as dest_conn:
        dest_cur = dest_conn.cursor()
        with src_engine.connect() as src_conn:
            for table_name, pk in TABLES:
                try:
                    result = src_conn.execute(sa_text(f"SELECT COUNT(*) FROM {table_name}"))
                    src_count = result.scalar() or 0

                    dest_cur.execute(f"SELECT COUNT(*) FROM {table_name}")
                    dest_count = dest_cur.fetchone()[0] or 0

                    if src_count == dest_count:
                        status = "✅ MATCH"
                    elif dest_count > 0:
                        status = "⚠️ DIFF"
                    else:
                        status = "❌ EMPTY"

                    print(f"  {table_name:<33} {src_count:>10} {dest_count:>10} {status:>10}")
                except Exception as e:
                    print(f"  {table_name:<33} {'ERROR':>10} {str(e)[:10]:>10}")

    print("\n✅ Verifikasi selesai.")


def main():
    parser = argparse.ArgumentParser(description="Migrasi Supabase LAMA → BARU")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--export-only", action="store_true", help="Export dari Supabase LAMA")
    group.add_argument("--import-only", action="store_true", help="Import ke Supabase BARU")
    group.add_argument("--verify", action="store_true", help="Verifikasi")

    args = parser.parse_args()

    if args.export_only:
        export_all()
    elif args.import_only:
        import_all()
    elif args.verify:
        verify()


if __name__ == "__main__":
    main()
