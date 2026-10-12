"""
Safe migration: tiap tahap di-commit terpisah, jadi kalau ada error
constraint tetap bisa dilanjut.
"""
import os
import psycopg2
import logging

logging.basicConfig(level=logging.INFO, format="%(message)s")
log = logging.getLogger("migration")

DB_URL = os.environ["DATABASE_URL"]


def run_steps():
    conn = psycopg2.connect(DB_URL)
    conn.set_session(autocommit=False)
    cur = conn.cursor()

    def q(stmt, params=None):
        cur.execute(stmt, params)
        conn.commit()

    def one(stmt, params=None):
        cur.execute(stmt, params)
        r = cur.fetchone()
        return r[0] if r else None

    def all_(stmt, params=None):
        cur.execute(stmt, params)
        return cur.fetchall()

    def fetch_and_commit(stmt, params=None):
        cur.execute(stmt, params)
        rows = cur.fetchall()
        conn.commit()
        return rows

    log.info("=== CEK AWAL ===")
    total = one("SELECT COUNT(*) FROM customers WHERE branch = 'BANJARMASIN'")
    with_kode = one("SELECT COUNT(*) FROM customers WHERE branch = 'BANJARMASIN' AND kode IS NOT NULL")
    distinct = one("SELECT COUNT(DISTINCT kode) FROM customers WHERE branch = 'BANJARMASIN' AND kode IS NOT NULL")
    log.info(f"  Total: {total}, with_kode: {with_kode}, distinct: {distinct}, extra: {with_kode - distinct}")
    log.info("")

    # ============================================================
    # STEP 1: Delete victims per pair
    # ============================================================
    log.info("=== STEP 1: Cleanup duplikat ===")
    log.info("  (commit per batch 50 pasangan)")

    batch_size = 50
    total_deleted = 0
    total_subs = 0
    batch_num = 0

    while True:
        batch_num += 1
        pairs = fetch_and_commit("""
            SELECT branch, kode
            FROM customers
            WHERE kode IS NOT NULL
            GROUP BY branch, kode
            HAVING COUNT(*) > 1
            LIMIT %s;
        """, (batch_size,))

        if not pairs:
            log.info(f"  Semua pasangan selesai ({total_deleted} dihapus)")
            break

        log.info(f"  Batch {batch_num}: {len(pairs)} pasangan")

        for branch, kode in pairs:
            # Ambil rows untuk pasangan ini
            cur.execute("""
                SELECT
                    c.id,
                    c.created_at,
                    (SELECT COUNT(*) FROM orders WHERE customer_id = c.id) AS order_cnt,
                    (SELECT COUNT(*) FROM customer_registration_submissions
                     WHERE approved_customer_id = c.id OR bareng_customer_id = c.id) AS sub_cnt
                FROM customers c
                WHERE c.branch = %s AND c.kode = %s
                ORDER BY order_cnt DESC, c.created_at ASC
                LIMIT 2;
            """, (branch, kode))
            rows = cur.fetchall()
            conn.commit()

            if len(rows) < 2:
                continue

            survivor_id = rows[0][0]
            survivor_orders = rows[0][2]

            for row in rows[1:]:
                vid = row[0]
                v_orders = row[2]
                v_subs = row[3]

                # Jika victim punya orders tapi survivor tidak -> swap
                if v_orders > 0 and survivor_orders == 0:
                    survivor_id = vid
                    survivor_orders = v_orders
                    total_deleted += 1
                    log.info(f"    SWAP [{kode}] survivor={vid} (punya orders)")
                    continue

                if v_orders > 0:
                    log.warning(f"    SKIP (victim punya orders): [{branch}, {kode}] victim={vid}")
                    continue

                # Migrate submissions
                if v_subs > 0:
                    cur.execute("""
                        UPDATE customer_registration_submissions
                        SET approved_customer_id = %s
                        WHERE approved_customer_id = %s;
                    """, (survivor_id, vid))
                    cur.execute("""
                        UPDATE customer_registration_submissions
                        SET bareng_customer_id = %s
                        WHERE bareng_customer_id = %s;
                    """, (survivor_id, vid))
                    total_subs += v_subs
                    log.info(f"    Migrated {v_subs} subs: {vid} -> {survivor_id}")

                # Delete victim
                cur.execute("DELETE FROM customers WHERE id = %s;", (vid,))
                total_deleted += 1
                conn.commit()
                log.info(f"    Deleted [{kode}] victim={vid} (0 orders)")

    log.info(f"\n  Total dihapus: {total_deleted}")
    log.info(f"  Total subs migrasi: {total_subs}")
    log.info("")

    # ============================================================
    # STEP 2: Handle P3469 (keduanya punya orders)
    # ============================================================
    log.info("=== STEP 2: Handle P3469 edge case ===")
    p3469 = one("""
        SELECT COUNT(*) FROM customers
        WHERE branch = %s AND kode = %s
    """, ('BANJARMASIN', 'P3469'))
    log.info(f"  P3469 rows: {p3469}")

    if p3469 > 1:
        cur.execute("""
            SELECT id, created_at,
                   (SELECT COUNT(*) FROM orders WHERE customer_id = c.id) AS order_cnt
            FROM customers c
            WHERE branch = %s AND kode = %s
            ORDER BY order_cnt DESC, created_at DESC;
        """, ('BANJARMASIN', 'P3469'))
        rows = cur.fetchall()
        conn.commit()

        survivor_id = rows[0][0]
        for row in rows[1:]:
            vid = row[0]
            # Pindahkan orders
            cur.execute("UPDATE orders SET customer_id = %s WHERE customer_id = %s", (survivor_id, vid))
            cur.execute("DELETE FROM customers WHERE id = %s", (vid,))
            total_deleted += 1
            conn.commit()
            log.info(f"  P3469: orders merged {vid} -> {survivor_id}, victim dihapus")
    log.info("")

    # ============================================================
    # STEP 3: Buat constraint
    # ============================================================
    log.info("=== STEP 3: Buat constraint ===")
    exists = one("SELECT 1 FROM pg_constraint WHERE conname = 'uq_customers_branch_kode'")
    if exists:
        log.info("  Constraint sudah ada.")
    else:
        try:
            q("CREATE UNIQUE INDEX uq_customers_branch_kode ON customers (branch, kode);")
            log.info("  Index dibuat.")
        except Exception as e:
            log.error(f"  GAGAL buat index: {e}")
            remaining = one("""
                SELECT COUNT(*) FROM (
                    SELECT 1 FROM customers
                    WHERE kode IS NOT NULL
                    GROUP BY branch, kode
                    HAVING COUNT(*) > 1
                ) t;
            """)
            log.error(f"  Sisa duplikat: {remaining}")
            raise

    branch_null = one("SELECT is_nullable FROM information_schema.columns WHERE table_name = 'customers' AND column_name = 'branch';")
    if branch_null == 'YES':
        q("ALTER TABLE customers ALTER COLUMN branch SET NOT NULL;")
        log.info("  branch SET NOT NULL.")
    log.info("")

    # ============================================================
    # STEP 4: Buat junction table
    # ============================================================
    log.info("=== STEP 4: Buat junction table ===")
    exists = one("SELECT 1 FROM pg_tables WHERE tablename = 'customer_kode_areas'")
    if exists:
        log.info("  Table sudah ada.")
    else:
        q("""
            CREATE TABLE customer_kode_areas (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                customer_id UUID NOT NULL REFERENCES customers(id) ON DELETE CASCADE,
                kode_area VARCHAR(50) NOT NULL,
                branch VARCHAR(20) NOT NULL,
                created_at TIMESTAMPTZ DEFAULT NOW(),
                UNIQUE(customer_id, kode_area)
            );
        """)
        q("CREATE INDEX idx_cka_customer ON customer_kode_areas(customer_id);")
        q("CREATE INDEX idx_cka_kode_area ON customer_kode_areas(kode_area);")
        q("CREATE INDEX idx_cka_branch ON customer_kode_areas(branch);")
        log.info("  Table + index dibuat.")
    log.info("")

    # ============================================================
    # STEP 5: Backfill
    # ============================================================
    log.info("=== STEP 5: Backfill kode_areas ===")
    q("""
        INSERT INTO customer_kode_areas (customer_id, kode_area, branch)
        SELECT c.id, c.kode_area, c.branch
        FROM customers c
        WHERE c.kode_area IS NOT NULL
          AND c.kode_area != ''
          AND NOT EXISTS (
              SELECT 1 FROM customer_kode_areas cka
              WHERE cka.customer_id = c.id AND cka.kode_area = c.kode_area
          );
    """)
    backfill = one("SELECT COUNT(*) FROM customer_kode_areas;")
    log.info(f"  Junction rows: {backfill}")
    log.info("")

    # ============================================================
    # STEP 6: Clear deprecated column
    # ============================================================
    log.info("=== STEP 6: Clear customers.kode_area ===")
    q("UPDATE customers SET kode_area = NULL WHERE kode_area IS NOT NULL AND kode_area != '';")
    cleared = one("SELECT COUNT(*) FROM customers WHERE kode_area IS NOT NULL AND kode_area != '';")
    log.info(f"  Sisa non-null kode_area: {cleared}")
    log.info("")

    # ============================================================
    # VERIFIKASI
    # ============================================================
    log.info("=== VERIFIKASI ===")
    remaining = one("""
        SELECT COUNT(*) FROM (
            SELECT 1 FROM customers
            WHERE kode IS NOT NULL
            GROUP BY branch, kode
            HAVING COUNT(*) > 1
        ) t;
    """)
    junction = one("SELECT COUNT(*) FROM customer_kode_areas;")
    total_now = one("SELECT COUNT(*) FROM customers WHERE branch = 'BANJARMASIN'")

    log.info(f"  Sisa duplikat kode: {remaining}")
    log.info(f"  Junction rows: {junction}")
    log.info(f"  Total BANJARMASIN: {total_now}")
    log.info("")
    log.info("=== DONE ===")
    log.info(f"  Total dihapus: {total_deleted}")

    cur.close()
    conn.close()


if __name__ == "__main__":
    try:
        run_steps()
    except Exception as e:
        log.error(f"ERROR: {e}")
        raise
