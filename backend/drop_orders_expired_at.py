"""
Migration: Drop expired_at column and index from orders table.

SAFE: expired_at sudah tidak ditulis/dibaca oleh kode sejak deploy sebelumnya.
Kolom masih ada di DB tapi tidak ada referensi kode lagi.

Jalankan SESUDAH kode baru di-deploy (expired_at sudah tidak di-touch):
    cd backend
    python drop_orders_expired_at.py

IRREVERSIBLE: tidak ada rollback script. Backup DB dulu jika ragu.
"""
import os
import sys

from dotenv import load_dotenv
load_dotenv()

from sqlalchemy import create_engine, text


def _db():
    DATABASE_URL = os.getenv("DATABASE_URL", "")
    if not DATABASE_URL:
        raise SystemExit("[ERROR] DATABASE_URL not set.")
    if "+psycopg" not in DATABASE_URL and "psycopg2" not in DATABASE_URL:
        DATABASE_URL = DATABASE_URL.replace("postgresql://", "postgresql+psycopg2://", 1)
    return create_engine(DATABASE_URL)


def _col_exists(conn, table: str, col: str) -> bool:
    r = conn.execute(text("""
        SELECT 1 FROM information_schema.columns
        WHERE table_name = :t AND column_name = :c
    """), {"t": table, "c": col})
    return r.fetchone() is not None


def _index_exists(conn, idx: str) -> bool:
    r = conn.execute(text(
        "SELECT 1 FROM pg_indexes WHERE indexname = :n"
    ), {"n": idx})
    return r.fetchone() is not None


def up(conn):
    # Index dulu (kalau ada) — foreign key lain bisa lock baris
    if _index_exists(conn, "ix_orders_expired_at"):
        conn.execute(text("DROP INDEX IF EXISTS ix_orders_expired_at"))
        conn.commit()
        print("  - dropped index ix_orders_expired_at")

    if _col_exists(conn, "orders", "expired_at"):
        conn.execute(text("ALTER TABLE orders DROP COLUMN expired_at"))
        conn.commit()
        print("  - dropped column orders.expired_at")
    else:
        print("  ~ column orders.expired_at already absent")


def down(conn):
    """Rollback — pasang ulang kolom + index."""
    if not _col_exists(conn, "orders", "expired_at"):
        conn.execute(text(
            "ALTER TABLE orders ADD COLUMN expired_at TIMESTAMPTZ"
        ))
        conn.commit()
        print("  + added column orders.expired_at")

    if not _index_exists(conn, "ix_orders_expired_at"):
        conn.execute(text(
            "CREATE INDEX ix_orders_expired_at ON orders(expired_at)"
        ))
        conn.commit()
        print("  + created index ix_orders_expired_at")


def main():
    engine = _db()
    with engine.connect() as conn:
        if len(sys.argv) > 1 and sys.argv[1] == "down":
            print("[down] Re-adding expired_at column and index...")
            down(conn)
        else:
            print("[up] Dropping expired_at column and index...")
            up(conn)
    print("[OK] Done.")


if __name__ == "__main__":
    main()
