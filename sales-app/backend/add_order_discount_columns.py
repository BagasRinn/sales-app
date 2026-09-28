"""
Migration: Add order-level discount columns to orders table.

Diskon sekarang di level order, bukan per item. Kolom ini menyimpan
nilai diskon yang berlaku untuk keseluruhan order (bukan per product).

Run once: python add_order_discount_columns.py
"""
import os
from dotenv import load_dotenv
load_dotenv()

from sqlalchemy import create_engine, text

DATABASE_URL = os.getenv("DATABASE_URL", "")
if not DATABASE_URL:
    raise SystemExit("[ERROR] DATABASE_URL not set.")

if "+psycopg" not in DATABASE_URL and "psycopg2" not in DATABASE_URL:
    DATABASE_URL = DATABASE_URL.replace("postgresql://", "postgresql+psycopg2://", 1)

engine = create_engine(DATABASE_URL)


def migrate():
    with engine.connect() as conn:
        # Check if columns exist
        result = conn.execute(text("""
            SELECT column_name FROM information_schema.columns
            WHERE table_name = 'orders' AND column_name IN ('order_discount_type', 'order_discount_nominal')
        """))
        existing = {row[0] for row in result}

        if 'order_discount_type' not in existing:
            conn.execute(text(
                "ALTER TABLE orders ADD COLUMN order_discount_type VARCHAR(10) NOT NULL DEFAULT 'PERCENT'"
            ))
            print("[OK] Added orders.order_discount_type")
        else:
            print("[--] orders.order_discount_type already exists")

        if 'order_discount_nominal' not in existing:
            conn.execute(text(
                "ALTER TABLE orders ADD COLUMN order_discount_nominal INTEGER NOT NULL DEFAULT 0"
            ))
            print("[OK] Added orders.order_discount_nominal")
        else:
            print("[--] orders.order_discount_nominal already exists")

        conn.commit()
        print("\n[OK] Migration complete.")


if __name__ == "__main__":
    migrate()
