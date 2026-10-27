import uuid
from fastapi.testclient import TestClient
from app.main import app
from app.models.database import engine
from app.core.security import create_access_token
from sqlalchemy import text

ORDER_IDEMPOTENCY_KEY = "test-idempotency-key-123"
USER_BRANCH = "BANJARMASIN"  # existing branch in DB for FK

def _cleanup_orders():
    with engine.begin() as conn:
        conn.execute(text("DELETE FROM orders WHERE client_request_id = :k"), {"k": ORDER_IDEMPOTENCY_KEY})

def _make_sales_user() -> str:
    user_id = str(uuid.uuid4())
    with engine.begin() as conn:
        conn.execute(text(
            "INSERT INTO users (id, username, password_hash, role, branch, is_active, token_version) "
            "VALUES (:id, :u, 'test-hash', :r, :b, true, 0)"
        ), {"id": user_id, "u": f"TEST-SALES-{user_id[:8]}", "r": "SALES", "b": USER_BRANCH})
    return user_id

def _make_customer(sales_id: str) -> str:
    cust_id = str(uuid.uuid4())
    with engine.begin() as conn:
        conn.execute(text(
            "INSERT INTO customers (id, kode, nama_toko, alamat, branch, deleted_at) "
            "VALUES (:id, :kode, :nama, :alamat, :branch, NULL)"
        ), {"id": cust_id, "kode": f"CUST-{cust_id[:8]}", "nama": "Test Toko", "alamat": "Jl Test", "branch": USER_BRANCH})
        # assign to sales
        conn.execute(text(
            "INSERT INTO customer_assignments (customer_id, sales_id) VALUES (:cid, :sid)"
        ), {"cid": cust_id, "sid": sales_id})
    return cust_id

def _make_product() -> str:
    prod_id = str(uuid.uuid4())
    with engine.begin() as conn:
        conn.execute(text(
            "INSERT INTO products (id, nama_barang, harga, branch, order_type, stok_sistem, stok_booking, stok_diterima) "
            "VALUES (:id, :nama, :harga, :branch, 'REGULER', 100, 0, 0)"
        ), {"id": prod_id, "nama": "Test Produk", "harga": 5000, "branch": USER_BRANCH})
    return prod_id

def _token(user_id: str) -> str:
    return create_access_token({
        "sub": user_id,
        "username": "t",
        "role": "SALES",
        "branch": USER_BRANCH,
        "token_version": 0,
    })

def test_create_order_idempotent():
    _cleanup_orders()
    sales_id = _make_sales_user()
    cust_id = _make_customer(sales_id)
    prod_id = _make_product()
    try:
        client = TestClient(app)
        headers = {"Authorization": f"Bearer {_token(sales_id)}"}
        payload = {
            "customer_id": cust_id,
            "items": [{"product_id": prod_id, "qty": 1}],
            "order_type": "REGULER",
            "client_request_id": ORDER_IDEMPOTENCY_KEY,
        }
        # First request
        resp1 = client.post("/api/v1/orders", json=payload, headers=headers)
        assert resp1.status_code == 200, resp1.text
        order1 = resp1.json()
        # Second request with same client_request_id
        resp2 = client.post("/api/v1/orders", json=payload, headers=headers)
        assert resp2.status_code == 200, resp2.text
        order2 = resp2.json()
        # Should return same order id
        assert order1["id"] == order2["id"]
    finally:
        _cleanup_orders()