"""Tabel suppliers — master data supplier dengan is_active flag.

Backfill dari products.nama_supplier yang sudah ada, semua default active.
ON CONFLICT DO NOTHING supaya re-run migration tidak overwrite toggle manual
yang sudah dilakukan manager via API.
"""
from sqlalchemy import text
from app.models.database import engine


def upgrade():
    with engine.begin() as conn:
        conn.execute(text(
            """
            CREATE TABLE IF NOT EXISTS suppliers (
                name VARCHAR PRIMARY KEY,
                is_active BOOLEAN NOT NULL DEFAULT TRUE,
                created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
            )
            """
        ))
        conn.execute(text(
            "CREATE INDEX IF NOT EXISTS ix_suppliers_is_active "
            "ON suppliers(is_active)"
        ))
        # Backfill: distinct nama_supplier dari products yang sudah ada
        conn.execute(text(
            """
            INSERT INTO suppliers (name, is_active)
            SELECT DISTINCT nama_supplier, TRUE
            FROM products
            WHERE nama_supplier IS NOT NULL AND nama_supplier != ''
            ON CONFLICT (name) DO NOTHING
            """
        ))
    print("[MIGRATION] Created suppliers table + index + backfill complete")


def downgrade():
    with engine.begin() as conn:
        conn.execute(text("DROP TABLE IF EXISTS suppliers"))
    print("[MIGRATION] Dropped suppliers")


if __name__ == "__main__":
    upgrade()
