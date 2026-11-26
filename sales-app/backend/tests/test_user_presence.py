"""Presence Status Online: throttle, threshold online, dan guard endpoint.

Logika murni (should_touch_last_seen, is_online) diuji tanpa DB. Guard
endpoint diverifikasi lewat inspeksi AST — pola yang sama dengan guard
``test_month_variable_not_shadowed_in_inventory_tracker`` — karena test
ber-DB butuh Postgres lokal yang tidak selalu tersedia.
"""

import ast
from datetime import datetime, timedelta, timezone
from pathlib import Path

from app.core.presence import (
    PRESENCE_ONLINE_THRESHOLD,
    PRESENCE_TOUCH_INTERVAL,
    is_online,
    should_touch_last_seen,
)

BASE = datetime(2026, 11, 26, 10, 0, 0)


def test_touch_when_never_seen():
    # Belum pernah terlihat → wajib tulis.
    assert should_touch_last_seen(None, now=BASE) is True


def test_touch_throttled_within_interval():
    last = BASE - timedelta(seconds=30)
    assert should_touch_last_seen(last, now=BASE) is False


def test_touch_after_interval():
    last = BASE - PRESENCE_TOUCH_INTERVAL
    assert should_touch_last_seen(last, now=BASE) is True


def test_online_within_threshold():
    last = BASE - timedelta(minutes=4, seconds=59)
    assert is_online(last, now=BASE) is True


def test_online_at_exact_threshold():
    # Tepat 5 menit masih di dalam rentang "5 menit terakhir".
    last = BASE - PRESENCE_ONLINE_THRESHOLD
    assert is_online(last, now=BASE) is True


def test_offline_just_above_threshold():
    last = BASE - PRESENCE_ONLINE_THRESHOLD - timedelta(seconds=1)
    assert is_online(last, now=BASE) is False


def test_offline_when_never_seen():
    assert is_online(None, now=BASE) is False


def test_aware_and_naive_timestamps_equivalent():
    # Nilai aware dari driver dikonversi otomatis; hasil harus sama dengan
    # nilai naive-UTC yang setara.
    aware = (BASE - timedelta(minutes=1)).replace(tzinfo=timezone.utc)
    assert is_online(aware, now=BASE) == is_online(BASE - timedelta(minutes=1), now=BASE)


def _load_source(relative: str) -> ast.Module:
    path = Path(__file__).resolve().parents[1] / "app" / relative
    return ast.parse(path.read_text(encoding="utf-8"))


def _param_deps_use(fn: ast.FunctionDef, dependency: str) -> bool:
    """True bila salah satu parameter punya default Depends(<dependency>)."""
    for stmt in ast.walk(fn):
        if isinstance(stmt, ast.Call) and getattr(stmt.func, "id", "") == "Depends":
            for arg in stmt.args:
                if isinstance(arg, ast.Name) and arg.id == dependency:
                    return True
    return False


def test_presence_endpoint_restricted_to_global_manager():
    """Endpoint presence wajib memakai guard require_manager_global.

    Data last_seen adalah data operasional lintas cabang; kalau guard ini
    longgar (mis. diganti require_supervisor_or_manager_global), supervisor
    cabang ikut melihat aktivitas user lintas cabang.
    """
    tree = _load_source(Path("api") / "endpoints" / "users.py")
    fn = next(
        node
        for node in ast.walk(tree)
        if isinstance(node, ast.FunctionDef) and node.name == "list_user_presence"
    )
    assert _param_deps_use(fn, "require_manager_global"), (
        "Endpoint /users/presence harus memakai Depends(require_manager_global) "
        "sesuai keputusan desain: hanya MANAGER global yang boleh melihat presence."
    )


def test_presence_tracking_never_breaks_auth():
    """Touch last_seen di get_current_user harus dibungkus try/except.

    Kalau tracking gagal (DB penuh, dsb.), request user tetap harus sukses —
    auth tidak boleh 500 karena fitur pemantauan.
    """
    tree = _load_source(Path("core") / "security.py")
    fn = next(
        node
        for node in ast.walk(tree)
        if isinstance(node, ast.FunctionDef) and node.name == "get_current_user"
    )
    has_try = any(isinstance(node, ast.Try) for node in ast.walk(fn))
    assert has_try, (
        "Blok presence touch di get_current_user harus dibungkus try/except "
        "supaya kegagalan tracking tidak menggagalkan autentikasi."
    )
