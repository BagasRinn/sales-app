"""Regression tests for the authorization / session hardening patches.

These tests are pure unit tests: they use in-memory SQLite and a tiny fake DB
object. They never connect to the configured PostgreSQL/Supabase database and
never touch the network.
"""
import uuid
from types import SimpleNamespace

import pytest
from fastapi import HTTPException, Request, Response
from sqlalchemy import Column, Integer, String, create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

from app.api.endpoints import auth as auth_endpoints
from app.core.security import (
    apply_branch_filter,
    assert_can_manage_role,
    effective_scope_role,
    get_current_user,
    is_global_manager,
    resolve_new_user_branch,
)
from app.core.security import create_access_token, create_refresh_token
from app.core.security import get_password_hash
from app.schemas.schemas import RefreshTokenRequest, UserLogin


# ---------------------------------------------------------------------------
# Fake DB (enough for auth.refresh_token)
# ---------------------------------------------------------------------------

class _FakeQuery:
    def __init__(self, row):
        self._row = row

    def filter(self, *args, **kwargs):
        return self

    def first(self):
        return self._row


class FakeDB:
    def __init__(self, row):
        self._row = row

    def query(self, *args, **kwargs):
        return _FakeQuery(self._row)


def _user(**overrides):
    values = dict(
        id=uuid.uuid4(),
        username="audit_user",
        role="ADMIN",
        branch="BANJARMASIN",
        nama="Audit User",
        is_active=True,
        token_version=0,
        deleted_at=None,
    )
    values.update(overrides)
    return SimpleNamespace(**values)


def _refresh(user, token_version=0):
    return create_refresh_token(
        {
            "sub": str(user.id),
            "username": user.username,
            "role": user.role,
            "branch": user.branch,
            "token_version": token_version,
        }
    )


def _make_request(cookies=None, headers=None):
    """Bangun Request minimal untuk memanggil endpoint auth secara langsung."""
    raw_headers = []
    if cookies:
        cookie_header = "; ".join(f"{k}={v}" for k, v in cookies.items())
        raw_headers.append((b"cookie", cookie_header.encode("latin-1")))
    for key, value in (headers or {}).items():
        raw_headers.append((key.lower().encode("latin-1"), value.encode("latin-1")))
    return Request(
        {
            "type": "http",
            "method": "POST",
            "path": "/api/v1/auth/refresh",
            "headers": raw_headers,
            "query_string": b"",
        }
    )


def _call_refresh(body, db, request=None, response=None):
    return auth_endpoints.refresh(
        request=request or _make_request(),
        response=response or Response(),
        body=body,
        db=db,
    )


class TestRefreshToken:
    def test_valid_refresh_token_is_accepted(self):
        user = _user()
        result = _call_refresh(
            RefreshTokenRequest(refresh_token=_refresh(user)), FakeDB(user)
        )
        assert result["access_token"]
        assert result["username"] == user.username

    def test_access_token_cannot_be_used_as_refresh(self):
        user = _user()
        access = create_access_token(
            {
                "sub": str(user.id),
                "username": user.username,
                "role": user.role,
                "branch": user.branch,
                "token_version": 0,
            }
        )
        with pytest.raises(HTTPException) as exc:
            _call_refresh(RefreshTokenRequest(refresh_token=access), FakeDB(user))
        assert exc.value.status_code == 401

    def test_inactive_account_cannot_refresh(self):
        user = _user(is_active=False)
        with pytest.raises(HTTPException) as exc:
            _call_refresh(
                RefreshTokenRequest(refresh_token=_refresh(user)), FakeDB(user)
            )
        assert exc.value.status_code == 403

    def test_stale_token_version_is_rejected(self):
        user = _user(token_version=1)
        with pytest.raises(HTTPException) as exc:
            _call_refresh(
                RefreshTokenRequest(refresh_token=_refresh(user, token_version=0)),
                FakeDB(user),
            )
        assert exc.value.status_code == 401

    def test_cookie_refresh_rotates_without_leaking_token_to_body(self, monkeypatch):
        monkeypatch.setenv("CORS_ORIGINS", "https://admin.example.com")
        user = _user()
        request = _make_request(
            cookies={"admin_rt": _refresh(user)},
            headers={"Origin": "https://admin.example.com"},
        )
        response = Response()

        result = _call_refresh(None, FakeDB(user), request=request, response=response)

        assert result["access_token"]
        # Body tidak boleh membawa refresh token untuk mode cookie.
        assert not result.get("refresh_token")
        set_cookie = response.headers.get("set-cookie", "")
        assert "admin_rt=" in set_cookie
        assert "httponly" in set_cookie.lower()

    def test_cookie_refresh_from_untrusted_origin_is_rejected(self, monkeypatch):
        monkeypatch.setenv("CORS_ORIGINS", "https://admin.example.com")
        user = _user()
        request = _make_request(
            cookies={"admin_rt": _refresh(user)},
            headers={"Origin": "https://evil.example.com"},
        )
        with pytest.raises(HTTPException) as exc:
            _call_refresh(None, FakeDB(user), request=request, response=Response())
        assert exc.value.status_code == 403

    def test_cookie_refresh_without_origin_is_rejected(self):
        user = _user()
        request = _make_request(cookies={"admin_rt": _refresh(user)})
        with pytest.raises(HTTPException) as exc:
            _call_refresh(None, FakeDB(user), request=request, response=Response())
        assert exc.value.status_code == 403

    def test_missing_refresh_source_is_rejected(self):
        user = _user()
        with pytest.raises(HTTPException) as exc:
            _call_refresh(None, FakeDB(user))
        assert exc.value.status_code == 401


