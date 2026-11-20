"""Test proxy kontrol sesi WhatsApp (tanpa worker/DB sungguhan)."""
from datetime import datetime, timezone

import pytest
from fastapi import HTTPException
from fastapi.testclient import TestClient

from app.api.endpoints import wa_session
from app.core.security import require_manager_global
from app.main import app


class _FakeResponse:
    def __init__(self, status_code=200, data=None):
        self.status_code = status_code
        self._data = {} if data is None else data

    def json(self):
        return self._data


@pytest.fixture
def client(monkeypatch):
    monkeypatch.setenv("WA_WORKER_URL", "http://wa-worker:3000")
    monkeypatch.setenv("INTERNAL_API_KEY", "test-internal-key")
    app.dependency_overrides[require_manager_global] = lambda: {
        "role": "MANAGER",
        "branch": None,
    }
    yield TestClient(app)
    app.dependency_overrides.pop(require_manager_global, None)


def test_get_session_returns_worker_state(client, monkeypatch):
    calls = []

    def fake_request(method, path):
        calls.append((method, path))
        return _FakeResponse(
            200,
            {
                "status": "waiting_qr",
                "connected": False,
                "qr": "2@abcdef",
                "phone": None,
                "name": None,
                "updated_at": "2026-01-02T03:04:05Z",
            },
        )

    monkeypatch.setattr(wa_session, "_worker_request", fake_request)

    response = client.get("/api/v1/wa/session")

    assert response.status_code == 200, response.text
    body = response.json()
    assert body["status"] == "waiting_qr"
    assert body["qr"] == "2@abcdef"
    assert body["connected"] is False
    assert datetime.fromisoformat(
        body["updated_at"].replace("Z", "+00:00")
    ) == datetime(2026, 1, 2, 3, 4, 5, tzinfo=timezone.utc)
    assert calls == [("GET", "/status")]


def test_logout_requests_new_qr(client, monkeypatch):
    calls = []

    def fake_request(method, path):
        calls.append((method, path))
        return _FakeResponse(202, {"status": "logging_out"})

    monkeypatch.setattr(wa_session, "_worker_request", fake_request)

    response = client.post("/api/v1/wa/session/logout")

    assert response.status_code == 202, response.text
    body = response.json()
    assert body["status"] == "logging_out"
    assert body["connected"] is False
    assert "QR baru" in body["message"]
    assert calls == [("POST", "/logout")]


def test_missing_worker_url_returns_503(client, monkeypatch):
    monkeypatch.delenv("WA_WORKER_URL", raising=False)

    response = client.get("/api/v1/wa/session")

    assert response.status_code == 503
    assert "WA_WORKER_URL" in response.json()["detail"]


def test_unreachable_worker_returns_503(client, monkeypatch):
    def fake_request(method, path):
        raise HTTPException(
            status_code=503, detail="Worker WhatsApp tidak bisa dihubungi."
        )

    monkeypatch.setattr(wa_session, "_worker_request", fake_request)

    response = client.get("/api/v1/wa/session")

    assert response.status_code == 503
    assert "tidak bisa dihubungi" in response.json()["detail"]
