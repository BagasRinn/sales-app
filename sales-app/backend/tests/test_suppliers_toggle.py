import uuid
from sqlalchemy import text
from fastapi.testclient import TestClient
from app.main import app
from app.models.database import engine
from app.core.security import create_access_token

TEST_SUP = "TEST-SUP-TOGGLE"
USER_BRANCH = "BANJARMASIN"


def _cleanup_suppliers():
    with engine.begin() as conn:
        conn.execute(text("DELETE FROM suppliers WHERE name LIKE 'TEST-SUP-TOGGLE%'"))


def _cleanup_users():
    with engine.begin() as conn:
        conn.execute(text("DELETE FROM users WHERE username LIKE 'TEST-USER-TOGGLE-%'"))


def _cleanup():
    _cleanup_suppliers()
    _cleanup_users()


def _make_user(role: str, branch: str | None) -> str:
    user_id = str(uuid.uuid4())
    with engine.begin() as conn:
        conn.execute(text(
            "INSERT INTO users (id, username, password_hash, role, branch, is_active, token_version) "
            "VALUES (:id, :u, 'test-hash', :r, :b, true, 0)"
        ), {"id": user_id, "u": f"TEST-USER-TOGGLE-{role}-{user_id[:8]}", "r": role, "b": branch})
    return user_id


def _token(user_id: str, role: str, branch: str | None) -> str:
    return create_access_token({
        "sub": user_id, "username": "t", "role": role,
        "branch": branch, "token_version": 0,
    })


def test_patch_active_as_manager_toggles():
    _cleanup()
    mgr_id = _make_user("MANAGER", None)
    try:
        client = TestClient(app)
        mgr_token = _token(mgr_id, "MANAGER", None)
        # Seed as active
        seed = client.post(
            "/api/v1/suppliers",
            json={"name": TEST_SUP},
            headers={"Authorization": f"Bearer {mgr_token}"},
        )
        assert seed.status_code == 201
        # Toggle to inactive
        resp = client.patch(
            f"/api/v1/suppliers/{TEST_SUP}/active",
            json={"is_active": False},
            headers={"Authorization": f"Bearer {mgr_token}"},
        )
        assert resp.status_code == 200
        assert resp.json()["is_active"] is False
        # Toggle back
        resp2 = client.patch(
            f"/api/v1/suppliers/{TEST_SUP}/active",
            json={"is_active": True},
            headers={"Authorization": f"Bearer {mgr_token}"},
        )
        assert resp2.status_code == 200
        assert resp2.json()["is_active"] is True
    finally:
        _cleanup()


def test_patch_active_rejects_admin():
    _cleanup()
    mgr_id = _make_user("MANAGER", None)
    admin_id = _make_user("ADMIN", USER_BRANCH)
    try:
        client = TestClient(app)
        mgr_token = _token(mgr_id, "MANAGER", None)
        admin_token = _token(admin_id, "ADMIN", USER_BRANCH)
        # Seed
        client.post(
            "/api/v1/suppliers",
            json={"name": TEST_SUP},
            headers={"Authorization": f"Bearer {mgr_token}"},
        )
        resp = client.patch(
            f"/api/v1/suppliers/{TEST_SUP}/active",
            json={"is_active": False},
            headers={"Authorization": f"Bearer {admin_token}"},
        )
        assert resp.status_code == 403, f"ADMIN should be rejected, got {resp.status_code}"
    finally:
        _cleanup()


def test_patch_active_404_for_missing():
    mgr_id = _make_user("MANAGER", None)
    try:
        client = TestClient(app)
        mgr_token = _token(mgr_id, "MANAGER", None)
        resp = client.patch(
            "/api/v1/suppliers/TEST-SUP-DOES-NOT-EXIST-XYZ/active",
            json={"is_active": False},
            headers={"Authorization": f"Bearer {mgr_token}"},
        )
        assert resp.status_code == 404
    finally:
        _cleanup()
