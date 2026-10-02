"""
Railway PostgreSQL Setup Script.

Creates the full database schema (all tables, indexes) and seeds
1 default user per role: ADMIN, MANAGER, SALES.

Jalankan SEKALI saat pertama kali setup di Railway:
    cd backend
    python setup_railway.py

Script ini idempotent — aman dijalankan berkali-kali.
"""
import os
import uuid
import bcrypt
from dotenv import load_dotenv

load_dotenv()

from sqlalchemy import create_engine, text

DATABASE_URL = os.getenv("DATABASE_URL", "")
if not DATABASE_URL:
    raise SystemExit("[ERROR] DATABASE_URL not set. Buat .env dengan Railway connection string.")

# Railway menggunakan PostgreSQL. Pastikan driver psycopg2.
if "+psycopg" not in DATABASE_URL and "psycopg2" not in DATABASE_URL:
    DATABASE_URL = DATABASE_URL.replace("postgresql://", "postgresql+psycopg2://", 1)

engine = create_engine(DATABASE_URL)


def _pw_hash(password: str) -> str:
    """Hash password dengan bcrypt — sama seperti app/core/security.py."""
    return bcrypt.hashpw(password[:72].encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def _table_exists(conn, name: str) -> bool:
    r = conn.execute(text(
        "SELECT 1 FROM information_schema.tables WHERE table_name = :name"
    ), {"name": name})
    return r.fetchone() is not None


def _index_exists(conn, index_name: str) -> bool:
    r = conn.execute(text(
        "SELECT 1 FROM pg_indexes WHERE indexname = :name"
    ), {"name": index_name})
    return r.fetchone() is not None


def setup_schema(conn):
    print("[1/3] Membuat schema...")

    # --- users ---
    if not _table_exists(conn, "users"):
        conn.execute(text("""
            CREATE TABLE users (
                id          UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
                username    VARCHAR(50) UNIQUE NOT NULL,
                password_hash VARCHAR,
                role        VARCHAR(10),
                nama        VARCHAR(100),
                is_active   BOOLEAN     NOT NULL DEFAULT true,
                token_version INTEGER   NOT NULL DEFAULT 0,
                created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                deleted_at  TIMESTAMPTZ
            )
        """))
        conn.execute(text("CREATE INDEX ix_users_username ON users(username)"))
        print("  + users")
    else:
        print("  ~ users (sudah ada)")

    # --- products ---
    if not _table_exists(conn, "products"):
        conn.execute(text("""
            CREATE TABLE products (
                id            VARCHAR     PRIMARY KEY,
                nama_barang   VARCHAR,
                harga         INTEGER,
                stok_sistem   INTEGER     NOT NULL DEFAULT 0,
                stok_booking  INTEGER     NOT NULL DEFAULT 0,
                kategori      VARCHAR,
                satuan        VARCHAR,
                nama_supplier VARCHAR,
                order_type    VARCHAR(10) NOT NULL DEFAULT 'REGULER'
            )
        """))
        conn.execute(text("CREATE INDEX ix_products_nama_barang ON products(nama_barang)"))
        conn.execute(text("CREATE INDEX ix_products_nama_supplier ON products(nama_supplier)"))
        conn.execute(text("CREATE INDEX ix_products_order_type ON products(order_type)"))
        print("  + products")
    else:
        print("  ~ products (sudah ada)")
        # Pastikan kolom nama_supplier ada (dari migrasi lama)
        r = conn.execute(text("""
            SELECT column_name FROM information_schema.columns
            WHERE table_name = 'products' AND column_name = 'nama_supplier'
        """))
        if r.fetchone() is None:
            conn.execute(text("ALTER TABLE products ADD COLUMN nama_supplier VARCHAR"))
            conn.execute(text("CREATE INDEX IF NOT EXISTS ix_products_nama_supplier ON products(nama_supplier)"))
            print("  + nama_supplier column di products")

    # --- customers ---
    if not _table_exists(conn, "customers"):
        conn.execute(text("""
            CREATE TABLE customers (
                id          UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
                kode        VARCHAR(50),
                nama_toko   VARCHAR(200) NOT NULL,
                alamat      VARCHAR(500),
                created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                deleted_at  TIMESTAMPTZ
            )
        """))
        conn.execute(text("CREATE INDEX ix_customers_kode ON customers(kode)"))
        conn.execute(text("CREATE INDEX ix_customers_nama_toko ON customers(nama_toko)"))
        print("  + customers")
    else:
        print("  ~ customers (sudah ada)")

    # --- orders ---
    if not _table_exists(conn, "orders"):
        conn.execute(text("""
            CREATE TABLE orders (
                id            UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
                sales_id      UUID        REFERENCES users(id),
                customer_id   UUID        REFERENCES customers(id),
                status        VARCHAR(20) NOT NULL DEFAULT 'DRAFT',
                notes         VARCHAR(1000),
                created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                store_name    VARCHAR(200),
                store_contact VARCHAR(50),
                store_address VARCHAR(500),
                order_type    VARCHAR(10) NOT NULL DEFAULT 'REGULER'
            )
        """))
        conn.execute(text("CREATE INDEX ix_orders_status ON orders(status)"))
        conn.execute(text("CREATE INDEX ix_orders_created_at ON orders(created_at)"))
        conn.execute(text("CREATE INDEX ix_orders_status_created_at ON orders(status, created_at)"))
        conn.execute(text("CREATE INDEX ix_orders_sales_id ON orders(sales_id)"))
        conn.execute(text("CREATE INDEX ix_orders_customer_id ON orders(customer_id)"))
        print("  + orders")
    else:
        print("  ~ orders (sudah ada)")

    # --- order_items ---
    if not _table_exists(conn, "order_items"):
        conn.execute(text("""
            CREATE TABLE order_items (
                id               UUID    DEFAULT gen_random_uuid() PRIMARY KEY,
                order_id         UUID    REFERENCES orders(id) ON DELETE CASCADE,
                product_id       VARCHAR REFERENCES products(id),
                qty              INTEGER,
                -- Discount Layer 1
                discount_percent INTEGER NOT NULL DEFAULT 0,
                discount_type    VARCHAR(10) NOT NULL DEFAULT 'PERCENT',
                discount_nominal INTEGER NOT NULL DEFAULT 0,
                -- Discount Layer 2
                discount2_percent INTEGER NOT NULL DEFAULT 0,
                discount2_type    VARCHAR(10) NOT NULL DEFAULT 'PERCENT',
                discount2_nominal INTEGER NOT NULL DEFAULT 0,
                -- Discount Layer 3
                discount3_percent INTEGER NOT NULL DEFAULT 0,
                discount3_type    VARCHAR(10) NOT NULL DEFAULT 'PERCENT',
                discount3_nominal INTEGER NOT NULL DEFAULT 0
            )
        """))
        print("  + order_items")
    else:
        print("  ~ order_items (sudah ada)")

    # --- stok_log ---
    if not _table_exists(conn, "stok_log"):
        conn.execute(text("""
            CREATE TABLE stok_log (
                id              UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
                product_id      VARCHAR     REFERENCES products(id),
                sumber          VARCHAR(20),
                field_terdampak VARCHAR(20),
                delta           INTEGER,
                nilai_sebelum   INTEGER,
                nilai_sesudah   INTEGER,
                actor_id        UUID        REFERENCES users(id),
                order_id        UUID        REFERENCES orders(id),
                created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
            )
        """))
        conn.execute(text("CREATE INDEX ix_stok_log_product_id ON stok_log(product_id)"))
        print("  + stok_log")
    else:
        print("  ~ stok_log (sudah ada)")

    # --- import_logs ---
    if not _table_exists(conn, "import_logs"):
        conn.execute(text("""
            CREATE TABLE import_logs (
                id          UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
                user_id     VARCHAR,
                nama        VARCHAR,
                import_type VARCHAR     NOT NULL DEFAULT 'PRODUCT',
                total_rows  INTEGER     NOT NULL DEFAULT 0,
                inserted    INTEGER     NOT NULL DEFAULT 0,
                updated     INTEGER     NOT NULL DEFAULT 0,
                skipped     INTEGER     NOT NULL DEFAULT 0,
                file_name   VARCHAR,
                created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
            )
        """))
        print("  + import_logs")
    else:
        print("  ~ import_logs (sudah ada)")

    # --- sync_validation_errors ---
    if not _table_exists(conn, "sync_validation_errors"):
        conn.execute(text("""
            CREATE TABLE sync_validation_errors (
                id            UUID        DEFAULT gen_random_uuid() PRIMARY KEY,
                import_log_id UUID        REFERENCES import_logs(id),
                row_number    INTEGER,
                sku           VARCHAR,
                reason        VARCHAR(255),
                created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
            )
        """))
        print("  + sync_validation_errors")
    else:
        print("  ~ sync_validation_errors (sudah ada)")

    conn.commit()


def cleanup_data(conn):
    print("\n[2/3] Membersihkan data lama...")
    # Hapus FK constraints dulu kalau perlu, truncate dependent tables
    tables_in_order = [
        "stok_log",
        "sync_validation_errors",
        "order_items",
        "orders",
        "customers",
        "products",
        "import_logs",
    ]
    for tbl in tables_in_order:
        if _table_exists(conn, tbl):
            conn.execute(text(f"TRUNCATE TABLE {tbl} CASCADE RESTART IDENTITY"))
            print(f"  ~ {tbl} truncated")
    # Soft-delete semua user (jangan hard-delete karena FK)
    conn.execute(text("UPDATE users SET deleted_at = NOW()"))
    conn.commit()


def seed_users(conn):
    print("\n[3/3] Membuat user default...")

    users = [
        ("admin",   "admin",   "ADMIN"),
        ("manager", "manager", "MANAGER"),
        ("sales",   "sales",   "SALES"),
    ]

    for username, password, role in users:
        r = conn.execute(text(
            "SELECT id FROM users WHERE username = :u AND deleted_at IS NULL"
        ), {"u": username})
        if r.fetchone():
            print(f"  ~ {username} ({role}) — sudah ada")
            continue

        conn.execute(text("""
            INSERT INTO users (username, password_hash, role, is_active, token_version)
            VALUES (:u, :h, :r, true, 0)
        """), {
            "u": username,
            "h": _pw_hash(password),
            "r": role,
        })
        conn.commit()
        print(f"  + {username} ({role})")

    print("\n[OK] Setup selesai!")


def main():
    print(f"Database: {DATABASE_URL.split('@')[-1] if '@' in DATABASE_URL else '(URL hidden)'}")
    print()

    with engine.connect() as conn:
        setup_schema(conn)
        cleanup_data(conn)
        seed_users(conn)


if __name__ == "__main__":
    main()