class TestWebLogin:
    """Cookie sesi hanya untuk client web, dan hanya untuk peran pengelola."""

    def _login(self, user, client="web", response=None):
        return auth_endpoints.login(
            user=UserLogin(
                username=user.username, password="secret", client=client
            ),
            request=_make_request(),
            response=response or Response(),
            db=FakeDB(user),
        )

    def _user_with_password(self, **overrides):
        return _user(password_hash=get_password_hash("secret"), **overrides)

    def test_web_login_sets_cookie_and_hides_refresh_token(self):
        user = self._user_with_password(role="ADMIN")
        response = Response()

        result = self._login(user, response=response)

        assert result["access_token"]
        assert result["refresh_token"] is None
        set_cookie = response.headers.get("set-cookie", "")
        assert "admin_rt=" in set_cookie
        assert "httponly" in set_cookie.lower()

    def test_mobile_login_returns_refresh_token_without_cookie(self):
        user = self._user_with_password(role="SALES")
        response = Response()

        result = self._login(user, client=None, response=response)

        assert result["access_token"]
        assert result["refresh_token"]
        assert not response.headers.get("set-cookie")

    def test_web_login_rejects_sales_role_without_setting_cookie(self):
        user = self._user_with_password(role="SALES")
        response = Response()

        with pytest.raises(HTTPException) as exc:
            self._login(user, response=response)

        assert exc.value.status_code == 403
        assert not response.headers.get("set-cookie")


class TestAccessToken:
    def test_refresh_token_cannot_be_used_as_access_token(self):
        user = _user()
        with pytest.raises(HTTPException) as exc:
            get_current_user(token=_refresh(user), db=FakeDB(user))
        assert exc.value.status_code == 401

    def test_inactive_user_access_token_is_rejected(self):
        user = _user(is_active=False)
        access = create_access_token(
            {
                "sub": str(user.id),
                "username": user.username,
                "role": user.role,
                "branch": user.branch,
                "token_version": 0,
            }
        )
        with pytest.raises(HTTPException) as exc:
            get_current_user(token=access, db=FakeDB(user))
        assert exc.value.status_code == 401


# ---------------------------------------------------------------------------
# Role ceiling
# ---------------------------------------------------------------------------

class TestRoleCeiling:
    def test_supervisor_cannot_create_admin(self):
        with pytest.raises(HTTPException) as exc:
            assert_can_manage_role(
                {"role": "SUPERVISOR", "branch": "BANJARMASIN"}, "ADMIN"
            )
        assert exc.value.status_code == 403

    def test_admin_cannot_create_manager(self):
        with pytest.raises(HTTPException) as exc:
            assert_can_manage_role({"role": "ADMIN", "branch": "BANJARMASIN"}, "MANAGER")
        assert exc.value.status_code == 403

    def test_admin_cannot_create_any_user(self):
        with pytest.raises(HTTPException) as exc:
            assert_can_manage_role(
                {"role": "ADMIN", "branch": "BANJARMASIN"}, "SALES"
            )
        assert exc.value.status_code == 403

    def test_supervisor_may_create_sales(self):
        assert (
            assert_can_manage_role(
                {"role": "SUPERVISOR", "branch": "BANJARMASIN"}, "SALES"
            )
            == "SALES"
        )

    def test_manager_branch_is_treated_as_branch_admin(self):
        user = {"role": "MANAGER", "branch": "BANJARMASIN"}
        assert effective_scope_role(user) == "ADMIN"
        assert is_global_manager(user) is False
        with pytest.raises(HTTPException):
            assert_can_manage_role(user, "MANAGER")

    def test_branch_manager_cannot_use_global_only_dependency(self):
        from app.core.security import require_supervisor_or_manager_global

        with pytest.raises(HTTPException) as exc:
            require_supervisor_or_manager_global(
                {"role": "MANAGER", "branch": "BANJARMASIN"}
            )
        assert exc.value.status_code == 403

    def test_global_manager_passes_global_only_dependency(self):
        from app.core.security import require_supervisor_or_manager_global

        user = {"role": "MANAGER", "branch": None}
        assert require_supervisor_or_manager_global(user) is user

    def test_unknown_role_is_rejected(self):
        with pytest.raises(HTTPException) as exc:
            assert_can_manage_role({"role": "MANAGER", "branch": None}, "ROOT")
        assert exc.value.status_code == 400


