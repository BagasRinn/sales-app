"""Integration tests for sales-import versioning + SQL summary.

Live DB (same style as the other tests in this folder). Test rows are
identified by the ``TEST-SALESIMP-`` prefix and month ``2099-01``, then
cleaned up in ``finally``.
"""
import uuid
from datetime import date
from io import BytesIO

from fastapi.testclient import TestClient
from openpyxl import Workbook
from sqlalchemy import text

from app.core.security import create_access_token
from app.main import app, _ensure_imported_sales_dedupe_key
from app.models.database import engine
from app.models.models import Base

USER_BRANCH = "BANJARMASIN"
OTHER_BRANCH = "BARABAI"
TEST_MONTH = "2099-01"
TEST_PREFIX = "TEST-SALESIMP-"
API = "/api/v1"

# New table must exist even when the app lifespan is not started by TestClient.
Base.metadata.create_all(bind=engine)
# ``create_all`` does not alter an existing table, so ensure the Phase 3
# column/index the same way the app startup does.
_ensure_imported_sales_dedupe_key()


APP_HEADERS = [
    "Tanggal",
    "Trans No",
    "Cabang",
    "Kode Pelanggan",
    "Nama Pelanggan",
    "Kode Item",
    "Nama Item",
    "Qty",
    "Satuan",
    "Harga Satuan",
    "Total Harga Sebelum Diskon",
    "Diskon Layer 1",
    "Diskon Layer 2",
    "Diskon Layer 3",
    "Total Diskon",
    "Up Price",
    "Total Harga Setelah Diskon",
    "Tipe Order",
    "Nama Sales",
    "Supplier",
]


def _cleanup() -> None:
    with engine.begin() as conn:
        conn.execute(
            text(
                "DELETE FROM sync_validation_errors WHERE import_log_id IN "
                "(SELECT id FROM import_logs WHERE file_name LIKE :p)"
            ),
            {"p": f"{TEST_PREFIX}%"},
        )
        conn.execute(
            text(
                "DELETE FROM imported_sales_monthly_summary "
                "WHERE month LIKE '2099-%'"
            )
        )
        conn.execute(
            text(
                "DELETE FROM imported_sales_summary_state "
                "WHERE month LIKE '2099-%'"
            )
        )
        conn.execute(
            text(
                "DELETE FROM imported_sales WHERE trans_no LIKE :p "
                "OR import_log_id IN "
                "(SELECT id FROM import_logs WHERE file_name LIKE :p)"
            ),
            {"p": f"{TEST_PREFIX}%"},
        )
        conn.execute(
            text("DELETE FROM import_logs WHERE file_name LIKE :p"),
            {"p": f"{TEST_PREFIX}%"},
        )
        conn.execute(
            text("DELETE FROM sales_import_versions WHERE month LIKE '2099-%'")
        )
        conn.execute(
            text("DELETE FROM users WHERE username LIKE :p"),
            {"p": f"{TEST_PREFIX}%"},
        )


def _seed_user(role: str, branch: str | None) -> str:
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
                "u": f"{TEST_PREFIX}USER-{role}-{user_id[:8]}",
                "r": role,
                "b": branch,
            },
        )
    return user_id


def _token(user_id: str, role: str, branch: str | None) -> str:
    return create_access_token(
        {
            "sub": user_id,
            "username": "t",
            "role": role,
            "branch": branch,
            "token_version": 0,
        }
    )


