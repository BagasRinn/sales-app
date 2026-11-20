"""Test webhook absensi WhatsApp + endpoint baca.

Memakai database nyata seperti test endpoint lain di proyek ini; semua baris
uji memakai prefix ``TEST-WA-`` dan dibersihkan di akhir setiap tes.
"""
import uuid

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import text

from app.main import _ensure_sales_attendance, app
from app.models.database import engine
from app.models.models import Base
from app.core.security import create_access_token

USER_PREFIX = "TEST-WA-"
PHONE_PREFIX = "6299"
API_KEY = "test-internal-key-attendance"

# Pastikan tabel/kolom ada walau lifespan app tidak dijalankan (TestClient
# tanpa context manager tidak memicu startup event). Bila database tidak
# terjangkau (mis. tunnel lokal belum dibuka), lewati seluruh modul.
try:
    Base.metadata.create_all(bind=engine)
    _ensure_sales_attendance()
except Exception as exc:  # pragma: no cover - environment dependent
    pytest.skip(
        f"Database tidak tersedia untuk tes absensi: {exc}",
        allow_module_level=True,
    )


@pytest.fixture(autouse=True)
def _cleanup():
    _delete_test_rows()
    yield
    _delete_test_rows()


@pytest.fixture
def client(monkeypatch):
    monkeypatch.setenv("INTERNAL_API_KEY", API_KEY)
    return TestClient(app)


def _delete_test_rows():
    with engine.begin() as conn:
        conn.execute(text(
            "DELETE FROM sales_attendance WHERE sender_phone LIKE :p "
            "OR wa_message_id LIKE 'TEST-WA-MSG-%'"
        ), {"p": f"{PHONE_PREFIX}%"})
        conn.execute(text(
            "DELETE FROM users WHERE username LIKE :u"
        ), {"u": f"{USER_PREFIX}%"})


def _make_user(role: str, branch: str | None, phone: str | None = None) -> str:
    user_id = str(uuid.uuid4())
    with engine.begin() as conn:
        conn.execute(text(
            "INSERT INTO users (id, username, password_hash, role, branch, "
            "whatsapp_number, is_active, token_version) "
            "VALUES (:id, :u, 'test-hash', :r, :b, :p, true, 0)"
        ), {
            "id": user_id,
            "u": f"{USER_PREFIX}{role}-{user_id[:8]}",
            "r": role,
            "b": branch,
            "p": phone,
        })
    return user_id


def _token(user_id: str, role: str, branch: str | None) -> str:
    return create_access_token({
        "sub": user_id,
        "username": "tester",
        "role": role,
        "branch": branch,
        "token_version": 0,
    })


def _payload(phone: str, message_id: str, **overrides) -> dict:
    data = {
        "sender_phone": phone,
        "sender_push_name": "Budi WA",
        "outlet_code": " out-042 ",
        "outlet_name": " Toko Berkah Jaya ",
        "outlet_channel": " gt ",
        "has_photo_proof": True,
        "wa_group_id": "120363000000000000@g.us",
        "wa_message_id": message_id,
        "message_timestamp": 1_700_000_000,
        "raw_message": "OUT-042#Toko Berkah Jaya#GT",
    }
    data.update(overrides)
    return data


def _post(client, payload, key=API_KEY):
    return client.post(
        "/api/v1/webhooks/wa-attendance",
        json=payload,
        headers={"X-Internal-API-Key": key},
    )


def test_webhook_without_configured_key_is_closed(monkeypatch):
    monkeypatch.delenv("INTERNAL_API_KEY", raising=False)
    resp = TestClient(app).post(
        "/api/v1/webhooks/wa-attendance", json=_payload("629900000001", "TEST-WA-MSG-x")
    )
    assert resp.status_code == 503


def test_webhook_rejects_wrong_key(client):
    resp = _post(client, _payload("629900000001", "TEST-WA-MSG-wrong"), key="nope")
    assert resp.status_code == 401


def test_webhook_matches_registered_sales(client):
    sales_id = _make_user("SALES", "BANJARMASIN", "629900000002")

    resp = _post(client, _payload("0812 0000 0002", "TEST-WA-MSG-1"))

    assert resp.status_code == 201, resp.text
    body = resp.json()
    assert body["is_registered_sales"] is True
    assert body["sales_id"] == sales_id

    with engine.begin() as conn:
        row = conn.execute(text(
            "SELECT sales_name, sender_phone, outlet_code, outlet_name, "
            "outlet_channel, has_photo_proof, visited_at "
            "FROM sales_attendance WHERE wa_message_id = 'TEST-WA-MSG-1'"
        )).one()
    assert row.sales_name.startswith(USER_PREFIX)
    assert row.sender_phone == "6281200000002"
    assert row.outlet_code == "OUT-042"      # trimmed + uppercase
    assert row.outlet_name == "Toko Berkah Jaya"
    assert row.outlet_channel == "gt"
    assert row.has_photo_proof is True
    assert row.visited_at is not None


