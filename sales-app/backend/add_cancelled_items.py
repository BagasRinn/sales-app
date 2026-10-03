"""Tambah kolom cancelled_items JSONB ke orders table.
Jalankan sekali saja di database yang sudah ada.

    cd backend
    python add_cancelled_items.py
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

with engine.connect() as conn:
    r = conn.execute(text("""
        SELECT column_name FROM information_schema.columns
        WHERE table_name = 'orders' AND column_name = 'cancelled_items'
    """))
    if r.fetchone() is not None:
        print("[SKIP] Kolom cancelled_items sudah ada di orders.")
    else:
        conn.execute(text("ALTER TABLE orders ADD COLUMN cancelled_items JSONB"))
        conn.commit()
        print("[OK]  Kolom cancelled_items berhasil ditambahkan.")