def _headers(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def _xlsx(rows: list[list]) -> bytes:
    wb = Workbook()
    ws = wb.active
    ws.append(APP_HEADERS)
    for row in rows:
        ws.append(row)
    buf = BytesIO()
    wb.save(buf)
    return buf.getvalue()


def _row(
    trans_no: str,
    product: str,
    qty: int,
    total: int,
    branch: str = "BANJARMASIN",
    sales_nama: str = "Budi",
    sale_date: str | None = None,
) -> list:
    return [
        sale_date or f"{TEST_MONTH}-15", trans_no, branch, "C001", "Toko A", product,
        f"Produk {product}", qty, "pcs", 10000, total, 0, 0, 0, 0, 0,
        total, "REGULER", sales_nama, "Supplier A",
    ]


def _import(client: TestClient, token: str, rows: list[list]):
    return client.post(
        f"{API}/sales-imports/excel",
        headers=_headers(token),
        files={
            "file": (
                f"{TEST_PREFIX}sales.xlsx",
                _xlsx(rows),
                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            )
        },
    )


def _version(
    client: TestClient,
    token: str,
    month: str = TEST_MONTH,
    query: str = "",
):
    suffix = f"&{query}" if query else ""
    return client.get(
        f"{API}/sales-imports/version?month={month}{suffix}",
        headers=_headers(token),
    )


def _summary(client: TestClient, token: str, query: str = ""):
    suffix = f"&{query}" if query else ""
    return client.get(
        f"{API}/sales-imports/summary?month={TEST_MONTH}{suffix}",
        headers=_headers(token),
    )


def test_failed_import_does_not_bump_version():
    _cleanup()
    manager = _seed_user("MANAGER", None)
    token = _token(manager, "MANAGER", None)
    client = TestClient(app)

    try:
        before = _version(client, token)
        assert before.status_code == 200, before.text
        assert before.json()["scope"] == "GLOBAL"
        assert before.json()["version"] == 0
        assert before.headers.get("cache-control") == "no-store"

        bad = client.post(
            f"{API}/sales-imports/excel",
            headers=_headers(token),
            files={
                "file": (
                    f"{TEST_PREFIX}bad.xlsx",
                    b"not-an-xlsx",
                    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                )
            },
        )
        assert bad.status_code == 200, bad.text
        assert bad.json()["success"] is False

        after = _version(client, token)
        assert after.json()["version"] == 0
    finally:
        _cleanup()


def test_import_bumps_branch_and_global_versions():
    _cleanup()
    manager = _seed_user("MANAGER", None)
    supervisor = _seed_user("SUPERVISOR", USER_BRANCH)
    mgr_token = _token(manager, "MANAGER", None)
    sup_token = _token(supervisor, "SUPERVISOR", USER_BRANCH)
    client = TestClient(app)

    try:
        resp = _import(
            client,
            sup_token,
            [
                _row(f"{TEST_PREFIX}T1", "P001", 2, 20000),
                _row(f"{TEST_PREFIX}T2", "P002", 1, 5000),
            ],
        )
        assert resp.status_code == 200, resp.text
        body = resp.json()
        assert body["success"] is True
        assert body["inserted"] == 2
        scopes = {(v["scope"], v["version"]) for v in body["versions"]}
        assert ("GLOBAL", 1) in scopes
        assert (USER_BRANCH, 1) in scopes

        sup_version = _version(client, sup_token).json()
        assert sup_version["scope"] == USER_BRANCH
        assert sup_version["version"] == 1

        mgr_version = _version(client, mgr_token).json()
        assert mgr_version["scope"] == "GLOBAL"
        assert mgr_version["version"] == 1

        summary = _summary(client, sup_token)
        assert summary.status_code == 200, summary.text
        assert summary.headers.get("cache-control") == "no-store"
        data = summary.json()
        assert data["scope"] == USER_BRANCH
        assert data["version"] == 1
        assert data["total_revenue"] == 25000
        assert data["total_qty"] == 3
        assert data["imported_rows"] == 2
        assert data["by_product"][0]["product_kode"] == "P001"
        assert data["by_product"][0]["revenue"] == 20000
        # Daily series feeds the analytics trend chart. All fixture rows share
        # one sale date, so the series collapses to a single bucket.
        assert data["by_day"] == [
            {"date": f"{TEST_MONTH}-15", "qty": 3, "revenue": 25000}
        ]
        # Per-sales daily series (multi-line chart) uses the same payload.
        assert len(data["by_sales_day"]) == 1
        assert data["by_sales_day"][0]["sales_nama"] == "Budi"
        assert data["by_sales_day"][0]["points"] == [
            {"date": f"{TEST_MONTH}-15", "revenue": 25000}
        ]

        # A second import with a new trans_no adds a new row, so the versions
        # bump again. Re-importing the *same* rows would not (see dedupe tests
        # below).
        again = _import(client, sup_token, [_row(f"{TEST_PREFIX}T3", "P003", 1, 1000)])
        assert again.json()["success"] is True
        assert _version(client, sup_token).json()["version"] == 2
        assert _version(client, mgr_token).json()["version"] == 2
    finally:
        _cleanup()


def test_global_manager_import_attributes_rows_via_cabang_column():
    _cleanup()
    manager = _seed_user("MANAGER", None)
    sup_banjar = _seed_user("SUPERVISOR", USER_BRANCH)
    sup_barabai = _seed_user("SUPERVISOR", OTHER_BRANCH)
    mgr_token = _token(manager, "MANAGER", None)
    banjar_token = _token(sup_banjar, "SUPERVISOR", USER_BRANCH)
    barabai_token = _token(sup_barabai, "SUPERVISOR", OTHER_BRANCH)
    client = TestClient(app)

    try:
        resp = _import(
            client,
            mgr_token,
            [
                _row(f"{TEST_PREFIX}G1", "P001", 1, 10000, USER_BRANCH),
                _row(f"{TEST_PREFIX}G2", "P002", 1, 20000, OTHER_BRANCH),
                # Empty Cabang -> stays NULL (global only).
                _row(f"{TEST_PREFIX}G3", "P003", 1, 40000, ""),
            ],
        )
        assert resp.status_code == 200, resp.text
        body = resp.json()
        assert body["success"] is True
        scopes = {v["scope"] for v in body["versions"]}
        assert {"GLOBAL", USER_BRANCH, OTHER_BRANCH} <= scopes

        banjar = _summary(client, banjar_token).json()
        assert banjar["total_revenue"] == 10000
        assert banjar["imported_rows"] == 1

        barabai = _summary(client, barabai_token).json()
        assert barabai["total_revenue"] == 20000
        assert barabai["imported_rows"] == 1

        global_summary = _summary(client, mgr_token).json()
        assert global_summary["total_revenue"] == 70000
        assert global_summary["imported_rows"] == 3
    finally:
        _cleanup()


def test_summary_is_strictly_branch_scoped_and_global_sees_all():
    _cleanup()
    manager = _seed_user("MANAGER", None)
    sup_banjar = _seed_user("SUPERVISOR", USER_BRANCH)
    sup_barabai = _seed_user("SUPERVISOR", OTHER_BRANCH)
    mgr_token = _token(manager, "MANAGER", None)
    banjar_token = _token(sup_banjar, "SUPERVISOR", USER_BRANCH)
    barabai_token = _token(sup_barabai, "SUPERVISOR", OTHER_BRANCH)
    client = TestClient(app)

    try:
        assert _import(
            client,
            banjar_token,
            [_row(f"{TEST_PREFIX}B1", "P001", 2, 20000)],
        ).json()["success"] is True
        assert _import(
            client,
            barabai_token,
            [_row(f"{TEST_PREFIX}R1", "P009", 1, 99999)],
        ).json()["success"] is True

        banjar = _summary(client, banjar_token).json()
        assert banjar["total_revenue"] == 20000
        assert banjar["imported_rows"] == 1

        barabai = _summary(client, barabai_token).json()
        assert barabai["total_revenue"] == 99999
        assert barabai["imported_rows"] == 1

        # Global manager sees both branches. GLOBAL was bumped by both imports.
        global_summary = _summary(client, mgr_token).json()
        assert global_summary["scope"] == "GLOBAL"
        assert global_summary["version"] == 2
        assert global_summary["total_revenue"] == 119999
        assert global_summary["imported_rows"] == 2
    finally:
        _cleanup()


def test_global_manager_can_filter_summary_by_branch():
    """A global MANAGER may narrow version+summary to one branch."""
    _cleanup()
    manager = _seed_user("MANAGER", None)
    sup_banjar = _seed_user("SUPERVISOR", USER_BRANCH)
    sup_barabai = _seed_user("SUPERVISOR", OTHER_BRANCH)
    mgr_token = _token(manager, "MANAGER", None)
    banjar_token = _token(sup_banjar, "SUPERVISOR", USER_BRANCH)
    barabai_token = _token(sup_barabai, "SUPERVISOR", OTHER_BRANCH)
    client = TestClient(app)

    try:
        assert _import(
            client,
            banjar_token,
            [_row(f"{TEST_PREFIX}B1", "P001", 2, 20000)],
        ).json()["success"] is True
        assert _import(
            client,
            barabai_token,
            [_row(f"{TEST_PREFIX}R1", "P009", 1, 99999)],
        ).json()["success"] is True

        # Filtered summary returns only the selected branch's rows.
        banjar = _summary(
            client, mgr_token, f"branch={USER_BRANCH}"
        ).json()
        assert banjar["scope"] == USER_BRANCH
        assert banjar["version"] == 1
        assert banjar["total_revenue"] == 20000
        assert banjar["imported_rows"] == 1

        barabai = _summary(
            client, mgr_token, f"branch={OTHER_BRANCH}"
        ).json()
        assert barabai["scope"] == OTHER_BRANCH
        assert barabai["total_revenue"] == 99999
        assert barabai["imported_rows"] == 1

        # Omitting branch keeps the aggregate GLOBAL scope.
        assert _summary(client, mgr_token).json()["scope"] == "GLOBAL"

        # Version probe honours the same filter and stays no-store.
        filtered_version = _version(
            client, mgr_token, query=f"branch={USER_BRANCH}"
        )
        assert filtered_version.status_code == 200, filtered_version.text
        assert filtered_version.json()["scope"] == USER_BRANCH
        assert filtered_version.json()["version"] == 1
        assert filtered_version.headers.get("cache-control") == "no-store"

        # Branch-scoped users cannot read another branch...
        forbidden = _summary(
            client, banjar_token, f"branch={OTHER_BRANCH}"
        )
        assert forbidden.status_code == 403, forbidden.text

        # ...but may pass their own branch explicitly.
        own = _summary(client, banjar_token, f"branch={USER_BRANCH}")
        assert own.status_code == 200, own.text
        assert own.json()["scope"] == USER_BRANCH

        # Unknown branch is rejected instead of creating an arbitrary scope.
        unknown = _summary(client, mgr_token, "branch=TIDAK_ADA")
        assert unknown.status_code == 400, unknown.text
    finally:
        _cleanup()


def test_summary_limit_and_include_reduce_payload():
    _cleanup()
    supervisor = _seed_user("SUPERVISOR", USER_BRANCH)
    token = _token(supervisor, "SUPERVISOR", USER_BRANCH)
    client = TestClient(app)

    try:
        assert _import(
            client,
            token,
            [
                _row(f"{TEST_PREFIX}L1", "P001", 1, 10000),
                _row(f"{TEST_PREFIX}L2", "P002", 1, 30000),
                _row(f"{TEST_PREFIX}L3", "P003", 1, 20000),
            ],
        ).json()["success"] is True

        limited = _summary(client, token, "limit=2").json()
        assert len(limited["by_product"]) == 2
        assert limited["by_product"][0]["product_kode"] == "P002"
        assert limited["by_product"][1]["product_kode"] == "P003"
        # Totals are still for the whole month, not just the top-N.
        assert limited["total_revenue"] == 60000

        only_products = _summary(client, token, "include=product").json()
        assert only_products["by_product"]
        assert only_products["by_sales"] == []
        assert only_products["by_customer"] == []
        assert only_products["by_channel"] == []
        assert only_products["by_day"] == []
        assert only_products["by_sales_day"] == []

        only_day = _summary(client, token, "include=day").json()
        assert only_day["by_day"] == [
            {"date": f"{TEST_MONTH}-15", "qty": 3, "revenue": 60000}
        ]
        assert only_day["by_product"] == []
        assert only_day["by_channel"] == []
        assert only_day["by_sales_day"] == []

        only_sales_day = _summary(client, token, "include=sales_day").json()
        assert len(only_sales_day["by_sales_day"]) == 1
        assert only_sales_day["by_sales_day"][0]["points"] == [
            {"date": f"{TEST_MONTH}-15", "revenue": 60000}
        ]
        assert only_sales_day["by_day"] == []
        assert only_sales_day["by_product"] == []
    finally:
        _cleanup()


def test_sales_daily_series_orders_by_revenue_and_keeps_days():
    _cleanup()
    supervisor = _seed_user("SUPERVISOR", USER_BRANCH)
    token = _token(supervisor, "SUPERVISOR", USER_BRANCH)
    client = TestClient(app)

    try:
        assert _import(
            client,
            token,
            [
                _row(
                    f"{TEST_PREFIX}S1",
                    "P001",
                    1,
                    10000,
                    sales_nama="Budi",
                    sale_date=f"{TEST_MONTH}-15",
                ),
                _row(
                    f"{TEST_PREFIX}S2",
                    "P002",
                    1,
                    5000,
                    sales_nama="Budi",
                    sale_date=f"{TEST_MONTH}-16",
                ),
                _row(
                    f"{TEST_PREFIX}S3",
                    "P003",
                    1,
                    20000,
                    sales_nama="Sari",
                    sale_date=f"{TEST_MONTH}-15",
                ),
                _row(
                    f"{TEST_PREFIX}S4",
                    "P004",
                    1,
                    30000,
                    sales_nama="Andi",
                    sale_date=f"{TEST_MONTH}-16",
                ),
            ],
        ).json()["success"] is True

        series = _summary(client, token, "include=sales_day").json()["by_sales_day"]
        # Ordered by month revenue: Andi 30k, Sari 20k, Budi 15k.
        assert [s["sales_nama"] for s in series] == ["Andi", "Sari", "Budi"]
        assert series[0]["points"] == [
            {"date": f"{TEST_MONTH}-16", "revenue": 30000}
        ]
        # One sales can have several daily buckets.
        assert series[2]["points"] == [
            {"date": f"{TEST_MONTH}-15", "revenue": 10000},
            {"date": f"{TEST_MONTH}-16", "revenue": 5000},
        ]
    finally:
        _cleanup()


def _live_where(scope: str) -> tuple[str, dict]:
    where = "sale_date >= :start AND sale_date < :end"
    params = {"start": date(2099, 1, 1), "end": date(2099, 2, 1)}
    if scope != "GLOBAL":
        where += " AND branch = :branch"
        params["branch"] = scope
    return where, params


def _live_totals(scope: str) -> tuple[int, int, int]:
    where, params = _live_where(scope)
    with engine.begin() as conn:
        row = conn.execute(
            text(
                "SELECT COALESCE(SUM(total_amount), 0) AS revenue, "
                "COALESCE(SUM(qty), 0) AS qty, COUNT(*) AS row_count "
                f"FROM imported_sales WHERE {where}"
            ),
            params,
        ).one()
    return int(row.revenue), int(row.qty), int(row.row_count)


def _live_products(scope: str) -> list[dict]:
    where, params = _live_where(scope)
    with engine.begin() as conn:
        rows = conn.execute(
            text(
                "SELECT product_kode, product_nama, "
                "COALESCE(SUM(qty), 0) AS qty, "
                "COALESCE(SUM(total_amount), 0) AS revenue "
                f"FROM imported_sales WHERE {where} "
                "GROUP BY product_kode, product_nama "
                "ORDER BY revenue DESC, COALESCE(product_nama, '') ASC, "
                "COALESCE(product_kode, '') ASC LIMIT 100"
            ),
            params,
        ).all()
    return [
        {
            "product_kode": row.product_kode,
            "product_nama": row.product_nama,
            "qty": int(row.qty),
            "revenue": int(row.revenue),
        }
        for row in rows
    ]


def test_precomputed_summary_matches_live_aggregation_and_backfills():
    _cleanup()
    supervisor = _seed_user("SUPERVISOR", USER_BRANCH)
    token = _token(supervisor, "SUPERVISOR", USER_BRANCH)
    client = TestClient(app)

    try:
        assert _import(
            client,
            token,
            [
                _row(f"{TEST_PREFIX}PC1", "P001", 2, 20000),
                _row(f"{TEST_PREFIX}PC2", "P002", 1, 30000),
                _row(f"{TEST_PREFIX}PC3", "P001", 3, 15000),
            ],
        ).json()["success"] is True

        # A successful import rebuilds the snapshot in the same transaction.
        with engine.begin() as conn:
            state = conn.execute(
                text(
                    "SELECT source_version FROM imported_sales_summary_state "
                    "WHERE scope = :s AND month = :m"
                ),
                {"s": USER_BRANCH, "m": TEST_MONTH},
            ).one()
        assert int(state.source_version) == 1

        first = _summary(client, token).json()
        assert (
            first["total_revenue"],
            first["total_qty"],
            first["imported_rows"],
        ) == _live_totals(USER_BRANCH)
        assert first["by_product"] == _live_products(USER_BRANCH)

        # Simulate legacy data (rows imported before the snapshot existed):
        # drop snapshot + state, then let the read path backfill lazily.
        with engine.begin() as conn:
            conn.execute(
                text(
                    "DELETE FROM imported_sales_monthly_summary "
                    "WHERE scope = :s AND month = :m"
                ),
                {"s": USER_BRANCH, "m": TEST_MONTH},
            )
            conn.execute(
                text(
                    "DELETE FROM imported_sales_summary_state "
                    "WHERE scope = :s AND month = :m"
                ),
                {"s": USER_BRANCH, "m": TEST_MONTH},
            )

        backfilled = _summary(client, token).json()
        assert (
            backfilled["total_revenue"],
            backfilled["total_qty"],
            backfilled["imported_rows"],
        ) == _live_totals(USER_BRANCH)
        assert backfilled["by_product"] == _live_products(USER_BRANCH)
        assert backfilled["version"] == first["version"]

        # GLOBAL includes rows from every branch plus NULL-branch rows.
        manager = _seed_user("MANAGER", None)
        mgr_token = _token(manager, "MANAGER", None)
        assert _import(
            client,
            mgr_token,
            [
                _row(f"{TEST_PREFIX}PC4", "P009", 1, 5000, OTHER_BRANCH),
                _row(f"{TEST_PREFIX}PC5", "P010", 1, 7000, ""),
            ],
        ).json()["success"] is True

        global_summary = _summary(client, mgr_token).json()
        assert (
            global_summary["total_revenue"],
            global_summary["total_qty"],
            global_summary["imported_rows"],
        ) == _live_totals("GLOBAL")
        assert global_summary["by_product"] == _live_products("GLOBAL")
    finally:
        _cleanup()


# ==================== PHASE 3: DEDUPE / UPSERT ====================


def _count_rows(trans_prefix: str) -> int:
    with engine.begin() as conn:
        return int(
            conn.execute(
                text(
                    "SELECT COUNT(*) FROM imported_sales "
                    "WHERE trans_no LIKE :p"
                ),
                {"p": f"{trans_prefix}%"},
            ).scalar()
            or 0
        )


def _dedupe_keys(trans_prefix: str) -> list[str | None]:
    with engine.begin() as conn:
        rows = conn.execute(
            text(
                "SELECT dedupe_key FROM imported_sales "
                "WHERE trans_no LIKE :p ORDER BY dedupe_key"
            ),
            {"p": f"{trans_prefix}%"},
        ).all()
    return [row[0] for row in rows]


def test_reimport_same_file_is_idempotent():
    _cleanup()
    supervisor = _seed_user("SUPERVISOR", USER_BRANCH)
    token = _token(supervisor, "SUPERVISOR", USER_BRANCH)
    client = TestClient(app)
    prefix = f"{TEST_PREFIX}ID"
    rows = [
        _row(f"{prefix}A", "P001", 2, 20000),
        _row(f"{prefix}B", "P002", 1, 5000),
    ]

    try:
        first = _import(client, token, rows).json()
        assert first["success"] is True
        assert (first["inserted"], first["updated"]) == (2, 0)
        assert _version(client, token).json()["version"] == 1

        again = _import(client, token, rows).json()
        assert again["success"] is True
        assert (again["inserted"], again["updated"]) == (0, 2)
        # No data changed, so no version bump and no summary rebuild.
        assert again["versions"] == []
        assert _version(client, token).json()["version"] == 1

        summary = _summary(client, token).json()
        assert summary["imported_rows"] == 2
        assert summary["total_revenue"] == 25000
        assert _count_rows(prefix) == 2
        assert all(_dedupe_keys(prefix))
    finally:
        _cleanup()


def test_reimport_updates_changed_row_and_bumps_version():
    _cleanup()
    supervisor = _seed_user("SUPERVISOR", USER_BRANCH)
    token = _token(supervisor, "SUPERVISOR", USER_BRANCH)
    client = TestClient(app)
    prefix = f"{TEST_PREFIX}UP"

    try:
        assert _import(
            client,
            token,
            [_row(f"{prefix}A", "P001", 2, 20000)],
        ).json()["inserted"] == 1
        assert _version(client, token).json()["version"] == 1

        changed = _import(
            client,
            token,
            [_row(f"{prefix}A", "P001", 2, 25000)],
        ).json()
        assert changed["success"] is True
        assert (changed["inserted"], changed["updated"]) == (0, 1)
        assert {v["scope"] for v in changed["versions"]} == {
            "GLOBAL",
            USER_BRANCH,
        }
        assert _version(client, token).json()["version"] == 2

        summary = _summary(client, token).json()
        assert summary["imported_rows"] == 1
        assert summary["total_revenue"] == 25000
        assert _count_rows(prefix) == 1
    finally:
        _cleanup()


def test_reimport_with_new_row_inserts_only_the_new_one():
    _cleanup()
    supervisor = _seed_user("SUPERVISOR", USER_BRANCH)
    token = _token(supervisor, "SUPERVISOR", USER_BRANCH)
    client = TestClient(app)
    prefix = f"{TEST_PREFIX}NEW"

    try:
        assert _import(
            client,
            token,
            [_row(f"{prefix}A", "P001", 1, 10000)],
        ).json()["inserted"] == 1

        body = _import(
            client,
            token,
            [
                _row(f"{prefix}A", "P001", 1, 10000),
                _row(f"{prefix}B", "P002", 1, 7000),
            ],
        ).json()
        assert body["success"] is True
        assert (body["inserted"], body["updated"]) == (1, 1)
        assert _version(client, token).json()["version"] == 2

        summary = _summary(client, token).json()
        assert summary["imported_rows"] == 2
        assert summary["total_revenue"] == 17000
        assert _count_rows(prefix) == 2
    finally:
        _cleanup()


def test_identical_rows_in_one_file_stay_separate_but_idempotent():
    _cleanup()
    supervisor = _seed_user("SUPERVISOR", USER_BRANCH)
    token = _token(supervisor, "SUPERVISOR", USER_BRANCH)
    client = TestClient(app)
    prefix = f"{TEST_PREFIX}DUP"
    rows = [
        _row(f"{prefix}A", "P001", 1, 10000),
        # Same natural key/content: a legitimate duplicate line in the file.
        _row(f"{prefix}A", "P001", 1, 10000),
    ]

    try:
        first = _import(client, token, rows).json()
        assert (first["inserted"], first["updated"]) == (2, 0)
        keys = _dedupe_keys(prefix)
        assert len(keys) == 2
        assert len(set(keys)) == 2

        again = _import(client, token, rows).json()
        assert (again["inserted"], again["updated"]) == (0, 2)
        assert _version(client, token).json()["version"] == 1
        assert _count_rows(prefix) == 2
    finally:
        _cleanup()


def test_legacy_null_dedupe_key_is_migrated_and_matched():
    _cleanup()
    supervisor = _seed_user("SUPERVISOR", USER_BRANCH)
    token = _token(supervisor, "SUPERVISOR", USER_BRANCH)
    client = TestClient(app)
    prefix = f"{TEST_PREFIX}LEG"
    row = _row(f"{prefix}A", "P001", 1, 10000)

    try:
        assert _import(client, token, [row]).json()["inserted"] == 1
        # Simulate a row imported before Phase 3 added the column.
        with engine.begin() as conn:
            conn.execute(
                text(
                    "UPDATE imported_sales SET dedupe_key = NULL "
                    "WHERE trans_no = :t"
                ),
                {"t": f"{prefix}A"},
            )

        body = _import(client, token, [row]).json()
        assert body["success"] is True
        assert (body["inserted"], body["updated"]) == (0, 1)
        # Lazy migration assigned a key, but the data did not change.
        assert body["versions"] == []
        assert _version(client, token).json()["version"] == 1
        assert _count_rows(prefix) == 1
        assert all(_dedupe_keys(prefix))
    finally:
        _cleanup()


def test_same_trans_no_in_different_branches_is_not_deduped():
    _cleanup()
    sup_banjar = _seed_user("SUPERVISOR", USER_BRANCH)
    sup_barabai = _seed_user("SUPERVISOR", OTHER_BRANCH)
    manager = _seed_user("MANAGER", None)
    banjar_token = _token(sup_banjar, "SUPERVISOR", USER_BRANCH)
    barabai_token = _token(sup_barabai, "SUPERVISOR", OTHER_BRANCH)
    mgr_token = _token(manager, "MANAGER", None)
    client = TestClient(app)
    prefix = f"{TEST_PREFIX}BR"
    row = _row(f"{prefix}A", "P001", 1, 10000)

    try:
        assert _import(client, banjar_token, [row]).json()["inserted"] == 1
        assert _import(client, barabai_token, [row]).json()["inserted"] == 1

        assert _summary(client, banjar_token).json()["imported_rows"] == 1
        assert _summary(client, barabai_token).json()["imported_rows"] == 1
        global_summary = _summary(client, mgr_token).json()
        assert global_summary["imported_rows"] == 2
        assert global_summary["total_revenue"] == 20000
    finally:
        _cleanup()
