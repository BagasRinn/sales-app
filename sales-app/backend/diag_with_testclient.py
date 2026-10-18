"""Test: insert in one engine.begin(), query via the SAME app.get_db in
a TestClient. Mirrors what test_products_supplier_filter.py does."""
import sys
sys.path.insert(0, '.')
from sqlalchemy import text
from fastapi.testclient import TestClient
from app.main import app
from app.models.database import engine
from app.core.security import create_access_token

USER_BRANCH = "BANJARMASIN"
SUP_ACTIVE = "TEST-SUP-LIST-ACTIVE"

# Cleanup
with engine.begin() as conn:
    conn.execute(text("DELETE FROM products WHERE id IN ('TEST-PROD-A', 'TEST-PROD-I')"))
    conn.execute(text("DELETE FROM suppliers WHERE name = :n"), {"n": SUP_ACTIVE})

# Seed
with engine.begin() as conn:
    conn.execute(text(
        "INSERT INTO suppliers (name, is_active) VALUES ('TEST-SUP-LIST-ACTIVE', true)"
    ))
    conn.execute(text(
        "INSERT INTO products (id, branch, nama_barang, harga, nama_supplier) "
        "VALUES ('TEST-PROD-A', 'BANJARMASIN', 'A', 1000, 'TEST-SUP-LIST-ACTIVE')"
    ))

# Verify it's there
with engine.begin() as conn:
    print("After seed, direct query:", conn.execute(text(
        "SELECT id FROM products WHERE id = 'TEST-PROD-A'"
    )).fetchall())

# Now use TestClient (this is what the test does)
client = TestClient(app)
token = create_access_token({
    "sub": "00000000-0000-0000-0000-000000000099",
    "username": "diag", "role": "ADMIN",
    "branch": USER_BRANCH, "token_version": 0,
})

# But wait — get_current_user needs a real user. Let me create one.
import uuid
diag_user_id = str(uuid.uuid4())
with engine.begin() as conn:
    conn.execute(text(
        "INSERT INTO users (id, username, password_hash, role, branch, is_active) "
        "VALUES (:id, :u, 'h', 'ADMIN', :b, true)"
    ), {"id": diag_user_id, "u": f"DIAG-USER-{diag_user_id[:8]}", "b": USER_BRANCH})

token = create_access_token({
    "sub": diag_user_id, "username": "diag", "role": "ADMIN",
    "branch": USER_BRANCH, "token_version": 0,
})

resp = client.get(
    "/api/v1/products?limit=1000",
    headers={"Authorization": f"Bearer {token}"},
)
ids = {p["id"] for p in resp.json()}
print(f"TestClient response includes TEST-PROD-A? {'TEST-PROD-A' in ids}")
print(f"TestClient response total: {len(ids)} products")
print(f"TestClient response id sample: {list(ids)[:8]}")

# Cleanup
with engine.begin() as conn:
    conn.execute(text("DELETE FROM products WHERE id IN ('TEST-PROD-A', 'TEST-PROD-I')"))
    conn.execute(text("DELETE FROM suppliers WHERE name = :n"), {"n": SUP_ACTIVE})
    conn.execute(text("DELETE FROM users WHERE id = :id"), {"id": diag_user_id})
print("Done")
