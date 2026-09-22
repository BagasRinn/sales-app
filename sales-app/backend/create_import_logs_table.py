"""
Migration: Create import_logs table and ensure import_errors table exists.
Run once: python create_import_logs_table.py
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
        # Create import_logs table
        result = conn.execute(text("""
            SELECT table_name FROM information_schema.tables
            WHERE table_name = 'import_logs'
        """))
        if result.fetchone() is None:
            conn.execute(text("""
                CREATE TABLE import_logs (
                    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
                    user_id VARCHAR,
                    username VARCHAR,
                    total_rows INTEGER DEFAULT 0,
                    inserted INTEGER DEFAULT 0,
                    updated INTEGER DEFAULT 0,
                    skipped INTEGER DEFAULT 0,
                    file_name VARCHAR,
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
                )
            """))
            conn.commit()
            print("[MIGRATE] Created import_logs table")
        else:
            print("[MIGRATE] import_logs table already exists")

        # Create sync_validation_errors table (if not exists)
        result2 = conn.execute(text("""
            SELECT table_name FROM information_schema.tables
            WHERE table_name = 'sync_validation_errors'
        """))
        if result2.fetchone() is None:
            conn.execute(text("""
                CREATE TABLE sync_validation_errors (
                    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
                    row_number INTEGER,
                    sku VARCHAR,
                    reason VARCHAR(255),
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
                )
            """))
            conn.commit()
            print("[MIGRATE] Created sync_validation_errors table")
        else:
            print("[MIGRATE] sync_validation_errors table already exists")

        print("[MIGRATE] Done!")

if __name__ == "__main__":
    migrate()
