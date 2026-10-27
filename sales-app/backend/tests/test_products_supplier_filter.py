import uuid
from sqlalchemy import text
from fastapi.testclient import TestClient
from app.main import app
from app.models.database import engine
from app.core.security import create_access_token

USER_BRANCH = "BANJARMASIN"  # real branch for FK
# Use EXACTLY the same supplier/product naming as the working test_suppliers_list.py
# to isolate whether the issue is naming-specific or structural.
SUP_ACTIVE = "TEST-SUP-LIST-ACTIVE"
SUP_INACTIVE = "TEST-SUP-LIST-INACTIVE"


def _cleanup():
    """Sweep leftover test rows from any previous run."""
    with engine.begin() as conn:
        conn.execute(text(
            "DELETE FROM products WHERE id LIKE 'TEST-P-FILTER-%' "
            "OR id LIKE 'TEST-PROD-%'"
        ))
        conn.execute(text(
            "DELETE FROM suppliers WHERE name = :a OR name = :i"
        ), {"a": SUP_ACTIVE, "i": SUP_INACTIVE})
        conn.execute(text(
            "DELETE FROM users WHERE username LIKE 'TEST-USER-FILTER-%'"
        ))


def _seed():
    """Mirror test_suppliers_list.py exactly. Set BOTH suppliers to active
    so the toggle test's precondition (SALES sees the product before
    deactivation) holds. The SALES test then deactivates SUP_INACTIVE itself."""
    _cleanup()
    with engine.begin() as conn:
        conn.execute(text(
            "INSERT INTO suppliers (name, is_active, order_type) VALUES (:n, :a, 'REGULER') "
            "ON CONFLICT (name) DO UPDATE SET is_active = EXCLUDED.is_active"
        ), [{"n": SUP_ACTIVE, "a": True}, {"n": SUP_INACTIVE, "a": True}])
        # Use exact test_suppliers_list.py SQL — no ON CONFLICT
        conn.execute(text(
            "INSERT INTO products (id, branch, nama_barang, harga, stok_diterima, "
            "order_type, nama_supplier) "
            "VALUES (:id, :branch, :nama, 1000, 0, 'REGULER', :sup)"
        ), [
            {"id": "TEST-PROD-A", "branch": USER_BRANCH, "nama": "A", "sup": SUP_ACTIVE},
            {"id": "TEST-PROD-I", "branch": USER_BRANCH, "nama": "I", "sup": SUP_INACTIVE},
        ])
        # NOSUP product with NULL supplier
        conn.execute(text(
            "INSERT INTO products (id, branch, nama_barang, harga, stok_diterima, "
            "order_type, nama_supplier) "
            "VALUES ('TEST-P-FILTER-NOSUP', :b, 'N', 1000, 0, 'REGULER', NULL)"
        ), {"b": USER_BRANCH})


def _make_user(role: str, branch):
    user_id = str(uuid.uuid4())
    with engine.begin() as conn:
        conn.execute(text(
            "INSERT INTO users (id, username, password_hash, role, branch, is_active, token_version) "
            "VALUES (:id, :u, 'test-hash', :r, :b, true, 0)"
        ), {"id": user_id, "u": f"TEST-USER-FILTER-{role}-{user_id[:8]}", "r": role, "b": branch})
    return user_id


def _token(user_id: str, role: str, branch) -> str:
    return create_access_token({
        "sub": user_id, "username": "t", "role": role,
        "branch": branch, "token_version": 0,
    })


def test_sales_sees_only_active_or_null_supplier():
    _seed()
    # SALES test: deactivate SUP_INACTIVE so the inactive-supplier product
    # is hidden from SALES.
    with engine.begin() as conn:
        conn.execute(text(
            "UPDATE suppliers SET is_active = false WHERE name = :n"
        ), {"n": SUP_INACTIVE})
    sales_id = _make_user("SALES", USER_BRANCH)
    try:
        client = TestClient(app)
        resp = client.get(
            "/api/v1/products?search=TEST-",
            headers={"Authorization": f"Bearer {_token(sales_id, 'SALES', USER_BRANCH)}"},
        )
        assert resp.status_code == 200
        ids = {p["id"] for p in resp.json()}
        assert "TEST-PROD-A" in ids, "active supplier product (TEST-PROD-A) should be visible"
        assert "TEST-P-FILTER-NOSUP" in ids, "null supplier product should be visible (backward-compat)"
        assert "TEST-PROD-I" not in ids, "inactive supplier product (TEST-PROD-I) should be hidden"
    finally:
        _cleanup()