class TestNewUserBranch:
    def test_global_manager_creating_manager_stays_global(self):
        creator = {"role": "MANAGER", "branch": None}
        assert resolve_new_user_branch(creator, "MANAGER", None) is None

    def test_global_manager_cannot_create_branch_manager(self):
        creator = {"role": "MANAGER", "branch": None}
        with pytest.raises(HTTPException) as exc:
            resolve_new_user_branch(creator, "MANAGER", "BANJARMASIN")
        assert exc.value.status_code == 400

    def test_supervisor_is_pinned_to_own_branch(self):
        creator = {"role": "SUPERVISOR", "branch": "BANJARMASIN"}
        assert (
            resolve_new_user_branch(creator, "SALES", "BANJARMASIN")
            == "BANJARMASIN"
        )
        # No branch sent -> default to the supervisor's own branch.
        assert resolve_new_user_branch(creator, "SALES", None) == "BANJARMASIN"
        with pytest.raises(HTTPException) as exc:
            resolve_new_user_branch(creator, "SALES", "SAMPIT")
        assert exc.value.status_code == 403

    def test_supervisor_cannot_create_non_sales(self):
        creator = {"role": "SUPERVISOR", "branch": "BANJARMASIN"}
        with pytest.raises(HTTPException) as exc:
            resolve_new_user_branch(creator, "SUPERVISOR", "BANJARMASIN")
        assert exc.value.status_code == 403

    def test_branchless_supervisor_cannot_create_users(self):
        creator = {"role": "SUPERVISOR", "branch": None}
        with pytest.raises(HTTPException) as exc:
            resolve_new_user_branch(creator, "SALES", None)
        assert exc.value.status_code == 403

    def test_manager_can_create_sales_in_chosen_branch(self):
        creator = {"role": "MANAGER", "branch": None}
        assert (
            resolve_new_user_branch(creator, "SALES", "SAMPIT") == "SAMPIT"
        )


# ---------------------------------------------------------------------------
# Fail-closed branch filter
# ---------------------------------------------------------------------------

SQLiteBase = declarative_base()


class _Row(SQLiteBase):
    __tablename__ = "branch_rows"
    id = Column(Integer, primary_key=True)
    branch = Column(String(20))


@pytest.fixture()
def sqlite_db():
    engine = create_engine("sqlite:///:memory:")
    SQLiteBase.metadata.create_all(engine)
    session = sessionmaker(bind=engine)()
    session.add_all(
        [
            _Row(id=1, branch="BANJARMASIN"),
            _Row(id=2, branch="SAMPIT"),
        ]
    )
    session.commit()
    try:
        yield session
    finally:
        session.close()


class TestBranchFilter:
    def test_branch_user_sees_only_own_branch(self, sqlite_db):
        q = apply_branch_filter(
            sqlite_db.query(_Row),
            _Row,
            {"role": "ADMIN", "branch": "BANJARMASIN"},
        )
        assert [r.id for r in q.all()] == [1]

    def test_global_manager_sees_all(self, sqlite_db):
        q = apply_branch_filter(
            sqlite_db.query(_Row), _Row, {"role": "MANAGER", "branch": None}
        )
        assert sorted(r.id for r in q.all()) == [1, 2]

    @pytest.mark.parametrize("role", ["ADMIN", "SUPERVISOR", "SALES"])
    def test_branchless_non_manager_sees_nothing(self, sqlite_db, role):
        q = apply_branch_filter(
            sqlite_db.query(_Row), _Row, {"role": role, "branch": None}
        )
        assert q.all() == []

    def test_manager_with_branch_is_scoped(self, sqlite_db):
        q = apply_branch_filter(
            sqlite_db.query(_Row),
            _Row,
            {"role": "MANAGER", "branch": "SAMPIT"},
        )
        assert [r.id for r in q.all()] == [2]
