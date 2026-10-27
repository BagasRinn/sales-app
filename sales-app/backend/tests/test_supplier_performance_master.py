"""KPI per supplier — sumber daftar (master suppliers) + guard nama target.

Live DB. Row test pakai prefix TEST-SUP-PMIX- / TEST-PROD-PMIX- dan dihapus
di awal + akhir tiap test.

Yang dicek:
- Supplier master baru (tanpa produk, tanpa target) tetap muncul di KPI.
- Supplier non-aktif tetap muncul tapi ditandai is_active=false.
- Supplier lama yang cuma ada di products (tanpa master) → is_master=false.
- Nama supplier dengan spasi tetap match target (di-trim saat baca).
- PUT target untuk nama asing → 404.
- SUPERVISOR & MANAGER boleh PUT; ADMIN (read-only) → 403.
"""
import uuid
from urllib.parse import quote

from fastapi.testclient import TestClient
from sqlalchemy import text

from app.core.security import create_access_token
from app.main import app
from app.models.database import engine

API = "/api/v1"
BJM = "BANJARMASIN"
PERIOD = "2026-01"

SUP_MASTER = "TEST-SUP-PMIX-MASTER"
SUP_NEW = "TEST-SUP-PMIX-NEW"
SUP_INACTIVE = "TEST-SUP-PMIX-INACTIVE"
SUP_LEGACY = "TEST-SUP-PMIX-LEGACY"
SUP_SPACE = "TEST-SUP-PMIX-SPACE"


def _cleanup():
    with engine.begin() as conn:
        conn.execute(
            text("DELETE FROM products WHERE id LIKE 'TEST-PROD-PMIX-%'")
        )
        conn.execute(
            text(
                "DELETE FROM supplier_targets "
                "WHERE supplier_name LIKE '%TEST-SUP-PMIX-%'"
            )
        )
        conn.execute(
            text("DELETE FROM suppliers WHERE name LIKE 'TEST-SUP-PMIX-%'")
        )
        conn.execute(
            text("DELETE FROM users WHERE username LIKE 'TEST-USER-PMIX-%'")
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
                "u": f"TEST-USER-PMIX-{role}-{user_id[:8]}",
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


def _seed_product(pid: str, supplier: str):
    with engine.begin() as conn:
        conn.execute(
            text(
                "INSERT INTO products (id, branch, nama_barang, harga, "
                "stok_diterima, order_type, nama_supplier) "
                "VALUES (:id, :branch, :nama, 1000, 0, 'REGULER', :sup)"
            ),
            {"id": pid, "branch": BJM, "nama": pid, "sup": supplier},
        )


def _seed():
    _cleanup()
    with engine.begin() as conn:
        conn.execute(
            text(
                "INSERT INTO suppliers (name, is_active, order_type) "
                "VALUES (:n, :a, :ot)"
            ),
            [
                {"n": SUP_MASTER, "a": True, "ot": "4P"},
                {"n": SUP_NEW, "a": True, "ot": "REGULER"},
                {"n": SUP_INACTIVE, "a": False, "ot": "REGULER"},
                {"n": SUP_SPACE, "a": True, "ot": "REGULER"},
            ],
        )
        conn.execute(
            text(
                "INSERT INTO supplier_targets "
                "(id, branch, supplier_name, period, target_value) "
                "VALUES (:id, :branch, :sup, :period, :value)"
            ),
            {
                "id": str(uuid.uuid4()),
                "branch": BJM,
                "sup": f" {SUP_SPACE} ",
                "period": PERIOD,
                "value": 900_000,
            },
        )
    _seed_product("TEST-PROD-PMIX-MASTER", SUP_MASTER)
    _seed_product("TEST-PROD-PMIX-INACTIVE", SUP_INACTIVE)
    _seed_product("TEST-PROD-PMIX-LEGACY", SUP_LEGACY)
    _seed_product("TEST-PROD-PMIX-SPACE", SUP_SPACE)


def _rows(client: TestClient, headers: dict) -> dict:
    resp = client.get(
        f"{API}/reports/supplier-performance?year_month={PERIOD}&branch={BJM}",
        headers=headers,
    )
    assert resp.status_code == 200, resp.text
    return {r["supplier_name"]: r for r in resp.json()}


def _put(client: TestClient, headers: dict, supplier: str, value: int):
    return client.put(
        f"{API}/supplier-targets/{BJM}/{quote(supplier, safe='')}/{PERIOD}",
        json={"target_value": value},
        headers=headers,
    )


def _run(fn):
    try:
        _seed()
        manager_id = _make_user("MANAGER", None)
        fn(TestClient(app), _token(manager_id, "MANAGER", None))
    finally:
        _cleanup()


def test_master_supplier_without_products_still_listed():
    def check(client, headers):
        rows = _rows(client, headers)
        assert SUP_NEW in rows
        row = rows[SUP_NEW]
        assert row["is_master"] is True
        assert row["is_active"] is True
        assert row["has_target"] is False
        assert row["value"] == 0

    _run(check)


def test_inactive_and_legacy_suppliers_flagged():
    def check(client, headers):
        rows = _rows(client, headers)
        assert rows[SUP_INACTIVE]["is_active"] is False
        assert rows[SUP_INACTIVE]["is_master"] is True
        assert rows[SUP_LEGACY]["is_master"] is False
        assert rows[SUP_LEGACY]["is_active"] is True
        assert rows[SUP_MASTER]["order_type"] == "4P"

    _run(check)


def test_target_with_spaces_still_matches_supplier():
    def check(client, headers):
        rows = _rows(client, headers)
        assert rows[SUP_SPACE]["has_target"] is True
        assert rows[SUP_SPACE]["target"] == 900_000

    _run(check)


def test_put_target_unknown_supplier_rejected():
    def check(client, headers):
        resp = _put(client, headers, "TEST-SUP-PMIX-NOPE", 1000)
        assert resp.status_code == 404, resp.text

    _run(check)


def test_put_target_allowed_for_supervisor_and_manager_but_not_admin():
    try:
        _seed()
        client = TestClient(app)
        supervisor_id = _make_user("SUPERVISOR", BJM)
        resp = _put(
            client, _token(supervisor_id, "SUPERVISOR", BJM), SUP_NEW, 5000
        )
        assert resp.status_code == 200, resp.text
        assert resp.json()["supplier_name"] == SUP_NEW

        manager_id = _make_user("MANAGER", None)
        resp = _put(
            client, _token(manager_id, "MANAGER", None), SUP_NEW, 6000
        )
        assert resp.status_code == 200, resp.text
        assert resp.json()["target_value"] == 6000

        admin_id = _make_user("ADMIN", BJM)
        resp = _put(client, _token(admin_id, "ADMIN", BJM), SUP_NEW, 7000)
        assert resp.status_code == 403, resp.text
    finally:
        _cleanup()