def test_admin_sees_all_products_regardless_of_supplier():
    _seed()
    admin_id = _make_user("ADMIN", USER_BRANCH)
    try:
        client = TestClient(app)
        resp = client.get(
            "/api/v1/products?search=TEST-",
            headers={"Authorization": f"Bearer {_token(admin_id, 'ADMIN', USER_BRANCH)}"},
        )
        ids = {p["id"] for p in resp.json()}
        assert "TEST-PROD-A" in ids
        assert "TEST-P-FILTER-NOSUP" in ids
        assert "TEST-PROD-I" in ids
    finally:
        _cleanup()


def test_supervisor_sees_all_products_regardless_of_supplier():
    _seed()
    sup_id = _make_user("SUPERVISOR", USER_BRANCH)
    try:
        client = TestClient(app)
        resp = client.get(
            "/api/v1/products?search=TEST-",
            headers={"Authorization": f"Bearer {_token(sup_id, 'SUPERVISOR', USER_BRANCH)}"},
        )
        ids = {p["id"] for p in resp.json()}
        assert "TEST-PROD-I" in ids, "SUPERVISOR should see all"
    finally:
        _cleanup()


def test_manager_sees_all_products_regardless_of_supplier():
    _seed()
    mgr_id = _make_user("MANAGER", None)
    try:
        client = TestClient(app)
        resp = client.get(
            "/api/v1/products?search=TEST-",
            headers={"Authorization": f"Bearer {_token(mgr_id, 'MANAGER', None)}"},
        )
        ids = {p["id"] for p in resp.json()}
        assert "TEST-PROD-I" in ids, "MANAGER (global) should see all"
    finally:
        _cleanup()


def test_toggling_supplier_hides_product_from_sales_on_refetch():
    """RF#1: a fresh SALES /products call after a toggle reflects the change."""
    _seed()
    # Both suppliers are active in _seed — so SALES sees TEST-PROD-I
    # initially. Then we toggle SUP_INACTIVE to inactive and verify SALES
    # loses access.
    sales_id = _make_user("SALES", USER_BRANCH)
    mgr_id = _make_user("MANAGER", None)
    try:
        client = TestClient(app)
        sales_token = _token(sales_id, "SALES", USER_BRANCH)
        mgr_token = _token(mgr_id, "MANAGER", None)

        # 1. Initially: supplier is ACTIVE → SALES sees the product
        resp = client.get(
            "/api/v1/products?search=TEST-",
            headers={"Authorization": f"Bearer {sales_token}"},
        )
        assert "TEST-PROD-I" in {p["id"] for p in resp.json()}, \
            "precondition: TEST-PROD-I supplier is currently active"

        # 2. Manager toggles supplier INACTIVE
        toggle = client.patch(
            f"/api/v1/suppliers/{SUP_INACTIVE}/active",
            json={"is_active": False},
            headers={"Authorization": f"Bearer {mgr_token}"},
        )
        assert toggle.status_code == 200
        assert toggle.json()["is_active"] is False

        # 3. SALES re-fetches → product no longer appears
        resp2 = client.get(
            "/api/v1/products?search=TEST-",
            headers={"Authorization": f"Bearer {sales_token}"},
        )
        assert "TEST-PROD-I" not in {p["id"] for p in resp2.json()}, \
            "SALES should not see TEST-PROD-I after supplier toggled inactive"
    finally:
        # Re-activate so other tests / future runs aren't affected
        with engine.begin() as conn:
            conn.execute(text(
                "UPDATE suppliers SET is_active = TRUE WHERE name = :n"
            ), {"n": SUP_INACTIVE})
        _cleanup()
