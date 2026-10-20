"""Tabel supplier_targets — target penjualan per supplier per periode bulanan.

Manager/admin set target nominal (IDR) per supplier per bulan untuk halaman
Performa Sales. Target carry-over otomatis dari bulan sebelumnya saat bulan
baru dibuka tanpa row eksplisit (read-time lookup, tidak ada trigger).
"""
from sqlalchemy import text
from app.models.database import engine


def upgrade():
    with engine.connect() as conn:
        conn.execute(
            text(
                """
                CREATE TABLE IF NOT EXISTS supplier_targets (
                    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                    branch VARCHAR(20) NOT NULL,
                    supplier_name VARCHAR NOT NULL,
                    period VARCHAR(7) NOT NULL,
                    target_value BIGINT NOT NULL DEFAULT 0,
                    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

                    -- Unique: 1 target per supplier per cabang per periode
                    CONSTRAINT uq_supplier_targets_branch_supplier_period
                        UNIQUE (branch, supplier_name, period)
                )
            """
            )
        )
        conn.execute(
            text(
                "CREATE INDEX IF NOT EXISTS ix_supplier_targets_branch_period "
                "ON supplier_targets(branch, period)"
            )
        )
        conn.execute(
            text(
                "CREATE INDEX IF NOT EXISTS ix_supplier_targets_supplier_name "
                "ON supplier_targets(supplier_name)"
            )
        )
        conn.commit()
    print("[MIGRATION] Created supplier_targets table + indexes")


def downgrade():
    with engine.connect() as conn:
        conn.execute(text("DROP TABLE IF EXISTS supplier_targets"))
        conn.commit()
    print("[MIGRATION] Dropped supplier_targets")


if __name__ == "__main__":
    upgrade()
