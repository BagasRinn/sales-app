"""Test optimasi egress Supabase (pool, N+1, agregasi report, pagination).

Cakupan:
- engine pakai QueuePool (bukan NullPool) dengan sizing kecil
- POST /orders batch-load Product sekali (bukan 2N query)
- /reports/cross-branch/* agregasi per branch, bukan query per branch
- /bulletins pagination opt-in (limit/offset/include_total), tanpa param = sama

Live DB. Semua test data pakai prefix TEST-EGRESS- dan dibersihkan di finally.
"""
import uuid
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone

from fastapi.testclient import TestClient
from sqlalchemy import event, text
from sqlalchemy.pool import QueuePool

from app.main import app
from app.models.database import engine
from app.core.security import create_access_token

WITA = timezone(timedelta(hours=8))
USER_BRANCH = "BANJARMASIN"  # branch real (FK products/customers)
TEST_PREFIX = "TEST-EGRESS-"
API = "/api/v1"


@contextmanager
def captured_statements():
    """Kumpulkan SQL statement yang benar-benar dikirim ke DB."""
    statements = []

    def _record(conn, cursor, statement, parameters, context, executemany):
        statements.append(statement)

    event.listen(engine, "before_cursor_execute", _record)
    try:
        yield statements
    finally:
        event.remove(engine, "before_cursor_execute", _record)


def _count(statements, needle: str) -> int:
    return sum(1 for s in statements if needle.lower() in s.lower())


def _cleanup():
    """Sweep leftover rows dari run sebelumnya (FK order: log → items → order)."""
    with engine.begin() as conn:
        conn.execute(text(
            "DELETE FROM stok_log WHERE order_id IN "
            "(SELECT id FROM orders WHERE notes LIKE :n)"
        ), {"n": f"{TEST_PREFIX}%"})
        conn.execute(text("DELETE FROM stok_log WHERE product_id LIKE :p"),
                     {"p": f"{TEST_PREFIX}PROD-%"})
        conn.execute(text(
            "DELETE FROM order_items WHERE order_id IN "
            "(SELECT id FROM orders WHERE notes LIKE :n)"
        ), {"n": f"{TEST_PREFIX}%"})
        conn.execute(text("DELETE FROM orders WHERE notes LIKE :n"), {"n": f"{TEST_PREFIX}%"})
        conn.execute(text(
            "DELETE FROM bulletin_dismisses WHERE bulletin_id IN "
            "(SELECT id FROM bulletins WHERE title LIKE :t)"
        ), {"t": f"{TEST_PREFIX}%"})
        conn.execute(text("DELETE FROM bulletins WHERE title LIKE :t"), {"t": f"{TEST_PREFIX}%"})
        conn.execute(text("DELETE FROM products WHERE id LIKE :p"), {"p": f"{TEST_PREFIX}PROD-%"})
        conn.execute(text("DELETE FROM customers WHERE kode LIKE :k"), {"k": f"{TEST_PREFIX}CUST-%"})
        conn.execute(text("DELETE FROM users WHERE username LIKE :u"), {"u": f"{TEST_PREFIX}USER-%"})


def _seed_user(role: str, branch: str | None) -> str:
    user_id = str(uuid.uuid4())
    with engine.begin() as conn:
        conn.execute(text(
            "INSERT INTO users (id, username, password_hash, role, branch, is_active) "
            "VALUES (:id, :u, 'test-hash', :r, :b, true)"
        ), {"id": user_id, "u": f"{TEST_PREFIX}USER-{role}-{user_id[:8]}", "r": role, "b": branch})
    return user_id


def _seed_customer(branch: str = USER_BRANCH) -> str:
    cust_id = str(uuid.uuid4())
    with engine.begin() as conn:
        conn.execute(text(
            "INSERT INTO customers (id, kode, nama_toko, branch) "
            "VALUES (:id, :kode, :nama, :branch)"
        ), {
            "id": cust_id, "kode": f"{TEST_PREFIX}CUST-{cust_id[:8]}",
            "nama": f"Test Egress {cust_id[:8]}", "branch": branch,
        })
    return cust_id


