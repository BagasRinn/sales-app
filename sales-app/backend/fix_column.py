"""
Migration: Add store columns to orders table.
Run once: python fix_column.py
"""
import os
from dotenv import load_dotenv
load_dotenv()

from sqlalchemy import create_engine, text

DATABASE_URL = os.getenv("DATABASE_URL")
engine = create_engine(DATABASE_URL)

def migrate():
    with engine.connect() as conn:
        # Check if columns already exist
        result = conn.execute(text("""
            SELECT column_name FROM information_schema.columns
            WHERE table_name = 'orders' AND column_name IN ('store_name', 'store_contact', 'store_address')
        """))
        existing = {row[0] for row in result}

        if 'store_name' not in existing:
            conn.execute(text("ALTER TABLE orders ADD COLUMN store_name VARCHAR(200)"))
            print("[MIGRATE] Added store_name column")
        else:
            print("[MIGRATE] store_name already exists")

        if 'store_contact' not in existing:
            conn.execute(text("ALTER TABLE orders ADD COLUMN store_contact VARCHAR(50)"))
            print("[MIGRATE] Added store_contact column")
        else:
            print("[MIGRATE] store_contact already exists")

        if 'store_address' not in existing:
            conn.execute(text("ALTER TABLE orders ADD COLUMN store_address VARCHAR(500)"))
            print("[MIGRATE] Added store_address column")
        else:
            print("[MIGRATE] store_address already exists")

        conn.commit()
        print("[MIGRATE] Done! All store columns present.")

if __name__ == "__main__":
    migrate()
