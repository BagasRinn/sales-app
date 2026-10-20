"""Test untuk GET /reports/summary — pure SQL aggregation endpoint.

Verifikasi:
- Endpoint return summary agregat (TIDAK load order row)
- by_status, by_product, by_sales, by_branch sesuai data
- Filter branch (sales/supervisor) hanya melihat order di branch-nya
- Range validation (max 365 hari, end >= start)

Live DB. Test data prefix: TEST-SUM-*. Cleanup di finally.
"""
import uuid
from datetime import datetime, timezone, timedelta

from sqlalchemy import text
from fastapi.testclient import TestClient
from app.main import app
from app.models.database import engine
from app.core.security import create_access_token


WITA = timezone(timedelta(hours=8))
USER_BRANCH = "BANJARMASIN"
OTHER_BRANCH = "BARABAI"
TEST_PREFIX = "TEST-SUM-"


def _cleanup():
    """Hapus semua test rows dari run sebelumnya. orders.id, customers.id adalah UUID
    (no LIKE), jadi pakai text columns (notes, kode, username) untuk identifikasi."""
    with engine.begin() as conn:
        # Sweep by notes (text column) — hapus order_items dulu (FK)
        conn.execute(text(
            "DELETE FROM order_items WHERE order_id IN "
            "(SELECT id FROM orders WHERE notes LIKE :note)"
        ), {"note": f"{TEST_PREFIX}%"})
        conn.execute(text("DELETE FROM orders WHERE notes LIKE :note"), {"note": f"{TEST_PREFIX}%"})
        conn.execute(text("DELETE FROM products WHERE id LIKE :p"), {"p": f"{TEST_PREFIX}PROD-%"})
        # customers: filter by kode (text), TEST-SUM-CUST- jadi unique
        conn.execute(text(
            "DELETE FROM customers WHERE kode LIKE :p"
        ), {"p": f"{TEST_PREFIX}CUST-%"})
        conn.execute(text("DELETE FROM users WHERE username LIKE :p"), {"p": f"{TEST_PREFIX}USER-%"})


def _seed_user(role: str, branch: str | None) -> str:
    user_id = str(uuid.uuid4())
    with engine.begin() as conn:
        conn.execute(text(
            "INSERT INTO users (id, username, password_hash, role, branch, is_active) "
            "VALUES (:id, :u, 'test-hash', :r, :b, true)"
        ), {"id": user_id, "u": f"{TEST_PREFIX}USER-{role}-{user_id[:8]}", "r": role, "b": branch})
    return user_id


def _seed_product(pid: str, branch: str, harga: int) -> None:
    with engine.begin() as conn:
        conn.execute(text(
            "INSERT INTO products (id, branch, nama_barang, harga) "
            "VALUES (:id, :branch, :nama, :harga)"
        ), {"id": pid, "branch": branch, "nama": f"Test Product {pid[-6:]}", "harga": harga})


def _seed_customer(cid: str) -> None:
    """cid is a UUID string; kode is the test-marker text used for cleanup."""
    with engine.begin() as conn:
        conn.execute(text(
            "INSERT INTO customers (id, kode, nama_toko, branch) "
            "VALUES (:id, :kode, :nama, :branch)"
        ), {"id": cid, "kode": f"{TEST_PREFIX}CUST-{cid[:8]}", "nama": f"Test Customer {cid[:8]}", "branch": USER_BRANCH})


def _seed_order(oid: str, branch: str, sales_id: str, customer_id: str, status: str, created_at: datetime) -> None:
    with engine.begin() as conn:
        conn.execute(text(
            "INSERT INTO orders (id, branch, sales_id, customer_id, status, notes, created_at) "
            "VALUES (:id, :branch, :sid, :cid, :status, :notes, :ts)"
        ), {
            "id": oid, "branch": branch, "sid": sales_id, "cid": customer_id,
            "status": status, "notes": f"{TEST_PREFIX}order", "ts": created_at,
        })


def _seed_order_item(oid: str, product_id: str, qty: int, branch: str = USER_BRANCH) -> None:
    """Insert OrderItem. branch defaults to USER_BRANCH but harus match product branch
    karena ada FK constraint (product_id, branch) -> (products.id, products.branch)."""
    with engine.begin() as conn:
        conn.execute(text(
            "INSERT INTO order_items (id, order_id, product_id, branch, qty) "
            "VALUES (:id, :oid, :pid, :branch, :qty)"
        ), {
            "id": str(uuid.uuid4()), "oid": oid, "pid": product_id,
            "branch": branch, "qty": qty,
        })


def _token(user_id: str, role: str, branch: str | None) -> str:
    return create_access_token({
        "sub": user_id, "username": "t", "role": role,
        "branch": branch, "token_version": 0,
    })


def _today_utc_8() -> datetime:
    """Today at 00:00 WITA, returned as UTC datetime."""
    today_wita = datetime.now(WITA).replace(hour=0, minute=0, second=0, microsecond=0)
    return today_wita.astimezone(timezone.utc)


# Test orders created at tanggal unik supaya tidak konflik dengan data real production
# di DB (yang live). 2020-01-15 adalah tanggal yang tidak mungkin punya data order.
TEST_DATE = "2020-01-15"


