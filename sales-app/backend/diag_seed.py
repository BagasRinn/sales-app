"""Quick diagnostic: verify engine + tables work as expected."""
import sys
sys.path.insert(0, '.')
from app.models.database import engine
from sqlalchemy import text

with engine.begin() as conn:
    conn.execute(text(
        "INSERT INTO suppliers (name, is_active) VALUES ('TEST-SUP-DEBUG', true) "
        "ON CONFLICT (name) DO UPDATE SET is_active = EXCLUDED.is_active"
    ))
    conn.execute(text(
        "INSERT INTO products (id, branch, nama_barang, harga, nama_supplier) "
        "VALUES ('TEST-P-DEBUG', 'BANJARMASIN', 'D', 1000, 'TEST-SUP-DEBUG')"
    ))
    print('Verify:', conn.execute(text(
        "SELECT id, branch, nama_supplier FROM products WHERE id = 'TEST-P-DEBUG'"
    )).fetchall())
    conn.execute(text("DELETE FROM products WHERE id = 'TEST-P-DEBUG'"))
    conn.execute(text("DELETE FROM suppliers WHERE name = 'TEST-SUP-DEBUG'"))
print('Done')
