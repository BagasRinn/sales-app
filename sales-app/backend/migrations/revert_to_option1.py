"""
Revert DB ke state Opsi 1:
1. Restore customers.kode_area dari junction table
2. Drop junction table customer_kode_areas
3. Keep uq_customers_branch_kode constraint (perlu untuk Opsi 1)
4. Keep branch NOT NULL
"""
import os
import psycopg2
import logging
from dotenv import load_dotenv

load_dotenv()

logging.basicConfig(level=logging.INFO, format="%(message)s")
log = logging.getLogger("revert")

conn = psycopg2.connect(os.environ["DATABASE_URL"])
conn.set_session(autocommit=False)
cur = conn.cursor()
log.info("Connected\n")


def q(stmt, params=None):
    cur.execute(stmt, params)
    conn.commit()
    return cur


def one(stmt, params=None):
    cur.execute(stmt, params)
    r = cur.fetchone()
    return r[0] if r else None


# ============================================================
# CEK STATE
# ============================================================
log.info("=== State sebelum revert ===")
log.info(f"  junction rows: {one('SELECT COUNT(*) FROM customer_kode_areas')}")
log.info(f"  customers.kode_area non-null: {one('SELECT COUNT(*) FROM customers WHERE kode_area IS NOT NULL AND kode_area != %s', ('',))}")
log.info(f"  customers.kode_area distinct: {one('SELECT COUNT(DISTINCT kode_area) FROM customers WHERE kode_area IS NOT NULL')}")
log.info("")


# ============================================================
# STEP 1: Restore customers.kode_area dari junction
# ============================================================
log.info("=== STEP 1: Restore customers.kode_area ===")

# Pakai kode_area pertama per customer (priority: non-empty, non-NULL)
q("""
    UPDATE customers c
    SET kode_area = (
        SELECT MIN(cka.kode_area) FROM customer_kode_areas cka
        WHERE cka.customer_id = c.id AND cka.kode_area IS NOT NULL AND cka.kode_area != ''
    )
    WHERE c.kode_area IS NULL OR c.kode_area = '';
""")
restored = one("SELECT COUNT(*) FROM customers WHERE kode_area IS NOT NULL AND kode_area != ''")
log.info(f"  customers.kode_area non-null: {restored}")
log.info("")


# ============================================================
# STEP 2: Drop junction table
# ============================================================
log.info("=== STEP 2: Drop junction table ===")
q("DROP TABLE IF EXISTS customer_kode_areas CASCADE;")
log.info("  Junction dropped")
log.info("")


# ============================================================
# VERIFIKASI
# ============================================================
log.info("=== VERIFIKASI ===")
junction_exists = one("SELECT 1 FROM pg_tables WHERE tablename = 'customer_kode_areas'") is not None
constraint_exists = one("SELECT 1 FROM pg_constraint WHERE conname = 'uq_customers_branch_kode'") is not None
log.info(f"  customers.kode_area non-null: {one('SELECT COUNT(*) FROM customers WHERE kode_area IS NOT NULL AND kode_area != %s', ('',))}")
log.info(f"  junction table exists: {junction_exists}")
log.info(f"  uq_customers_branch_kode exists: {constraint_exists}")
log.info("")

log.info("=== DONE ===")
log.info("Backend sudah direvert ke a082c24 (pakai customers.kode_area).")
log.info("DB sudah disinkronkan. customers.kode_area kembali terisi.")
log.info("Constraint uq_customers_branch_kode tetap (perlu untuk Opsi 1).")

cur.close()
conn.close()
