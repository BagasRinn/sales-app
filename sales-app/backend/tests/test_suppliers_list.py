import uuid
from sqlalchemy import text
from fastapi.testclient import TestClient
from app.main import app
from app.models.database import engine
from app.core.security import create_access_token

# Reuse the live DB. Test data: prefix TEST-SUP- per Global Constraints.
TEST_SUP_ACTIVE = "TEST-SUP-LIST-ACTIVE"
TEST_SUP_INACTIVE = "TEST-SUP-LIST-INACTIVE"
# Real branches because users.branch has a FK to branches.code.
# Products have no such FK but to keep user/product visibility aligned,
# we put the test products in real branches too.
USER_BRANCH = "BANJARMASIN"
OTHER_BRANCH = "BARABAI"


def _cleanup_suppliers():
    """Sweep any leftover test rows from previous runs (any branch)."""
    with engine.begin() as conn:
        conn.execute(text(
            "DELETE FROM products WHERE id LIKE 'TEST-PROD-%' "
            "OR nama_supplier LIKE 'TEST-SUP-LIST-%'"
        ))
        conn.execute(text("DELETE FROM suppliers WHERE name LIKE 'TEST-SUP-LIST-%'"))


def _cleanup_users():
    with engine.begin() as conn:
        conn.execute(text("DELETE FROM users WHERE username LIKE 'TEST-USER-LIST-%'"))


def _cleanup():
    _cleanup_suppliers()
    _cleanup_users()


def _make_user(role: str, branch: str | None) -> str:
    """Create a real test user. Required because get_current_user looks up
    users in the DB and re-reads role/branch from the row (not the JWT claims)."""
    user_id = str(uuid.uuid4())
    with engine.begin() as conn:
        conn.execute(text(
            "INSERT INTO users (id, username, password_hash, role, branch, is_active, token_version) "
            "VALUES (:id, :u, 'test-hash', :r, :b, true, 0)"
        ), {"id": user_id, "u": f"TEST-USER-LIST-{role}-{user_id[:8]}", "r": role, "b": branch})
    return user_id


def _seed():
    _cleanup_suppliers()
    with engine.begin() as conn:
        conn.execute(text(
            "INSERT INTO suppliers (name, is_active, order_type) VALUES (:n, :a, 'REGULER') "
            "ON CONFLICT (name) DO UPDATE SET is_active = EXCLUDED.is_active"
        ), [{"n": TEST_SUP_ACTIVE, "a": True}, {"n": TEST_SUP_INACTIVE, "a": False}])
        conn.execute(text(
            "INSERT INTO products (id, branch, nama_barang, harga, stok_diterima, "
            "order_type, nama_supplier) "
            "VALUES (:id, :branch, :nama, 1000, 0, 'REGULER', :sup)"
        ), [
            {"id": "TEST-PROD-A", "branch": USER_BRANCH, "nama": "A", "sup": TEST_SUP_ACTIVE},
            {"id": "TEST-PROD-I", "branch": USER_BRANCH, "nama": "I", "sup": TEST_SUP_INACTIVE},
        ])


def _seed_other_branch():
    with engine.begin() as conn:
        conn.execute(text(
            "INSERT INTO products (id, branch, nama_barang, harga, stok_diterima, "
            "order_type, nama_supplier) "
            "VALUES ('TEST-PROD-OTHER', :b, 'O', 1000, 0, 'REGULER', :sup)"
        ), {"b": OTHER_BRANCH, "sup": TEST_SUP_ACTIVE})


def _token(user_id: str, role: str, branch: str | None) -> str:
    return create_access_token({
        "sub": user_id, "username": "t", "role": role,
        "branch": branch, "token_version": 0,
    })


def test_supplier_list_includes_product_count():
    _seed()
    user_id = _make_user("ADMIN", USER_BRANCH)
    try:
        client = TestClient(app)
        token = _token(user_id, "ADMIN", USER_BRANCH)
        resp = client.get("/api/v1/suppliers", headers={"Authorization": f"Bearer {token}"})
        assert resp.status_code == 200
        rows = {r["name"]: r for r in resp.json() if r["name"].startswith("TEST-SUP-LIST-")}
        assert rows[TEST_SUP_ACTIVE]["is_active"] is True
        assert rows[TEST_SUP_ACTIVE]["product_count"] == 1
        assert rows[TEST_SUP_INACTIVE]["is_active"] is False
        assert rows[TEST_SUP_INACTIVE]["product_count"] == 1
    finally:
        _cleanup()


def test_supplier_list_active_filter():
    _seed()
    user_id = _make_user("ADMIN", USER_BRANCH)
    try:
        client = TestClient(app)
        token = _token(user_id, "ADMIN", USER_BRANCH)
        resp = client.get("/api/v1/suppliers?active=false", headers={"Authorization": f"Bearer {token}"})
        assert resp.status_code == 200
        rows = resp.json()
        assert all(r["is_active"] is False for r in rows)
    finally:
        _cleanup()


def test_supervisor_product_count_excludes_other_branches():
    """RF#3: SUPERVISOR sees product_count only for their branch."""
    _seed()
    _seed_other_branch()
    user_id = _make_user("SUPERVISOR", USER_BRANCH)
    try:
        client = TestClient(app)
        token = _token(user_id, "SUPERVISOR", USER_BRANCH)
        resp = client.get("/api/v1/suppliers", headers={"Authorization": f"Bearer {token}"})
        assert resp.status_code == 200
        rows = {r["name"]: r for r in resp.json() if r["name"].startswith("TEST-SUP-LIST-")}
        # Count should be 1 (only this branch's product), not 2 (which would include OTHER_BRANCH)
        assert rows[TEST_SUP_ACTIVE]["product_count"] == 1, \
            f"SUPERVISOR count should be branch-scoped, got {rows[TEST_SUP_ACTIVE]['product_count']}"
    finally:
        _cleanup()


def test_manager_product_count_is_global():
    """RF#3 (manager side): MANAGER's product_count spans all branches."""
    _seed()
    _seed_other_branch()
    user_id = _make_user("MANAGER", None)
    try:
        client = TestClient(app)
        token = _token(user_id, "MANAGER", None)
        resp = client.get("/api/v1/suppliers", headers={"Authorization": f"Bearer {token}"})
        rows = {r["name"]: r for r in resp.json() if r["name"].startswith("TEST-SUP-LIST-")}
        # Count should be 2 (both branches)
        assert rows[TEST_SUP_ACTIVE]["product_count"] == 2, \
            f"MANAGER count should be global, got {rows[TEST_SUP_ACTIVE]['product_count']}"
    finally:
        _cleanup()
