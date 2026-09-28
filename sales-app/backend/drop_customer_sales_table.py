"""
Migration: Drop customer_sales table.

Assignment customer→sales telah dihapus. Semua sales dapat melihat
dan membuat order ke semua customer tanpa batasan assignment.

Run once: python drop_customer_sales_table.py
"""
import os
from dotenv import load_dotenv
load_dotenv()

from sqlalchemy import create_engine, text

DATABASE_URL = os.getenv("DATABASE_URL", "")
if "+psycopg" not in DATABASE_URL:
    DATABASE_URL = DATABASE_URL.replace("postgresql://", "postgresql+psycopg://", 1)

engine = create_engine(DATABASE_URL)


def migrate():
    with engine.connect() as conn:
        # Drop customer_sales table if it exists
        result = conn.execute(text(
            "SELECT table_name FROM information_schema.tables "
            "WHERE table_name = 'customer_sales'"
        ))
        if result.fetchone() is not None:
            conn.execute(text("DROP TABLE customer_sales CASCADE"))
            conn.commit()
            print("[OK] Table customer_sales dropped.")
        else:
            print("[--] Table customer_sales does not exist — nothing to drop.")


if __name__ == "__main__":
    migrate()
