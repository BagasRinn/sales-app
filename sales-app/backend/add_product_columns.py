"""
Migration: Add kategori and satuan columns to products table.
Run once: python add_product_columns.py
"""
import os
from dotenv import load_dotenv
load_dotenv()

from sqlalchemy import create_engine, text

DATABASE_URL = os.getenv("DATABASE_URL")
engine = create_engine(DATABASE_URL)

def migrate():
    with engine.connect() as conn:
        result = conn.execute(text("""
            SELECT column_name FROM information_schema.columns
            WHERE table_name = 'products' AND column_name IN ('kategori', 'satuan')
        """))
        existing = {row[0] for row in result}

        if 'kategori' not in existing:
            conn.execute(text("ALTER TABLE products ADD COLUMN kategori VARCHAR"))
            print("[MIGRATE] Added kategori column")
        else:
            print("[MIGRATE] kategori already exists")

        if 'satuan' not in existing:
            conn.execute(text("ALTER TABLE products ADD COLUMN satuan VARCHAR"))
            print("[MIGRATE] Added satuan column")
        else:
            print("[MIGRATE] satuan already exists")

        conn.commit()
        print("[MIGRATE] Done! All product columns present.")

if __name__ == "__main__":
    migrate()