def _seed_product(branch: str, harga: int = 1000, stok: int = 100) -> str:
    pid = f"{TEST_PREFIX}PROD-{uuid.uuid4().hex[:8]}"
    with engine.begin() as conn:
        conn.execute(text(
            "INSERT INTO products (id, branch, nama_barang, harga, stok_sistem, stok_booking, "
            "stok_diterima, order_type) "
            "VALUES (:id, :branch, :nama, :harga, :stok, 0, 0, 'REGULER')"
        ), {"id": pid, "branch": branch, "nama": f"Test Egress {pid[-6:]}", "harga": harga, "stok": stok})
    return pid


def _seed_bulletin(title_suffix: str, created_at: datetime) -> str:
    bid = str(uuid.uuid4())
    with engine.begin() as conn:
        conn.execute(text(
            "INSERT INTO bulletins (id, branch, title, description, expire_at, created_at) "
            "VALUES (:id, NULL, :title, :desc, NULL, :ts)"
        ), {"id": bid, "title": f"{TEST_PREFIX}BUL-{title_suffix}", "desc": "test", "ts": created_at})
    return bid


def _auth(user_id: str, role: str, branch: str | None) -> dict:
    token = create_access_token({
        "sub": user_id, "username": "t", "role": role,
        "branch": branch, "token_version": 0,
    })
    return {"Authorization": f"Bearer {token}"}


# ==================== 1. Connection pool ====================

def test_engine_uses_queue_pool():
    """Pool reuse koneksi (bukan NullPool) supaya tidak handshake tiap request."""
    assert isinstance(engine.pool, QueuePool), f"pool={type(engine.pool).__name__}"
    assert engine.pool.size() == 5
    assert engine.pool._max_overflow == 5
    assert engine.pool._recycle == 1800
    assert engine.pool._pre_ping is True


# ==================== 2. Batch load product di POST /orders ====================

def test_create_order_loads_products_in_one_batch():
    """Item berapapun, Product di-load 1x (IN query), bukan 2 query per item."""
    _cleanup()
    sales_id = _seed_user("SALES", USER_BRANCH)
    cust_id = _seed_customer()
    prod_ids = [_seed_product(USER_BRANCH) for _ in range(4)]

    payload = {
        "customer_id": cust_id,
        "notes": f"{TEST_PREFIX}order api",
        "order_type": "REGULER",
        "items": [{"product_id": pid, "qty": 2} for pid in prod_ids],
    }

    try:
        client = TestClient(app)
        with captured_statements() as stmts:
            resp = client.post(f"{API}/orders", json=payload,
                               headers=_auth(sales_id, "SALES", USER_BRANCH))
        assert resp.status_code == 200, resp.text
        assert len(resp.json()["items"]) == 4

        batch_loads = _count(stmts, "products.id IN")
        assert batch_loads == 1, (
            f"expected 1 batch Product query, got {batch_loads}.\n"
            + "\n".join(s for s in stmts if "products" in s.lower())
        )
    finally:
        _cleanup()


# ==================== 3. Agregasi cross-branch (bukan N+1 per branch) ====================

def test_cross_branch_summaries_use_fixed_query_count():
    """sales-summary = 2 query orders + 1 customers; stock-summary = 1 products."""
    _cleanup()
    manager_id = _seed_user("MANAGER", None)
    try:
        client = TestClient(app)
        headers = _auth(manager_id, "MANAGER", None)

        with captured_statements() as stmts:
            resp = client.get(f"{API}/reports/cross-branch/sales-summary", headers=headers)
        assert resp.status_code == 200, resp.text
        assert len(resp.json()["branches"]) >= 1
        assert _count(stmts, "FROM orders") == 2, (
            f"expected 2 orders query, got {_count(stmts, 'FROM orders')}"
        )
        assert _count(stmts, "FROM customers") == 1, (
            f"expected 1 customers query, got {_count(stmts, 'FROM customers')}"
        )

        with captured_statements() as stmts:
            resp = client.get(f"{API}/reports/cross-branch/stock-summary", headers=headers)
        assert resp.status_code == 200, resp.text
        assert _count(stmts, "FROM products") == 1, (
            f"expected 1 products query, got {_count(stmts, 'FROM products')}"
        )
    finally:
        _cleanup()


