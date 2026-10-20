"""
Buat semua tabel di Supabase BARU dari SQLAlchemy models.

Usage:
    # Set Supabase BARU connection string (DATABASE_URL di .env sudah menunjuk ke baru)
    python scripts/create_tables_supabase.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from dotenv import load_dotenv

load_dotenv()

DEST_DATABASE_URL = os.getenv("DATABASE_URL", "")

if not DEST_DATABASE_URL:
    print("DATABASE_URL belum diset di .env")
    print("Pastikan .env menunjuk ke Supabase BARU")
    sys.exit(1)

from sqlalchemy import create_engine
from app.models.models import Base


def create_tables():
    """Create semua tabel yang belum ada di Supabase BARU."""
    import psycopg

    # psycopg3 pakai postgresql://
    url = DEST_DATABASE_URL.replace("postgresql+psycopg://", "postgresql://")

    # Cek tabel yang sudah ada
    existing = set()
    with psycopg.connect(url) as conn:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT table_name FROM information_schema.tables
                WHERE table_schema = 'public'
            """)
            for (t,) in cur:
                existing.add(t)

    models_to_create = []
    skipped = []

    for table_name in Base.metadata.tables.keys():
        if table_name in existing:
            skipped.append(table_name)
        else:
            models_to_create.append(table_name)

    print(f"📋 Status tabel di Supabase BARU:\n")
    print(f"   ✅ Sudah ada ({len(skipped)}): {', '.join(sorted(skipped)) if skipped else '(tidak ada)'}")
    print(f"   🔨 Akan dibuat ({len(models_to_create)}): {', '.join(sorted(models_to_create)) if models_to_create else '(tidak ada)'}")
    print()

    if not models_to_create:
        print("✅ Semua tabel sudah ada.")
        return

    # Convert untuk SQLAlchemy engine (butuh +psycopg)
    engine_url = DEST_DATABASE_URL
    if "+psycopg" not in engine_url:
        engine_url = engine_url.replace("postgresql://", "postgresql+psycopg://", 1)

    engine = create_engine(engine_url, isolation_level="AUTOCOMMIT")
    Base.metadata.create_all(engine)

    # Verify
    with psycopg.connect(url) as conn:
        with conn.cursor() as cur:
            cur.execute("""
                SELECT table_name FROM information_schema.tables
                WHERE table_schema = 'public'
            """)
            created = {r[0] for r in cur.fetchall()}

    print()
    for t in sorted(models_to_create):
        if t in created:
            print(f"  ✅ {t}")
        else:
            print(f"  ❌ {t} — GAGAL")

    ok = sum(1 for t in models_to_create if t in created)
    print(f"\n✅ {ok}/{len(models_to_create)} tabel berhasil dibuat.")


if __name__ == "__main__":
    create_tables()
