"""Mimics _seed() exactly but runs outside pytest."""
import sys
sys.path.insert(0, '.')
from sqlalchemy import text
from app.models.database import engine, SessionLocal

USER_BRANCH = "BANJARMASIN"
SUP_ACTIVE = "TEST-SUP-LIST-ACTIVE"
SUP_INACTIVE = "TEST-SUP-LIST-INACTIVE"

# Step 1: cleanup
print("--- Step 1: cleanup ---")
with engine.begin() as conn:
    conn.execute(text("DELETE FROM products WHERE id LIKE 'TEST-PROD-%' OR id LIKE 'TEST-P-FILTER-%'"))
    conn.execute(text("DELETE FROM suppliers WHERE name = :a OR name = :i"), {"a": SUP_ACTIVE, "i": SUP_INACTIVE})

# Step 2: seed
print("--- Step 2: seed ---")
with engine.begin() as conn:
    sup_r = conn.execute(text(
        "INSERT INTO suppliers (name, is_active) VALUES (:n, :a) "
        "ON CONFLICT (name) DO UPDATE SET is_active = EXCLUDED.is_active"
    ), [{"n": SUP_ACTIVE, "a": True}, {"n": SUP_INACTIVE, "a": False}])
    print(f"  supplier rowcount={sup_r.rowcount}")
    prod_r = conn.execute(text(
        "INSERT INTO products (id, branch, nama_barang, harga, nama_supplier) "
        "VALUES (:id, :branch, :nama, 1000, :sup)"
    ), [
        {"id": "TEST-PROD-A", "branch": USER_BRANCH, "nama": "A", "sup": SUP_ACTIVE},
        {"id": "TEST-PROD-I", "branch": USER_BRANCH, "nama": "I", "sup": SUP_INACTIVE},
    ])
    print(f"  products rowcount={prod_r.rowcount}")
    nosup_r = conn.execute(text(
        "INSERT INTO products (id, branch, nama_barang, harga, nama_supplier) "
        "VALUES ('TEST-P-FILTER-NOSUP', :b, 'N', 1000, NULL)"
    ), {"b": USER_BRANCH})
    print(f"  nosup rowcount={nosup_r.rowcount}")

# Step 3: verify in a fresh transaction
print("--- Step 3: verify (fresh transaction) ---")
with engine.begin() as conn:
    rows = conn.execute(text(
        "SELECT id, branch, nama_supplier FROM products WHERE id IN ('TEST-PROD-A', 'TEST-PROD-I', 'TEST-P-FILTER-NOSUP')"
    )).fetchall()
    print(f"  Found: {rows}")

# Step 4: query via SessionLocal (mimics get_db)
print("--- Step 4: query via SessionLocal (mimics API) ---")
db = SessionLocal()
try:
    products = db.query.__self_class__ if False else None
    result = db.execute(text(
        "SELECT id, branch, nama_supplier FROM products WHERE id IN ('TEST-PROD-A', 'TEST-PROD-I', 'TEST-P-FILTER-NOSUP')"
    )).fetchall()
    print(f"  Via SessionLocal: {result}")
finally:
    db.close()

# Step 5: cleanup
print("--- Step 5: cleanup ---")
with engine.begin() as conn:
    conn.execute(text("DELETE FROM products WHERE id LIKE 'TEST-PROD-%' OR id LIKE 'TEST-P-FILTER-%'"))
    conn.execute(text("DELETE FROM suppliers WHERE name = :a OR name = :i"), {"a": SUP_ACTIVE, "i": SUP_INACTIVE})
print("Done")
