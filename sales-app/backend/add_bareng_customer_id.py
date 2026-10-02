"""Tambah kolom bareng_customer_id ke customer_registration_submissions.
Jalankan sekali saja di database yang sudah ada.

    cd backend
    python add_bareng_customer_id.py
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
    # Cek apakah kolom sudah ada
    r = conn.execute(text("""
        SELECT column_name FROM information_schema.columns
        WHERE table_name = 'customer_registration_submissions'
          AND column_name = 'bareng_customer_id'
    """))
    if r.fetchone() is not None:
        print("[SKIP] Kolom bareng_customer_id sudah ada di customer_registration_submissions.")
    else:
        conn.execute(text("""
            ALTER TABLE customer_registration_submissions
            ADD COLUMN bareng_customer_id UUID REFERENCES customers(id)
        """))
        conn.commit()
        print("[OK]  Kolom bareng_customer_id berhasil ditambahkan.")
