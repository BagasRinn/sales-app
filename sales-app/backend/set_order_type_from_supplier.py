"""Set order_type untuk semua produk berdasarkan nama_supplier.

Daftar supplier 4P berdasarkan data dari admin:
  - CANDRA FOOD, CV
  - CUAN BERKAT BERSAMA, PT
  - DARMAWAN SUKSES MANDIRI, PT
  - PANGAN INDUSTRI BANUA, PT

Selain itu = REGULER.

Jalankan SEKALI saja untuk meng-klasifikasi produk yang sudah ada.
Setelah ini, import Excel akan otomatis set order_type saat insert/update
berdasarkan kolom '\' (nama_supplier) di Excel.

    cd backend
    python set_order_type_from_supplier.py
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

# Daftar supplier 4P — dari data TAX STATE 4P
SUPPLIERS_4P = [
    "CANDRA FOOD, CV",
    "CUAN BERKAT BERSAMA, PT",
    "DARMAWAN SUKSES MANDIRI, PT",
    "PANGAN INDUSTRI BANUA, PT",
]


def upgrade():
    print(f"[INFO] Supplier 4P: {SUPPLIERS_4P}")

    with engine.connect() as conn:
        # Set 4P untuk produk yang supplier-nya masuk daftar
        result = conn.execute(
            text("""
                UPDATE products
                SET order_type = '4P'
                WHERE nama_supplier IN :suppliers
                  AND (order_type IS NULL OR order_type != '4P')
            """),
            {"suppliers": tuple(SUPPLIERS_4P)},
        )
        conn.commit()
        print(f"[OK]  {result.rowcount} produk di-set sebagai 4P")

        # Set REGULER untuk produk lainnya
        result2 = conn.execute(
            text("""
                UPDATE products
                SET order_type = 'REGULER'
                WHERE nama_supplier NOT IN :suppliers
                  AND (order_type IS NULL OR order_type != 'REGULER')
            """),
            {"suppliers": tuple(SUPPLIERS_4P)},
        )
        conn.commit()
        print(f"[OK]  {result2.rowcount} produk di-set sebagai REGULER")

        # Summary
        total = conn.execute(text("SELECT COUNT(*) FROM products")).scalar()
        reguler = conn.execute(
            text("SELECT COUNT(*) FROM products WHERE order_type = 'REGULER'")
        ).scalar()
        p4p = conn.execute(
            text("SELECT COUNT(*) FROM products WHERE order_type = '4P'")
        ).scalar()
        print(f"[SUMMARY] Total: {total} produk | REGULER: {reguler} | 4P: {p4p}")


if __name__ == "__main__":
    upgrade()
