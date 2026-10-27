"""KPI per supplier — branch scoping untuk MANAGER.

Live DB. Semua row test pakai prefix TEST-SUP-PERF- / TEST-PROD-PERF- dan
dihapus di awal + akhir tiap test.

Yang dicek:
- MANAGER tanpa `branch` = semua cabang, target dijumlah per supplier
  (row terbaru per branch, lalu di-sum).
- MANAGER + `branch` = hanya cabang itu (target cabang tsb, tanpa sum).
- Role non-MANAGER tidak boleh minta cabang lain (403).
- Kode cabang tak dikenal → 400.
"""
import uuid

from fastapi.testclient import TestClient
from sqlalchemy import text

from app.core.security import create_access_token
from app.main import app
from app.models.database import engine

API = "/api/v1"
BJM = "BANJARMASIN"
BRB = "BARABAI"
SUP_BJM = "TEST-SUP-PERF-BJM"
SUP_BRB = "TEST-SUP-PERF-BRB"
SUP_SUM = "TEST-SUP-PERF-SUM"


def _cleanup():
    with engine.begin() as conn:
        conn.execute(
            text("DELETE FROM products WHERE id LIKE 'TEST-PROD-PERF-%'")
        )
        conn.execute(
            text(
                "DELETE FROM supplier_targets "
                "WHERE supplier_name LIKE 'TEST-SUP-PERF-%'"
            )
        )
        conn.execute(
            text("DELETE FROM users WHERE username LIKE 'TEST-USER-PERF-%'")
        )


def _make_user(role: str, branch: str | None) -> str:
    user_id = str(uuid.uuid4())
    with engine.begin() as conn:
        conn.execute(
            text(
                "INSERT INTO users (id, username, password_hash, role, branch, "
                "is_active, token_version) "
                "VALUES (:id, :u, 'test-hash', :r, :b, true, 0)"
            ),
            {
                "id": user_id,
                "u": f"TEST-USER-PERF-{role}-{user_id[:8]}",
                "r": role,
                "b": branch,
            },
        )
    return user_id


def _token(user_id: str, role: str, branch: str | None) -> dict:
    token = create_access_token(
        {
            "sub": user_id,
            "username": "t",
            "role": role,
            "branch": branch,
            "token_version": 0,
        }
    )
    return {"Authorization": f"Bearer {token}"}


def _seed_product(pid: str, branch: str, supplier: str):
    with engine.begin() as conn:
        conn.execute(
            text(
                "INSERT INTO products (id, branch, nama_barang, harga, "
                "stok_diterima, order_type, nama_supplier) "
                "VALUES (:id, :branch, :nama, 1000, 0, 'REGULER', :sup)"
            ),
            {"id": pid, "branch": branch, "nama": pid, "sup": supplier},
        )


def _seed_target(branch: str, supplier: str, period: str, value: int):
    with engine.begin() as conn:
        conn.execute(
            text(
                "INSERT INTO supplier_targets "
                "(id, branch, supplier_name, period, target_value) "
                "VALUES (:id, :branch, :sup, :period, :value)"
            ),
            {
                "id": str(uuid.uuid4()),
                "branch": branch,
                "sup": supplier,
                "period": period,
                "value": value,
            },
        )


def _seed():
    _cleanup()
    _seed_product("TEST-PROD-PERF-BJM", BJM, SUP_BJM)
    _seed_product("TEST-PROD-PERF-BRB", BRB, SUP_BRB)
    _seed_product("TEST-PROD-PERF-SUM-BJM", BJM, SUP_SUM)
    _seed_product("TEST-PROD-PERF-SUM-BRB", BRB, SUP_SUM)

    _seed_target(BJM, SUP_BJM, "2026-09", 1_000_000)
    _seed_target(BRB, SUP_BRB, "2026-09", 2_000_000)
    _seed_target(BJM, SUP_SUM, "2026-09", 1_000_000)
    _seed_target(BRB, SUP_SUM, "2026-09", 2_000_000)
    # Periode lebih baru di BJM → rollover per branch: 5jt + 2jt (BRB carry).
    _seed_target(BJM, SUP_SUM, "2026-10", 5_000_000)


def _rows(client: TestClient, headers: dict, year_month: str, branch: str | None = None):
    url = f"{API}/reports/supplier-performance?year_month={year_month}"
    if branch:
        url += f"&branch={branch}"
    resp = client.get(url, headers=headers)
    assert resp.status_code == 200, resp.text
    return {r["supplier_name"]: r for r in resp.json()}


def _run(fn):
    """Seed + MANAGER headers, cleanup di akhir (selalu, termasuk saat gagal)."""
    try:
        _seed()
        manager_id = _make_user("MANAGER", None)
        fn(TestClient(app), _token(manager_id, "MANAGER", None))
    finally:
        _cleanup()


def test_manager_all_branches_sums_latest_target_per_branch():
    def check(client, manager_headers):
        rows = _rows(client, manager_headers, "2026-09")
        assert rows[SUP_BJM]["target"] == 1_000_000
        assert rows[SUP_BRB]["target"] == 2_000_000
        # 1jt (BJM) + 2jt (BRB) — bukan salah satu cabang saja.
        assert rows[SUP_SUM]["target"] == 3_000_000
        assert rows[SUP_SUM]["has_target"] is True

    _run(check)


def test_manager_all_branches_rollover_then_sum():
    def check(client, manager_headers):
        rows = _rows(client, manager_headers, "2026-10")
        # BJM 5jt (2026-10) + BRB 2jt (carry 2026-09).
        assert rows[SUP_SUM]["target"] == 7_000_000
        # Supplier tanpa target baru tetap carry dari 2026-09.
        assert rows[SUP_BJM]["target"] == 1_000_000

    _run(check)


def test_manager_branch_filter_uses_that_branch_only():
    def check(client, manager_headers):
        rows = _rows(client, manager_headers, "2026-09", branch=BRB)
        assert SUP_BJM not in rows
        assert rows[SUP_BRB]["target"] == 2_000_000
        # Bukan sum lintas branch.
        assert rows[SUP_SUM]["target"] == 2_000_000

    _run(check)


def test_non_manager_cannot_request_other_branch():
    try:
        _seed()
        supervisor_id = _make_user("SUPERVISOR", BJM)
        resp = TestClient(app).get(
            f"{API}/reports/supplier-performance?year_month=2026-09&branch={BRB}",
            headers=_token(supervisor_id, "SUPERVISOR", BJM),
        )
        assert resp.status_code == 403, resp.text
    finally:
        _cleanup()


def test_manager_unknown_branch_rejected():
    try:
        _seed()
        manager_id = _make_user("MANAGER", None)
        resp = TestClient(app).get(
            f"{API}/reports/supplier-performance?year_month=2026-09&branch=NOPE",
            headers=_token(manager_id, "MANAGER", None),
        )
        assert resp.status_code == 400, resp.text
    finally:
        _cleanup()
