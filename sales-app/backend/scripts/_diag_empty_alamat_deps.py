"""Check if 6 bad-alamat test customers have dependent rows (orders, assignments)."""
from app.models.database import engine
from sqlalchemy import text

SQL = """
WITH bad AS (
    SELECT id FROM customers
    WHERE deleted_at IS NULL AND (alamat IS NULL OR alamat = '')
)
SELECT
    (SELECT COUNT(*) FROM orders o WHERE o.customer_id IN (SELECT id FROM bad)) AS order_count,
    (SELECT COUNT(*) FROM customer_assignments ca WHERE ca.customer_id IN (SELECT id FROM bad)) AS assignment_count,
    (SELECT COUNT(*) FROM order_items oi WHERE oi.order_id IN (SELECT o.id FROM orders o WHERE o.customer_id IN (SELECT id FROM bad))) AS order_item_count
"""

with engine.connect() as conn:
    r = conn.execute(text(SQL)).fetchone()
    print(f"orders tied to bad customers        : {r.order_count}")
    print(f"customer_assignments tied to bad    : {r.assignment_count}")
    print(f"order_items tied via orders         : {r.order_item_count}")