# ==================== 4. Pagination opt-in /bulletins ====================

def test_bulletins_pagination_is_opt_in():
    """limit/offset slice hasil; include_total kirim X-Total-Count."""
    _cleanup()
    sales_id = _seed_user("SALES", USER_BRANCH)
    base = datetime.now(WITA) - timedelta(days=1)
    for i in range(3):
        _seed_bulletin(f"{i}-{uuid.uuid4().hex[:6]}", base + timedelta(minutes=i))

    try:
        client = TestClient(app)
        headers = _auth(sales_id, "SALES", USER_BRANCH)

        # Tanpa param: perilaku lama (semua, tanpa header total)
        all_resp = client.get(f"{API}/bulletins", headers=headers)
        assert all_resp.status_code == 200, all_resp.text
        assert "X-Total-Count" not in all_resp.headers

        page1 = client.get(f"{API}/bulletins?limit=2&include_total=true", headers=headers)
        assert page1.status_code == 200, page1.text
        page1_ids = [b["id"] for b in page1.json()]
        assert len(page1_ids) == 2
        assert int(page1.headers["X-Total-Count"]) >= 3

        page2 = client.get(f"{API}/bulletins?limit=2&offset=2", headers=headers)
        assert page2.status_code == 200, page2.text
        page2_ids = [b["id"] for b in page2.json()]
        assert page2_ids, "halaman 2 harus berisi sisa data"
        assert not set(page1_ids) & set(page2_ids), "halaman 1 dan 2 tidak boleh overlap"
        assert len(set(page1_ids) | set(page2_ids)) >= 3

        assert client.get(f"{API}/bulletins?limit=0", headers=headers).status_code == 422
        assert client.get(f"{API}/bulletins?offset=-1", headers=headers).status_code == 422
    finally:
        _cleanup()


# ==================== 5. Batch load product di PUT /orders/{id} ====================

def test_update_order_loads_products_in_one_batch():
    """Update item berapapun, Product di-load 1x (pakai _load_products_map yang sama
    dengan POST /orders) — bukan 1-2 query per item."""
    _cleanup()
    sales_id = _seed_user("SALES", USER_BRANCH)
    cust_id = _seed_customer()
    prod_ids = [_seed_product(USER_BRANCH) for _ in range(4)]

    payload = {
        "customer_id": cust_id,
        "notes": f"{TEST_PREFIX}order put",
        "order_type": "REGULER",
        "items": [{"product_id": pid, "qty": 1} for pid in prod_ids],
    }

    try:
        client = TestClient(app)
        headers = _auth(sales_id, "SALES", USER_BRANCH)
        created = client.post(f"{API}/orders", json=payload, headers=headers)
        assert created.status_code == 200, created.text
        order_id = created.json()["id"]

        payload["items"] = [{"product_id": pid, "qty": 3} for pid in prod_ids]
        payload["notes"] = f"{TEST_PREFIX}order put edited"
        with captured_statements() as stmts:
            resp = client.put(f"{API}/orders/{order_id}", json=payload, headers=headers)
        assert resp.status_code == 200, resp.text
        assert len(resp.json()["items"]) == 4

        batch_loads = _count(stmts, "products.id IN")
        assert batch_loads == 1, (
            f"expected 1 batch Product query, got {batch_loads}.\n"
            + "\n".join(s for s in stmts if "products" in s.lower())
        )
    finally:
        _cleanup()