def test_webhook_ignores_non_sales_role_and_falls_back_to_push_name(client):
    _make_user("SUPERVISOR", "BANJARMASIN", "629900000003")

    resp = _post(
        client,
        _payload("629900000003", "TEST-WA-MSG-2", sender_push_name="Pak Sup"),
    )

    assert resp.status_code == 201, resp.text
    body = resp.json()
    assert body["is_registered_sales"] is False
    assert body["sales_id"] is None

    with engine.begin() as conn:
        row = conn.execute(text(
            "SELECT sales_name, is_registered_sales FROM sales_attendance "
            "WHERE wa_message_id = 'TEST-WA-MSG-2'"
        )).one()
    assert row.sales_name == "Pak Sup"
    assert row.is_registered_sales is False


def test_webhook_is_idempotent_on_same_message_id(client):
    first = _post(client, _payload("629900000004", "TEST-WA-MSG-3"))
    assert first.status_code == 201

    second = _post(client, _payload("629900000004", "TEST-WA-MSG-3"))
    assert second.status_code == 200
    body = second.json()
    assert body["duplicate"] is True
    assert body["attendance_id"] == first.json()["attendance_id"]

    with engine.begin() as conn:
        count = conn.execute(text(
            "SELECT COUNT(*) FROM sales_attendance "
            "WHERE wa_message_id = 'TEST-WA-MSG-3'"
        )).scalar_one()
    assert count == 1


def test_list_attendance_is_branch_scoped(client):
    branch_sales = _make_user("SALES", "BANJARMASIN", "629900000005")
    other_sales = _make_user("SALES", "BANDUNG", "629900000006")
    _post(client, _payload("629900000005", "TEST-WA-MSG-4"))
    _post(client, _payload("629900000006", "TEST-WA-MSG-5"))
    _post(client, _payload("629900000099", "TEST-WA-MSG-6"))  # unregistered

    mgr_id = _make_user("MANAGER", None)
    sup_id = _make_user("SUPERVISOR", "BANJARMASIN")

    all_resp = client.get(
        "/api/v1/sales-attendances",
        headers={"Authorization": f"Bearer {_token(mgr_id, 'MANAGER', None)}"},
    )
    assert all_resp.status_code == 200
    assert len(all_resp.json()) == 3

    scoped = client.get(
        "/api/v1/sales-attendances",
        headers={"Authorization": f"Bearer {_token(sup_id, 'SUPERVISOR', 'BANJARMASIN')}"},
    )
    assert scoped.status_code == 200
    rows = scoped.json()
    assert len(rows) == 1
    assert rows[0]["sales_id"] == branch_sales
    assert rows[0]["sales_id"] != other_sales


def test_create_user_normalizes_whatsapp_number_and_rejects_duplicate(client):
    mgr_id = _make_user("MANAGER", None)
    headers = {"Authorization": f"Bearer {_token(mgr_id, 'MANAGER', None)}"}

    created = client.post(
        "/api/v1/users",
        json={
            "username": f"{USER_PREFIX}created",
            "password": "rahasia123",
            "role": "SALES",
            "branch": "BANJARMASIN",
            "whatsapp_number": "0812-3456-9999",
        },
        headers=headers,
    )
    assert created.status_code == 201, created.text
    assert created.json()["whatsapp_number"] == "6281234569999"

    duplicate = client.post(
        "/api/v1/users",
        json={
            "username": f"{USER_PREFIX}duplicate",
            "password": "rahasia123",
            "role": "SALES",
            "branch": "BANJARMASIN",
            "whatsapp_number": "+62 812 3456 9999",
        },
        headers=headers,
    )
    assert duplicate.status_code == 409


def test_update_user_can_clear_whatsapp_number(client):
    mgr_id = _make_user("MANAGER", None)
    target_id = _make_user("SALES", "BANJARMASIN", "629900000007")
    headers = {"Authorization": f"Bearer {_token(mgr_id, 'MANAGER', None)}"}

    resp = client.put(
        f"/api/v1/users/{target_id}",
        json={"whatsapp_number": None},
        headers=headers,
    )
    assert resp.status_code == 200, resp.text
    assert resp.json()["whatsapp_number"] is None
