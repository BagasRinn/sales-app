"""Test untuk ?detail=true param di /reports/daily dan /reports/period.

Verifikasi backward compat:
- Default (no param) → return JSON summary, BUKAN XLSX binary
- ?detail=true → return XLSX binary seperti sebelumnya
- Caller lama yang pakai XLSX harus update pakai ?detail=true
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
TEST_DATE = "2020-01-16"


def _cleanup():
    with engine.begin() as conn:
        conn.execute(text(
            "DELETE FROM order_items WHERE order_id IN "
            "(SELECT id FROM orders WHERE notes LIKE 'TEST-DET-%')"
        ))
        conn.execute(text("DELETE FROM orders WHERE notes LIKE 'TEST-DET-%'"))


def _seed_user(role: str, branch: str | None) -> str:
    user_id = str(uuid.uuid4())
    with engine.begin() as conn:
        conn.execute(text(
            "INSERT INTO users (id, username, password_hash, role, branch, is_active) "
            "VALUES (:id, :u, 'test-hash', :r, :b, true)"
        ), {"id": user_id, "u": f"TEST-DET-USER-{user_id[:8]}", "r": role, "b": branch})
    return user_id


def _seed_one_order(sales_id: str) -> str:
    """Insert 1 order di TEST_DATE supaya endpoint return data non-empty."""
    oid = str(uuid.uuid4())
    test_dt = datetime(2020, 1, 16, 10, 0, 0, tzinfo=WITA).astimezone(timezone.utc)
    with engine.begin() as conn:
        conn.execute(text(
            "INSERT INTO orders (id, branch, sales_id, status, notes, created_at) "
            "VALUES (:id, :branch, :sid, 'APPROVED', 'TEST-DET-seed', :ts)"
        ), {"id": oid, "branch": USER_BRANCH, "sid": sales_id, "ts": test_dt})
    return oid


def _token(user_id: str, role: str, branch: str | None) -> str:
    return create_access_token({
        "sub": user_id, "username": "t", "role": role,
        "branch": branch, "token_version": 0,
    })


def test_daily_default_returns_summary_json():
    """Tanpa ?detail, /daily return JSON (summary), Content-Type bukan XLSX."""
    _cleanup()
    user_id = _seed_user("MANAGER", None)
    sales_id = _seed_user("SALES", USER_BRANCH)
    _seed_one_order(sales_id)
    try:
        client = TestClient(app)
        token = _token(user_id, "MANAGER", None)
        resp = client.get(
            f"/api/v1/reports/daily?date={TEST_DATE}",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 200, resp.text
        ct = resp.headers.get("content-type", "")
        assert "spreadsheet" not in ct.lower(), f"expected JSON, got XLSX: {ct}"
        body = resp.json()
        # Summary shape: ada total_orders, by_status, dll
        assert "total_orders" in body
        assert "by_status" in body
        assert "by_branch" in body
    finally:
        _cleanup()


def test_daily_with_detail_returns_xlsx():
    """Dengan ?detail=true, /daily return XLSX seperti behavior lama."""
    _cleanup()
    user_id = _seed_user("MANAGER", None)
    sales_id = _seed_user("SALES", USER_BRANCH)
    _seed_one_order(sales_id)
    try:
        client = TestClient(app)
        token = _token(user_id, "MANAGER", None)
        resp = client.get(
            f"/api/v1/reports/daily?date={TEST_DATE}&detail=true",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 200, resp.text
        ct = resp.headers.get("content-type", "").lower()
        assert "spreadsheet" in ct, f"expected XLSX, got: {ct}"
        # XLSX file starts with PK (zip magic bytes)
        assert resp.content[:2] == b"PK", "expected XLSX (zip) magic bytes"
    finally:
        _cleanup()


def test_period_default_returns_summary_json():
    _cleanup()
    user_id = _seed_user("MANAGER", None)
    try:
        client = TestClient(app)
        token = _token(user_id, "MANAGER", None)
        resp = client.get(
            f"/api/v1/reports/period?start_date={TEST_DATE}&end_date={TEST_DATE}",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 200
        ct = resp.headers.get("content-type", "").lower()
        assert "spreadsheet" not in ct
        body = resp.json()
        assert "total_orders" in body
    finally:
        _cleanup()


def test_period_with_detail_returns_xlsx():
    _cleanup()
    user_id = _seed_user("MANAGER", None)
    try:
        client = TestClient(app)
        token = _token(user_id, "MANAGER", None)
        resp = client.get(
            f"/api/v1/reports/period?start_date={TEST_DATE}&end_date={TEST_DATE}&detail=true",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 200
        ct = resp.headers.get("content-type", "").lower()
        assert "spreadsheet" in ct
        assert resp.content[:2] == b"PK"
    finally:
        _cleanup()