def test_summary_aggregates_correctly():
    """Seed 2 orders (1 approved, 1 pending), 2 products, 1 customer. Verify summary."""
    _cleanup()
    user_id = _seed_user("MANAGER", None)
    sales_id = _seed_user("SALES", USER_BRANCH)
    cust_id = str(uuid.uuid4())
    _seed_customer(cust_id)

    prod_a = f"{TEST_PREFIX}PROD-A-{uuid.uuid4().hex[:8]}"
    prod_b = f"{TEST_PREFIX}PROD-B-{uuid.uuid4().hex[:8]}"
    _seed_product(prod_a, USER_BRANCH, 10000)
    _seed_product(prod_b, USER_BRANCH, 20000)

    today_utc = _today_utc_8()
    # Pakai tanggal historis (2020) supaya test order tidak konflik dengan production
    test_dt = datetime(2020, 1, 15, 10, 0, 0, tzinfo=timezone(timedelta(hours=8))).astimezone(timezone.utc)
    order1 = str(uuid.uuid4())
    order2 = str(uuid.uuid4())
    _seed_order(order1, USER_BRANCH, sales_id, cust_id, "APPROVED", test_dt)
    _seed_order(order2, USER_BRANCH, sales_id, cust_id, "PENDING", test_dt + timedelta(hours=2))
    _seed_order_item(order1, prod_a, 3)   # 3 * 10000 = 30000
    _seed_order_item(order1, prod_b, 1)   # 1 * 20000 = 20000 → total 50000
    _seed_order_item(order2, prod_b, 2)   # 2 * 20000 = 40000

    try:
        client = TestClient(app)
        token = _token(user_id, "MANAGER", None)
        resp = client.get(
            f"/api/v1/reports/summary?start_date={TEST_DATE}&end_date={TEST_DATE}",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 200, resp.text
        body = resp.json()

        # Total orders: 2 (1 APPROVED + 1 PENDING)
        assert body["total_orders"] == 2, f"expected 2 orders, got {body['total_orders']}"
        # Total items: 3 + 1 + 2 = 6
        assert body["total_items_sold"] == 6, f"expected 6 items, got {body['total_items_sold']}"
        # Raw revenue: 30000 + 20000 + 40000 = 90000
        assert body["raw_revenue"] == 90000, f"expected 90000, got {body['raw_revenue']}"

        # by_status: 1 APPROVED, 1 PENDING
        status_map = {r["status"]: r["count"] for r in body["by_status"]}
        assert status_map.get("APPROVED") == 1
        assert status_map.get("PENDING") == 1

        # by_product: top by raw_revenue (prod_b = 20000+40000=60000, prod_a = 30000)
        assert len(body["by_product"]) >= 2
        top = body["by_product"][0]
        assert top["product_id"] == prod_b
        assert top["raw_revenue"] == 60000

        # by_sales: 1 sales dengan 2 order
        assert len(body["by_sales"]) >= 1
        s = next(s for s in body["by_sales"] if s["user_id"] == sales_id)
        assert s["order_count"] == 2

        # by_branch: 1 branch
        assert len(body["by_branch"]) == 1
        assert body["by_branch"][0]["branch"] == USER_BRANCH
        assert body["by_branch"][0]["order_count"] == 2
    finally:
        _cleanup()


def test_summary_rejects_oversized_range():
    """Range > 365 hari harus ditolak 400."""
    _cleanup()
    user_id = _seed_user("MANAGER", None)
    try:
        client = TestClient(app)
        token = _token(user_id, "MANAGER", None)
        resp = client.get(
            "/api/v1/reports/summary?start_date=2024-01-01&end_date=2025-12-31",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 400
        assert "365" in resp.json()["detail"]
    finally:
        _cleanup()


def test_summary_rejects_end_before_start():
    """End < start harus 400."""
    _cleanup()
    user_id = _seed_user("MANAGER", None)
    try:
        client = TestClient(app)
        token = _token(user_id, "MANAGER", None)
        resp = client.get(
            "/api/v1/reports/summary?start_date=2026-10-15&end_date=2026-10-01",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 400
    finally:
        _cleanup()


def test_summary_branch_scoped_for_supervisor():
    """SUPERVISOR hanya melihat order di branch-nya, bukan branch lain."""
    _cleanup()
    sup_id = _seed_user("SUPERVISOR", USER_BRANCH)
    sales_id = _seed_user("SALES", USER_BRANCH)
    cust_id = str(uuid.uuid4())
    _seed_customer(cust_id)
    prod = f"{TEST_PREFIX}PROD-X-{uuid.uuid4().hex[:8]}"
    _seed_product(prod, USER_BRANCH, 5000)
    prod_other = f"{TEST_PREFIX}PROD-OTHER-{uuid.uuid4().hex[:8]}"
    _seed_product(prod_other, OTHER_BRANCH, 9999)  # product branch lain

    today_utc = _today_utc_8()
    test_dt = datetime(2020, 1, 15, 10, 0, 0, tzinfo=timezone(timedelta(hours=8))).astimezone(timezone.utc)
    order_my = str(uuid.uuid4())
    order_other = str(uuid.uuid4())
    _seed_order(order_my, USER_BRANCH, sales_id, cust_id, "APPROVED", test_dt)
    _seed_order(order_other, OTHER_BRANCH, sales_id, cust_id, "APPROVED", test_dt + timedelta(hours=1))
    _seed_order_item(order_my, prod, 5)  # 5 * 5000 = 25000
    _seed_order_item(order_other, prod_other, 1, branch=OTHER_BRANCH)  # di branch lain

    try:
        client = TestClient(app)
        token = _token(sup_id, "SUPERVISOR", USER_BRANCH)
        resp = client.get(
            f"/api/v1/reports/summary?start_date={TEST_DATE}&end_date={TEST_DATE}",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 200, resp.text
        body = resp.json()
        # Supervisor hanya melihat 1 order (branch dia)
        assert body["total_orders"] == 1, f"expected 1 order (branch-scoped), got {body['total_orders']}"
        assert body["raw_revenue"] == 25000
    finally:
        _cleanup()
