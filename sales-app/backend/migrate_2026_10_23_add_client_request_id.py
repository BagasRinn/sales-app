"""Add client_request_id column to orders for idempotency key support.

Allows duplicate-submit prevention by storing the client-provided key.
"""
from sqlalchemy import text
from app.models.database import engine


def upgrade():
    with engine.connect() as conn:
        conn.execute(
            text(
                """
                ALTER TABLE orders
                ADD COLUMN IF NOT EXISTS client_request_id VARCHAR(128)
                """
            )
        )
        conn.execute(
            text(
                "CREATE INDEX IF NOT EXISTS ix_orders_client_request_id "
                "ON orders(client_request_id)"
            )
        )
        conn.commit()
    print("[MIGRATION] Added client_request_id column + index to orders")


def downgrade():
    with engine.connect() as conn:
        conn.execute(text("DROP INDEX IF EXISTS ix_orders_client_request_id"))
        conn.execute(
            text("ALTER TABLE orders DROP COLUMN IF EXISTS client_request_id")
        )
        conn.commit()
    print("[MIGRATION] Dropped client_request_id column from orders")


if __name__ == "__main__":
    upgrade()