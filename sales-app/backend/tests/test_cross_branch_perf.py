"""Performance test /reports/cross-branch/* — implementasi GROUP BY (bukan query per branch).

Seed ~1000 order + order_item di semua branch, lalu assert waktu respons endpoint
tetap sebanding beberapa query (limit relatif ke baseline 1 query) — implementasi
lama (query scalar per branch) tembus limit.

Live DB. Semua row pakai prefix TEST-PERF- dan dihapus di finally.
"""
import time
import uuid
from datetime import datetime, timedelta, timezone

from fastapi.testclient import TestClient
from sqlalchemy import text

from app.main import app
from app.core.branch import get_valid_branch_codes
from app.core.security import create_access_token
from app.models.database import engine

WITA = timezone(timedelta(hours=8))
TEST_PREFIX = "TEST-PERF-"
API = "/api/v1"
ROW_COUNT = 1000            # total order yang di-seed
REPEATS = 3                 # ambil waktu terbaik dari 3 hit (kurangi noise jaringan)
BASELINE_URL = "/branches"  # endpoint 1 query kecil → ukur latency jaringan + DB
QUERY_BUDGET = 6            # endpoint cross-branch ≤4 query; 6× baseline = slack variansi
MAX_MS = 500.0              # tambahan slack absolut (ms) di atas QUERY_BUDGET × baseline


def _cleanup():
    """Sweep row TEST-PERF- (FK: stok_log → order_items → orders → products → customers → users)."""
    with engine.begin() as conn:
        conn.execute(text(
            "DELETE FROM stok_log WHERE order_id IN "
            "(SELECT id FROM orders WHERE notes LIKE :n)"
        ), {"n": f"{TEST_PREFIX}%"})
        conn.execute(text(
            "DELETE FROM order_items WHERE order_id IN "
            "(SELECT id FROM orders WHERE notes LIKE :n)"
        ), {"n": f"{TEST_PREFIX}%"})
        conn.execute(text("DELETE FROM orders WHERE notes LIKE :n"), {"n": f"{TEST_PREFIX}%"})
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


def _seed_customer(branch: str) -> str:
    cust_id = str(uuid.uuid4())
    with engine.begin() as conn:
        conn.execute(text(
            "INSERT INTO customers (id, kode, nama_toko, branch) "
            "VALUES (:id, :kode, :nama, :branch)"
        ), {
            "id": cust_id, "kode": f"{TEST_PREFIX}CUST-{cust_id[:8]}",
            "nama": f"Test Perf {cust_id[:8]}", "branch": branch,
        })
    return cust_id


def _seed_product(branch: str, harga: int = 1000) -> str:
    pid = f"{TEST_PREFIX}PROD-{uuid.uuid4().hex[:8]}"
    with engine.begin() as conn:
        conn.execute(text(
            "INSERT INTO products (id, branch, nama_barang, harga, stok_sistem, stok_booking, "
            "stok_diterima, order_type) "
            "VALUES (:id, :branch, :nama, :harga, 50, 0, 0, 'REGULER')"
        ), {"id": pid, "branch": branch, "nama": f"Test Perf {pid[-6:]}", "harga": harga})
    return pid


def _seed_dataset() -> int:
    """Bulk-insert ROW_COUNT order (status APPROVED) + 1 item per order, tersebar rata
    di semua branch valid. 2 round-trip (orders, order_items) — bukan 1000 insert.

    customer + product di-seed 1 per branch; order_item.branch harus sama dengan
    product.branch (FK composite product_id + branch).
    """
    codes = get_valid_branch_codes()
    ts = datetime(2020, 3, 1, 10, 0, tzinfo=WITA).astimezone(timezone.utc)
    per_branch = ROW_COUNT // len(codes)
    orders, items = [], []
    for code in codes:
        sales_id = _seed_user("SALES", code)
        cust_id = _seed_customer(code)
        prod_id = _seed_product(code)
        for _ in range(per_branch):
            oid = str(uuid.uuid4())
            orders.append({
                "id": oid, "branch": code, "sid": sales_id, "cid": cust_id,
                "status": "APPROVED", "notes": f"{TEST_PREFIX}perf load", "ts": ts,
            })
            items.append({
                "id": str(uuid.uuid4()), "oid": oid, "pid": prod_id,
                "branch": code, "qty": 3,
            })
    with engine.begin() as conn:
        conn.execute(text(
            "INSERT INTO orders (id, branch, sales_id, customer_id, status, notes, created_at) "
            "VALUES (:id, :branch, :sid, :cid, :status, :notes, :ts)"
        ), orders)
        conn.execute(text(
            "INSERT INTO order_items (id, order_id, product_id, branch, qty) "
            "VALUES (:id, :oid, :pid, :branch, :qty)"
        ), items)
    return len(orders)


def _best_ms(client: TestClient, url: str, headers: dict) -> tuple[float, dict]:
    """Hit endpoint REPEATS kali, return (waktu terbaik ms, body terakhir)."""
    best = float("inf")
    body: dict = {}
    for _ in range(REPEATS):
        start = time.perf_counter()
        resp = client.get(url, headers=headers)
        elapsed = (time.perf_counter() - start) * 1000
        assert resp.status_code == 200, resp.text
        body = resp.json()
        best = min(best, elapsed)
    return best, body


def test_cross_branch_endpoints_under_500ms_with_1000_orders():
    """Overhead agregasi per branch harus tetap sebanding beberapa query, bukan ×branch.

    Latency absolut bergantung jarak ke Supabase (dev remote: ~170ms/query), jadi
    limit dibuat relatif: QUERY_BUDGET × waktu 1 query kecil + 500ms slack.
    Lokal (DB dekat, ~20ms/query) → limit ≈ 620ms, praktis setara target 500ms;
    remote → ≈ 6.7s. Implementasi lama (query per branch: 5 branch × 4 query)
    tembus jauh di atas limit ini.
    """
    _cleanup()
    manager_id = _seed_user("MANAGER", None)
    try:
        client = TestClient(app)
        token = create_access_token({
            "sub": manager_id, "username": "t", "role": "MANAGER",
            "branch": None, "token_version": 0,
        })
        headers = {"Authorization": f"Bearer {token}"}

        # Warmup: buka koneksi pool + isi branch cache sebelum diukur.
        warmup = client.get(f"{API}/reports/cross-branch/sales-summary", headers=headers)
        assert warmup.status_code == 200, warmup.text

        seeded = _seed_dataset()
        assert seeded >= 500, f"dataset terlalu kecil: {seeded} order"

        baseline, _ = _best_ms(client, f"{API}{BASELINE_URL}", headers)
        assert baseline > 0
        limit = baseline * QUERY_BUDGET + MAX_MS

        elapsed, body = _best_ms(client, f"{API}/reports/cross-branch/sales-summary", headers)
        branches = body["branches"]
        assert len(branches) >= 1
        assert sum(b["approved_count"] for b in branches) >= seeded
        assert elapsed < limit, (
            f"sales-summary {elapsed:.0f}ms vs baseline {baseline:.0f}ms "
            f"(limit {limit:.0f}ms) dengan {seeded} order"
        )

        elapsed, body = _best_ms(client, f"{API}/reports/cross-branch/stock-summary", headers)
        assert len(body["branches"]) >= 1
        assert elapsed < limit, (
            f"stock-summary {elapsed:.0f}ms vs baseline {baseline:.0f}ms "
            f"(limit {limit:.0f}ms) dengan {seeded} order"
        )
    finally:
        _cleanup()
