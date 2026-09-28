"""Add nama_supplier column to products table."""
from sqlalchemy import text
from app.models.database import engine


def migrate():
    with engine.begin() as conn:
        conn.execute(text("""
            ALTER TABLE products
            ADD COLUMN IF NOT EXISTS nama_supplier VARCHAR(255);
        """))
        conn.execute(text("""
            CREATE INDEX IF NOT EXISTS ix_products_nama_supplier
            ON products(nama_supplier);
        """))
        print("Migration complete: nama_supplier column added to products table.")


if __name__ == "__main__":
    migrate()
