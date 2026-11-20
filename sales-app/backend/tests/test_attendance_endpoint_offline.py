"""Test endpoint webhook tanpa database (fake session).

Database integration penuh ada di ``test_attendance_webhook.py``; file ini
memastikan alur HTTP tetap benar walau DB tidak tersedia saat menjalankan tes.
"""
import uuid
from datetime import datetime, timezone
from types import SimpleNamespace

import pytest
from fastapi.testclient import TestClient

from app.api.endpoints import attendance as attendance_module
from app.main import app
from app.models.database import get_db

API_KEY = "offline-internal-key"


class _FakeQuery:
    def __init__(self, db):
        self._db = db

    def filter(self, *args, **kwargs):
        return self

    def order_by(self, *args, **kwargs):
        return self

    def offset(self, *args, **kwargs):
        return self

    def limit(self, *args, **kwargs):
        return self

    def first(self):
        return self._db.existing_attendance

    def all(self):
        return []


class FakeDB:
    def __init__(self, existing_attendance=None):
        self.existing_attendance = existing_attendance
        self.added = []

    def query(self, _model):
        return _FakeQuery(self)

    def add(self, obj):
        self.added.append(obj)

    def commit(self):
        pass

    def rollback(self):
        pass

    def refresh(self, _obj):
        pass


@pytest.fixture
def client(monkeypatch):
    monkeypatch.setenv("INTERNAL_API_KEY", API_KEY)
    yield TestClient(app)
    app.dependency_overrides.pop(get_db, None)


def _use_db(fake_db):
    app.dependency_overrides[get_db] = lambda: fake_db


def _payload(**overrides):
    data = {
        "sender_phone": "0812-0000-1234",
        "sender_push_name": "Budi WA",
        "outlet_code": " out-01 ",
        "outlet_name": " Toko A ",
        "outlet_channel": " gt ",
        "has_photo_proof": True,
        "wa_group_id": "120363000000000000@g.us",
        "wa_message_id": "OFFLINE-MSG-1",
        "message_timestamp": "2026-01-02T03:04:05+08:00",
        "raw_message": "OUT-01#Toko A#GT",
    }
    data.update(overrides)
    return data


def _post(client, payload, key=API_KEY):
    return client.post(
        "/api/v1/webhooks/wa-attendance",
        json=payload,
        headers={"X-Internal-API-Key": key},
    )


def test_webhook_stores_registered_sales(client, monkeypatch):
    sales_id = uuid.uuid4()
    fake_db = FakeDB()
    _use_db(fake_db)
    monkeypatch.setattr(
        attendance_module,
        "_resolve_sales",
        lambda db, phone: SimpleNamespace(
            id=sales_id, nama="Budi Santoso", username="budi"
        ),
    )

    resp = _post(client, _payload())

    assert resp.status_code == 201, resp.text
    body = resp.json()
    assert body["is_registered_sales"] is True
    assert body["sales_id"] == str(sales_id)

    assert len(fake_db.added) == 1
    row = fake_db.added[0]
    assert row.sales_name == "Budi Santoso"
    assert row.sender_phone == "6281200001234"
    assert row.outlet_code == "OUT-01"
    assert row.outlet_channel == "gt"
    assert row.visited_at == datetime(2026, 1, 1, 19, 4, 5, tzinfo=timezone.utc)


def test_webhook_falls_back_to_push_name(client, monkeypatch):
    fake_db = FakeDB()
    _use_db(fake_db)
    monkeypatch.setattr(
        attendance_module, "_resolve_sales", lambda db, phone: None
    )

    resp = _post(client, _payload(sender_push_name="Pak Sup"))

    assert resp.status_code == 201
    assert resp.json()["is_registered_sales"] is False
    assert fake_db.added[0].sales_name == "Pak Sup"


def test_webhook_duplicate_message_is_ignored(client):
    existing_id = uuid.uuid4()
    fake_db = FakeDB(
        existing_attendance=SimpleNamespace(
            id=existing_id,
            is_registered_sales=False,
            sales_id=None,
        )
    )
    _use_db(fake_db)

    resp = _post(client, _payload())

    assert resp.status_code == 200
    body = resp.json()
    assert body["duplicate"] is True
    assert body["attendance_id"] == str(existing_id)
    assert fake_db.added == []
