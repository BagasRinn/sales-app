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
                order_type VARCHAR(10) NOT NULL DEFAULT 'REGULER',
                created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
            )
            """
        ))
        # Tabel yang dibuat sebelum kolom order_type ada (model sudah NOT NULL).
        conn.execute(text(
            "ALTER TABLE suppliers ADD COLUMN IF NOT EXISTS "
            "order_type VARCHAR(10) NOT NULL DEFAULT 'REGULER'"
        ))
        conn.execute(text(
            "CREATE INDEX IF NOT EXISTS ix_suppliers_is_active "
            "ON suppliers(is_active)"
        ))
        # Backfill: distinct nama_supplier dari products yang sudah ada
        conn.execute(text(
            """
            INSERT INTO suppliers (name, is_active, order_type)
            SELECT DISTINCT nama_supplier, TRUE, 'REGULER'
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
