import uuid
from sqlalchemy import text
from fastapi.testclient import TestClient
from app.main import app
from app.models.database import engine
from app.core.security import create_access_token

TEST_SUP = "TEST-SUP-CREATE"
USER_BRANCH = "BANJARMASIN"  # real branch for FK to users.branch


def _cleanup_suppliers():
    with engine.begin() as conn:
        conn.execute(text("DELETE FROM suppliers WHERE name LIKE 'TEST-SUP-CREATE%'"))


def _cleanup_users():
    with engine.begin() as conn:
        conn.execute(text("DELETE FROM users WHERE username LIKE 'TEST-USER-CREATE-%'"))


def _cleanup():
    _cleanup_suppliers()
    _cleanup_users()


def _make_user(role: str, branch: str | None) -> str:
    user_id = str(uuid.uuid4())
    with engine.begin() as conn:
        conn.execute(text(
            # token_version & is_active pakai nilai kolom karena column default
            # SQLAlchemy hanya jalan lewat ORM, bukan raw SQL.
            "INSERT INTO users (id, username, password_hash, role, branch, is_active, token_version) "
            "VALUES (:id, :u, 'test-hash', :r, :b, true, 0)"
        ), {"id": user_id, "u": f"TEST-USER-CREATE-{role}-{user_id[:8]}", "r": role, "b": branch})
    return user_id


def _token(user_id: str, role: str, branch: str | None) -> str:
    return create_access_token({
        "sub": user_id, "username": "t", "role": role,
        "branch": branch, "token_version": 0,
    })


def test_post_suppliers_as_manager_creates_row():
    _cleanup()
    user_id = _make_user("MANAGER", None)
    try:
        client = TestClient(app)
        resp = client.post(
            "/api/v1/suppliers",
            json={"name": TEST_SUP},
            headers={"Authorization": f"Bearer {_token(user_id, 'MANAGER', None)}"},
        )
        assert resp.status_code == 201, resp.text
        assert resp.json()["name"] == TEST_SUP
        assert resp.json()["is_active"] is True
    finally:
        _cleanup()


def test_post_suppliers_rejects_non_manager():
    for role, branch in (("ADMIN", USER_BRANCH), ("SUPERVISOR", USER_BRANCH), ("SALES", USER_BRANCH)):
        _cleanup()
        user_id = _make_user(role, branch)
        try:
            client = TestClient(app)
            resp = client.post(
                "/api/v1/suppliers",
                json={"name": TEST_SUP},
                headers={"Authorization": f"Bearer {_token(user_id, role, branch)}"},
            )
            assert resp.status_code == 403, f"{role} should be rejected, got {resp.status_code}"
        finally:
            _cleanup()


def test_post_suppliers_duplicate_returns_409():
    _cleanup()
    user_id = _make_user("MANAGER", None)
    try:
        client = TestClient(app)
        # Seed
        resp1 = client.post(
            "/api/v1/suppliers",
            json={"name": TEST_SUP},
            headers={"Authorization": f"Bearer {_token(user_id, 'MANAGER', None)}"},
        )
        assert resp1.status_code == 201
        # Duplicate
        resp2 = client.post(
            "/api/v1/suppliers",
            json={"name": TEST_SUP},
            headers={"Authorization": f"Bearer {_token(user_id, 'MANAGER', None)}"},
        )
        assert resp2.status_code == 409
    finally:
        _cleanup()
