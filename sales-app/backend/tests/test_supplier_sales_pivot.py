"""API coverage for the imported-sales supplier pivot."""
import uuid

from fastapi.testclient import TestClient
from sqlalchemy import text

from app.core.security import create_access_token
from app.main import app
from app.models.database import engine

API = "/api/v1"
PREFIX = "TEST-SSP-"
DATE_FROM = "2099-01-01"
DATE_TO = "2099-01-31"


def _token(role: str, branch: str | None) -> dict:
    user_id = str(uuid.uuid4())
    with engine.begin() as conn:
        conn.execute(
            text(
                "INSERT INTO users (id, username, password_hash, role, branch, "
                "is_active, token_version) VALUES (:id, :u, 'test', :r, :b, true, 0)"
            ),
            {"id": user_id, "u": f"{PREFIX}{user_id[:8]}", "r": role, "b": branch},
        )
    token = create_access_token(
        {"sub": user_id, "username": "test", "role": role, "branch": branch, "token_version": 0}
    )
    return {"Authorization": f"Bearer {token}"}


def _seed():
    _cleanup()
    log_ids = [str(uuid.uuid4()), str(uuid.uuid4())]
    with engine.begin() as conn:
        for log_id in log_ids:
            conn.execute(
                text("INSERT INTO import_logs (id, import_type, file_name) VALUES (:id, 'SALES', :name)"),
                {"id": log_id, "name": f"{PREFIX}{log_id}"},
            )
        rows = [
            ("BANJARMASIN", log_ids[0], f"  {PREFIX}Supplier A  ", "Mix", f"{PREFIX}Ayu", 1000, 100, 2, DATE_FROM),
            ("BANJARMASIN", log_ids[0], f"{PREFIX}Supplier A", "Mix", f"{PREFIX}Budi", 500, 50, 1, "2099-01-15"),
            ("BANJARMASIN", log_ids[0], None, None, None, 300, -10, 3, "2099-01-20"),
            ("BANJARBARU", log_ids[1], f"{PREFIX}Supplier A", "Mix", f"{PREFIX}Ayu", 9000, 900, 9, "2099-01-10"),
            ("BANJARMASIN", log_ids[0], f"{PREFIX}Supplier A", "Mix", f"{PREFIX}Ayu", 9999, 999, 9, "2098-12-31"),
        ]
        for branch, log_id, supplier, divisi, sales, value, margin, qty, day in rows:
            conn.execute(
                text(
                    "INSERT INTO imported_sales "
                    "(id, import_log_id, branch, sale_date, supplier, divisi, sales_nama, total_amount, margin, qty) "
                    "VALUES (:id, :log, :branch, :day, :supplier, :divisi, :sales, :value, :margin, :qty)"
                ),
                {"id": str(uuid.uuid4()), "log": log_id, "branch": branch, "day": day,
                 "supplier": supplier, "divisi": divisi, "sales": sales, "value": value,
                 "margin": margin, "qty": qty},
            )


def _cleanup():
    with engine.begin() as conn:
        conn.execute(text("DELETE FROM imported_returns WHERE import_log_id IN (SELECT id FROM import_logs WHERE file_name LIKE 'TEST-SSP-%')"))
        conn.execute(text("DELETE FROM imported_sales WHERE import_log_id IN (SELECT id FROM import_logs WHERE file_name LIKE 'TEST-SSP-%')"))
        conn.execute(text("DELETE FROM import_logs WHERE file_name LIKE 'TEST-SSP-%'"))
        conn.execute(text("DELETE FROM users WHERE username LIKE 'TEST-SSP-%'"))


def test_pivot_aggregates_metrics_normalizes_names_and_filters_scope():
    _seed()
    headers = _token("MANAGER", None)
    try:
        response = TestClient(app).get(
            f"{API}/reports/supplier-sales-pivot?from={DATE_FROM}&to={DATE_TO}&branch=BANJARMASIN",
            headers=headers,
        )
        assert response.status_code == 200, response.text
        data = response.json()
        assert data["total"] == {"value": 1800, "margin": 140, "qty": 6}
        assert [col["nama"] for col in data["columns"]] == [f"{PREFIX}Ayu", f"{PREFIX}Budi", "-"]
        supplier_a = next(row for row in data["rows"] if row["supplier"] == f"{PREFIX}Supplier A")
        assert supplier_a["cells"][f"{PREFIX}Ayu"] == {"value": 1000, "margin": 100, "qty": 2}
        assert supplier_a["total"] == {"value": 1500, "margin": 150, "qty": 3}
        assert any(row["supplier"] == "-" and row["channel"] == "-" for row in data["rows"])
    finally:
        _cleanup()


def test_supervisor_cannot_request_other_branch():
    _seed()
    headers = _token("SUPERVISOR", "BANJARMASIN")
    try:
        response = TestClient(app).get(
            f"{API}/reports/supplier-sales-pivot?from={DATE_FROM}&to={DATE_TO}&branch=BANJARBARU",
            headers=headers,
        )
        assert response.status_code == 403
    finally:
        _cleanup()


def _seed_sale_and_return():
    """Satu penjualan + satu retur pada supplier/divisi/sales yang sama."""
    _cleanup()
    log_id = str(uuid.uuid4())
    with engine.begin() as conn:
        conn.execute(
            text("INSERT INTO import_logs (id, import_type, file_name) VALUES (:id, 'SALES', :name)"),
            {"id": log_id, "name": f"{PREFIX}{log_id}"},
        )
        conn.execute(
            text(
                "INSERT INTO imported_sales "
                "(id, import_log_id, branch, sale_date, supplier, divisi, sales_nama, total_amount, margin, qty) "
                "VALUES (:id, :log, 'BANJARMASIN', :day, :supplier, 'Mix', :sales, 1000, 100, 2)"
            ),
            {"id": str(uuid.uuid4()), "log": log_id, "day": DATE_FROM,
             "supplier": f"{PREFIX}Supplier A", "sales": f"{PREFIX}Ayu"},
        )
        conn.execute(
            text(
                "INSERT INTO imported_returns "
                "(id, import_log_id, branch, sale_date, supplier, divisi, sales_nama, revenue, margin) "
                "VALUES (:id, :log, 'BANJARMASIN', :day, :supplier, 'Mix', :sales, 300, 30)"
            ),
            {"id": str(uuid.uuid4()), "log": log_id, "day": DATE_FROM,
             "supplier": f"{PREFIX}Supplier A", "sales": f"{PREFIX}Ayu"},
        )


def test_pivot_nets_returns_like_dashboard():
    """Omzet pivot harus neto (penjualan − retur), sama dengan Dashboard."""
    _seed_sale_and_return()
    headers = _token("MANAGER", None)
    try:
        response = TestClient(app).get(
            f"{API}/reports/supplier-sales-pivot?from={DATE_FROM}&to={DATE_TO}&branch=BANJARMASIN",
            headers=headers,
        )
        assert response.status_code == 200, response.text
        data = response.json()
        assert data["total"] == {"value": 700, "margin": 70, "qty": 2}
        supplier_a = next(row for row in data["rows"] if row["supplier"] == f"{PREFIX}Supplier A")
        assert supplier_a["cells"][f"{PREFIX}Ayu"] == {"value": 700, "margin": 70, "qty": 2}
        assert supplier_a["total"] == {"value": 700, "margin": 70, "qty": 2}
    finally:
        _cleanup()
