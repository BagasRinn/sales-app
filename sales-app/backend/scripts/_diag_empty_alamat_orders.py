"""Show details of the 6 orders tied to bad-alamat customers."""
from app.models.database import engine
from sqlalchemy import text

SQL = """
SELECT
    o.id AS order_id, o.status, o.created_at,
    c.id AS customer_id, c.kode, c.nama_toko, c.alamat, c.branch,
    oi.id AS order_item_id, oi.product_id
FROM orders o
JOIN customers c ON c.id = o.customer_id
LEFT JOIN order_items oi ON oi.order_id = o.id
WHERE c.id IN (
    SELECT id FROM customers
    WHERE deleted_at IS NULL AND (alamat IS NULL OR alamat = '')
)
ORDER BY o.created_at DESC
"""

with engine.connect() as conn:
    rows = conn.execute(text(SQL)).fetchall()
    print(f"Rows: {len(rows)}")
    print()
    for r in rows:
        print(f"  order={r.order_id} status={r.status} created={r.created_at}")
        print(f"    cust={r.customer_id} branch={r.branch} kode={r.kode!r} nama={r.nama_toko!r} alamat={r.alamat!r}")
        print(f"    order_item={r.order_item_id} product={r.product_id}")
        print()
