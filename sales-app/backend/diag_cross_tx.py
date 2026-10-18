"""Simulates the test scenario: seed in one transaction, then query via
the app's SessionLocal in a second transaction. Matches what TestClient
does internally."""
import sys
sys.path.insert(0, '.')
from app.models.database import engine, SessionLocal
from app.models.models import Product
from sqlalchemy import text

# Step 1: Seed (same as _seed in the test)
print('--- Step 1: Seed ---')
with engine.begin() as conn:
    conn.execute(text(
        "INSERT INTO suppliers (name, is_active) VALUES ('TEST-SUP-CROSS', true) "
        "ON CONFLICT (name) DO UPDATE SET is_active = EXCLUDED.is_active"
    ))
    conn.execute(text(
        "INSERT INTO products (id, branch, nama_barang, harga, nama_supplier) "
        "VALUES ('TEST-P-CROSS', 'BANJARMASIN', 'X', 1000, 'TEST-SUP-CROSS')"
    ))
    print('Seed transaction committed.')

# Step 2: Query via SessionLocal (same as get_db in the API)
print('--- Step 2: Query via SessionLocal ---')
db = SessionLocal()
try:
    result = db.execute(text(
        "SELECT id, branch, nama_supplier FROM products WHERE id = 'TEST-P-CROSS'"
    )).fetchall()
    print('Found via SessionLocal:', result)
finally:
    db.close()

# Step 3: Cleanup
print('--- Step 3: Cleanup ---')
with engine.begin() as conn:
    conn.execute(text("DELETE FROM products WHERE id = 'TEST-P-CROSS'"))
    conn.execute(text("DELETE FROM suppliers WHERE name = 'TEST-SUP-CROSS'"))
print('Done')
