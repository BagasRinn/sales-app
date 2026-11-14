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
from app.main import (
    app,
    _ensure_imported_sales_dedupe_key,
    _ensure_imported_sales_template_v2_columns,
    _ensure_imported_returns,
)
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
_ensure_imported_sales_template_v2_columns()
_ensure_imported_returns()


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
V2_HEADERS = [
    "Cabang", "Penjualan", "Kode", "Nama Pelanggan", "Kode Item",
    "Nama Item", "TOTAL", "MARGIN", "Sales", "Supplier", "Mother SKU",
    "Divisi",
]
RETURN_HEADERS = [
    "Cabang", "Tanggal Retur", "Kode Item", "Nama Item", "TOTAL",
    "TOTAL PPN", "MARGIN", "Supplier", "Divisi", "Mother SKU",
    "Kode Pelanggan", "Nama Pelanggan", "Sales",
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
                "DELETE FROM imported_returns WHERE import_log_id IN "
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


def _upload_excel(
        client: TestClient,
        token: str,
        path: str,
        filename: str,
        rows: list[list],
        headers: list[str],
):
        return client.post(
            f"{API}{path}",
            headers=_headers(token),
            files={
                "file": (
                    filename,
                    _xlsx(rows, headers),
                    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                )
            },
        )


def _v2_row(total: int = 100, margin: int = 20) -> list:
        return [
            USER_BRANCH, f"{TEST_MONTH}-15", "C001", "Toko A", "P001",
            "Produk P001", total, margin, "Budi", "Supplier A", "M001",
            "Bangunan",
        ]


def _return_row(
        total: int = 30,
        margin: int = 5,
        supplier: str = "Supplier A",
        sale_date: str | None = None,
        mother_sku: str = "M001",
) -> list:
        return [
            USER_BRANCH, sale_date or f"{TEST_MONTH}-20", "P001", "Produk P001", total,
            total + 3000, margin, supplier, "Bangunan", mother_sku, "C001",
            "Toko A", "Budi",
        ]


def _import_returns(client: TestClient, token: str, row: list):
        return _upload_excel(
            client,
            token,
            "/sales-imports/returns/excel",
            f"{TEST_PREFIX}returns.xlsx",
            [row],
            RETURN_HEADERS,
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


def _manager_token() -> str:
    user_id = _seed_user("MANAGER", None)
    return _token(user_id, "MANAGER", None)


def _headers(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}


def _xlsx(rows: list[list], headers: list[str] = APP_HEADERS) -> bytes:
    wb = Workbook()
    ws = wb.active
    ws.append(headers)
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
    customer_kode: str | None = None,
) -> list:
    return [
        sale_date or f"{TEST_MONTH}-15",
        trans_no,
        branch,
        customer_kode or "C001",
        "Toko A",
        product,
        f"Produk {product}",
        qty,
        "pcs",
        10000,
        total,
        0,
        0,
        0,
        0,
        0,
        total,
        "REGULER",
        sales_nama,
        "Supplier A",
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


def _comparison(client: TestClient, token: str, query: str = ""):
    suffix = f"&{query}" if query else ""
    return client.get(
        f"{API}/sales-imports/comparison?month={TEST_MONTH}{suffix}",
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
            mgr_token,
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
        assert data["effective_calls"] == 2
        assert data["active_outlets"] == 1
        assert data["by_product"][0]["product_kode"] == "P001"
        assert data["by_product"][0]["revenue"] == 20000
        assert data["by_supplier"] == [
            {
                "supplier": "Supplier A",
                "qty": 3,
                "revenue": 25000,
                "margin": 0,
            }
        ]
        # Daily series feeds the analytics trend chart. All fixture rows share
        # one sale date, so the series collapses to a single bucket.
        assert data["by_day"] == [
            {
                "date": f"{TEST_MONTH}-15",
                "qty": 3,
                "margin": 0,
                "revenue": 25000,
            }
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
        again = _import(client, mgr_token, [_row(f"{TEST_PREFIX}T3", "P003", 1, 1000)])
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


def test_sales_import_access_and_month_delete_are_scoped():
    _cleanup()
    manager = _seed_user("MANAGER", None)
    branch_manager = _seed_user("MANAGER", USER_BRANCH)
    supervisor = _seed_user("SUPERVISOR", USER_BRANCH)
    admin = _seed_user("ADMIN", None)
    manager_token = _token(manager, "MANAGER", None)
    branch_manager_token = _token(branch_manager, "MANAGER", USER_BRANCH)
    supervisor_token = _token(supervisor, "SUPERVISOR", USER_BRANCH)
    admin_token = _token(admin, "ADMIN", None)
    client = TestClient(app)
    rows = [
        _row(f"{TEST_PREFIX}DEL1", "P001", 1, 10000, USER_BRANCH),
        _row(f"{TEST_PREFIX}DEL2", "P002", 1, 20000, OTHER_BRANCH),
    ]

    try:
        assert _import(client, supervisor_token, rows).status_code == 403
        assert _import(client, branch_manager_token, rows).status_code == 403
        assert _version(client, supervisor_token).status_code == 200
        assert _summary(client, supervisor_token).status_code == 200
        assert _version(client, admin_token).status_code == 403
        assert _summary(client, admin_token).status_code == 403
        assert client.delete(
            f"{API}/sales-imports/month?month={TEST_MONTH}&all_branches=true",
            headers=_headers(supervisor_token),
        ).status_code == 403

        assert _import(client, manager_token, rows).json()["success"] is True
        branch_delete = client.delete(
            f"{API}/sales-imports/month?month={TEST_MONTH}&branch={USER_BRANCH}",
            headers=_headers(manager_token),
        )
        assert branch_delete.status_code == 200, branch_delete.text
        assert branch_delete.json()["deleted"] == 1
        version_after_branch_delete = _version(
            client, manager_token
        ).json()["version"]

        repeated_delete = client.delete(
            f"{API}/sales-imports/month?month={TEST_MONTH}&branch={USER_BRANCH}",
            headers=_headers(manager_token),
        )
        assert repeated_delete.status_code == 200
        assert repeated_delete.json()["deleted"] == 0
        assert _version(client, manager_token).json()["version"] == (
            version_after_branch_delete
        )

        global_delete = client.delete(
            f"{API}/sales-imports/month?month={TEST_MONTH}&all_branches=true",
            headers=_headers(manager_token),
        )
        assert global_delete.status_code == 200, global_delete.text
        assert global_delete.json()["deleted"] == 1
        assert client.delete(
            f"{API}/sales-imports/month?month={TEST_MONTH}",
            headers=_headers(manager_token),
        ).status_code == 400
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
            mgr_token,
            [_row(f"{TEST_PREFIX}B1", "P001", 2, 20000)],
        ).json()["success"] is True
        assert _import(
            client,
            mgr_token,
            [_row(f"{TEST_PREFIX}R1", "P009", 1, 99999, OTHER_BRANCH)],
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
            mgr_token,
            [_row(f"{TEST_PREFIX}B1", "P001", 2, 20000)],
        ).json()["success"] is True
        assert _import(
            client,
            mgr_token,
            [_row(f"{TEST_PREFIX}R1", "P009", 1, 99999, OTHER_BRANCH)],
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
    upload_token = _manager_token()
    client = TestClient(app)

    try:
        assert _import(
            client,
            upload_token,
            [
                _row(f"{TEST_PREFIX}L1", "P001", 1, 10000, sales_nama="Sales A"),
                _row(f"{TEST_PREFIX}L2", "P002", 1, 30000, sales_nama="Sales B"),
                _row(f"{TEST_PREFIX}L3", "P003", 1, 20000, sales_nama="Sales C"),
            ],
        ).json()["success"] is True

        limited = _summary(client, token, "limit=2").json()
        assert len(limited["by_product"]) == 2
        assert limited["by_product"][0]["product_kode"] == "P002"
        assert limited["by_product"][1]["product_kode"] == "P003"
        # Totals are still for the whole month, not just the top-N.
        assert limited["total_revenue"] == 60000

        limited_sales = _summary(
            client, token, "limit=1&include=sales"
        ).json()
        assert len(limited_sales["by_sales"]) == 1

        all_sales = _summary(
            client, token, "limit=1&include=all_sales"
        ).json()
        assert [row["sales_nama"] for row in all_sales["by_sales"]] == [
            "Sales B",
            "Sales C",
            "Sales A",
        ]

        all_sales_range = _summary(
            client,
            token,
            "limit=1&range_months=3&include=all_sales",
        ).json()
        assert [row["sales_nama"] for row in all_sales_range["by_sales"]] == [
            "Sales B",
            "Sales C",
            "Sales A",
        ]

        only_products = _summary(client, token, "include=product").json()
        assert only_products["by_product"]
        assert only_products["by_sales"] == []
        assert only_products["by_customer"] == []
        assert only_products["by_channel"] == []
        assert only_products["by_divisi"] == []
        assert only_products["by_supplier"] == []
        assert only_products["by_day"] == []
        assert only_products["by_sales_day"] == []

        only_day = _summary(client, token, "include=day").json()
        assert only_day["by_day"] == [
            {
                "date": f"{TEST_MONTH}-15",
                "qty": 3,
                "margin": 0,
                "revenue": 60000,
            }
        ]
        assert only_day["by_product"] == []
        assert only_day["by_channel"] == []
        assert only_day["by_supplier"] == []
        assert only_day["by_sales_day"] == []

        only_supplier = _summary(client, token, "include=supplier").json()
        assert only_supplier["by_supplier"] == [
            {
                "supplier": "Supplier A",
                "qty": 3,
                "revenue": 60000,
                "margin": 0,
            }
        ]
        assert only_supplier["by_product"] == []

        only_sales_day = _summary(client, token, "include=sales_day").json()
        assert [
            row["sales_nama"] for row in only_sales_day["by_sales_day"]
        ] == ["Sales B", "Sales C", "Sales A"]
        assert [row["points"] for row in only_sales_day["by_sales_day"]] == [
            [{"date": f"{TEST_MONTH}-15", "revenue": 30000}],
            [{"date": f"{TEST_MONTH}-15", "revenue": 20000}],
            [{"date": f"{TEST_MONTH}-15", "revenue": 10000}],
        ]
        assert only_sales_day["by_day"] == []
        assert only_sales_day["by_product"] == []
    finally:
        _cleanup()


def test_sales_daily_series_orders_by_revenue_and_keeps_days():
    _cleanup()
    supervisor = _seed_user("SUPERVISOR", USER_BRANCH)
    token = _token(supervisor, "SUPERVISOR", USER_BRANCH)
    upload_token = _manager_token()
    client = TestClient(app)

    try:
        assert _import(
            client,
            upload_token,
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
                "MAX(mother_sku) AS mother_sku, "
                "COALESCE(SUM(qty), 0) AS qty, "
                "COALESCE(SUM(total_amount), 0) AS revenue, "
                "COALESCE(SUM(margin), 0) AS margin "
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
            "mother_sku": row.mother_sku,
            "qty": int(row.qty),
            "revenue": int(row.revenue),
            "margin": int(row.margin),
        }
        for row in rows
    ]


def test_precomputed_summary_matches_live_aggregation_and_backfills():
    _cleanup()
    supervisor = _seed_user("SUPERVISOR", USER_BRANCH)
    token = _token(supervisor, "SUPERVISOR", USER_BRANCH)
    upload_token = _manager_token()
    client = TestClient(app)

    try:
        assert _import(
            client,
            upload_token,
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
    upload_token = _manager_token()
    client = TestClient(app)
    prefix = f"{TEST_PREFIX}ID"
    rows = [
        _row(f"{prefix}A", "P001", 2, 20000),
        _row(f"{prefix}B", "P002", 1, 5000),
    ]

    try:
        first = _import(client, upload_token, rows).json()
        assert first["success"] is True
        assert (first["inserted"], first["updated"]) == (2, 0)
        assert _version(client, token).json()["version"] == 1

        again = _import(client, upload_token, rows).json()
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
    upload_token = _manager_token()
    client = TestClient(app)
    prefix = f"{TEST_PREFIX}UP"

    try:
        assert _import(
            client,
            upload_token,
            [_row(f"{prefix}A", "P001", 2, 20000)],
        ).json()["inserted"] == 1
        assert _version(client, token).json()["version"] == 1

        changed = _import(
            client,
            upload_token,
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
    upload_token = _manager_token()
    client = TestClient(app)
    prefix = f"{TEST_PREFIX}NEW"

    try:
        assert _import(
            client,
            upload_token,
            [_row(f"{prefix}A", "P001", 1, 10000)],
        ).json()["inserted"] == 1

        body = _import(
            client,
            upload_token,
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
    upload_token = _manager_token()
    client = TestClient(app)
    prefix = f"{TEST_PREFIX}DUP"
    rows = [
        _row(f"{prefix}A", "P001", 1, 10000),
        # Same natural key/content: a legitimate duplicate line in the file.
        _row(f"{prefix}A", "P001", 1, 10000),
    ]

    try:
        first = _import(client, upload_token, rows).json()
        assert (first["inserted"], first["updated"]) == (2, 0)
        keys = _dedupe_keys(prefix)
        assert len(keys) == 2
        assert len(set(keys)) == 2

        again = _import(client, upload_token, rows).json()
        assert (again["inserted"], again["updated"]) == (0, 2)
        assert _version(client, token).json()["version"] == 1
        assert _count_rows(prefix) == 2
    finally:
        _cleanup()


def test_legacy_null_dedupe_key_is_migrated_and_matched():
    _cleanup()
    supervisor = _seed_user("SUPERVISOR", USER_BRANCH)
    token = _token(supervisor, "SUPERVISOR", USER_BRANCH)
    upload_token = _manager_token()
    client = TestClient(app)
    prefix = f"{TEST_PREFIX}LEG"
    row = _row(f"{prefix}A", "P001", 1, 10000)

    try:
        assert _import(client, upload_token, [row]).json()["inserted"] == 1
        # Simulate a row imported before Phase 3 added the column.
        with engine.begin() as conn:
            conn.execute(
                text(
                    "UPDATE imported_sales SET dedupe_key = NULL "
                    "WHERE trans_no = :t"
                ),
                {"t": f"{prefix}A"},
            )

        body = _import(client, upload_token, [row]).json()
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
        row_other_branch = _row(
            f"{prefix}A", "P001", 1, 10000, branch=OTHER_BRANCH
        )
        response = _import(
            client, mgr_token, [row, row_other_branch]
        )
        assert response.json()["inserted"] == 2

        assert _summary(client, banjar_token).json()["imported_rows"] == 1
        assert _summary(client, barabai_token).json()["imported_rows"] == 1
        global_summary = _summary(client, mgr_token).json()
        assert global_summary["imported_rows"] == 2
        assert global_summary["total_revenue"] == 20000
    finally:
        _cleanup()


def test_return_import_nets_summaries_upserts_and_deletes_by_month():
    _cleanup()
    manager = _seed_user("MANAGER", None)
    supervisor = _seed_user("SUPERVISOR", USER_BRANCH)
    manager_token = _token(manager, "MANAGER", None)
    supervisor_token = _token(supervisor, "SUPERVISOR", USER_BRANCH)
    client = TestClient(app)
    sales = _upload_excel(
        client,
        manager_token,
        "/sales-imports/excel",
        f"{TEST_PREFIX}v2.xlsx",
        [_v2_row()],
        V2_HEADERS,
    )
    assert sales.status_code == 200, sales.text
    assert sales.json()["success"] is True

    try:
        forbidden_upload = _import_returns(
            client, supervisor_token, _return_row()
        )
        assert forbidden_upload.status_code == 403
        forbidden_delete = client.delete(
            f"{API}/sales-imports/returns/month"
            f"?month={TEST_MONTH}&branch={USER_BRANCH}",
            headers=_headers(supervisor_token),
        )
        assert forbidden_delete.status_code == 403

        first = _import_returns(client, manager_token, _return_row())
        assert first.status_code == 200, first.text
        assert first.json()["inserted"] == 1

        repeated = _import_returns(client, manager_token, _return_row())
        assert repeated.status_code == 200, repeated.text
        assert repeated.json()["inserted"] == 0
        assert repeated.json()["updated"] == 1
        assert repeated.json()["versions"] == []

        summary = _summary(
            client, manager_token, "include=product,sales,customer,divisi,supplier,supplier_retur"
        ).json()
        assert summary["total_revenue"] == 70
        assert summary["total_margin"] == 15
        assert summary["total_retur_revenue"] == 30
        assert summary["total_retur_margin"] == 5
        assert summary["total_retur_rows"] == 1
        assert summary["by_product"][0]["revenue"] == 70
        assert summary["by_sales"][0]["revenue"] == 70
        assert summary["by_customer"][0]["revenue"] == 70
        assert summary["by_divisi"][0]["revenue"] == 70
        assert summary["by_supplier"][0]["revenue"] == 70
        assert summary["by_supplier_retur"][0] == {
            "supplier": "Supplier A",
            "revenue": 30,
            "margin": 5,
            "row_count": 1,
            "supplier_net_revenue": 70,
        }

        corrected = _import_returns(
            client, manager_token, _return_row(total=40, margin=8)
        )
        assert corrected.json()["inserted"] == 0
        assert corrected.json()["updated"] == 1
        corrected_summary = _summary(client, manager_token).json()
        assert corrected_summary["total_revenue"] == 60
        assert corrected_summary["total_margin"] == 12

        moved_supplier = _import_returns(
            client,
            manager_token,
            _return_row(total=40, margin=8, supplier="Supplier B"),
        )
        assert moved_supplier.json()["inserted"] == 1
        assert moved_supplier.json()["unmatched_suppliers"] == ["Supplier B"]
        assert _summary(client, manager_token).json()["total_revenue"] == 20

        deleted = client.delete(
            f"{API}/sales-imports/returns/month"
            f"?month={TEST_MONTH}&branch={USER_BRANCH}",
            headers=_headers(manager_token),
        )
        assert deleted.status_code == 200, deleted.text
        assert deleted.json()["deleted"] == 2
        final_summary = _summary(client, manager_token).json()
        assert final_summary["total_revenue"] == 100
        assert final_summary["total_margin"] == 20
        assert final_summary["total_retur_rows"] == 0
    finally:
        _cleanup()


def test_comparison_returns_months_before_selected_month():
    """Pembanding N bulan adalah bulan *sebelum* bulan terpilih."""
    _cleanup()
    manager = _seed_user("MANAGER", None)
    token = _token(manager, "MANAGER", None)
    client = TestClient(app)

    try:
        # 100 di 2098-12, 200 di 2099-01 (bulan terpilih), 300 di 2099-02
        _import(client, token, [_row("T1", "P001", 1, 100, sale_date="2098-12-15")])
        _import(client, token, [_row("T2", "P001", 1, 200, sale_date="2099-01-15")])
        _import(client, token, [_row("T3", "P001", 1, 300, sale_date="2099-02-15")])

        c3 = _comparison(client, token, "months=3").json()
        assert c3["month"] == "2099-01"
        assert c3["months_with_data"] == 1
        # Bulan sebelum 2099-01: 2098-10, 2098-11, 2098-12 → hanya 2098-12 punya data
        assert [m["month"] for m in c3["monthly"]] == ["2098-12"]
        assert c3["monthly"][0]["net_revenue"] == 100
        assert c3["average_revenue"] == 100

        c12 = _comparison(client, token, "months=12").json()
        assert [m["month"] for m in c12["monthly"]] == ["2098-12"]
    finally:
        _cleanup()


def test_comparison_nets_retur_and_excludes_selected_month():
    """Omzet pembanding sudah dikurangi retur; bulan terpilih ikut diabaikan."""
    _cleanup()
    manager = _seed_user("MANAGER", None)
    token = _token(manager, "MANAGER", None)
    client = TestClient(app)

    try:
        # Bulan terpilih 2099-01: penjualan 1000 + retur 200
        _import(client, token, [_row("T1", "P001", 1, 1000, sale_date="2099-01-10")])
        _import_returns(client, token, _return_row(total=200, margin=0))
        # Bulan sebelumnya 2098-12: penjualan 600, tanpa retur
        _import(client, token, [_row("T2", "P001", 1, 600, sale_date="2098-12-10")])
        # Bulan sebelumnya 2098-11: penjualan 400
        _import(client, token, [_row("T3", "P001", 1, 400, sale_date="2098-11-10")])

        c2 = _comparison(client, token, "months=2").json()
        assert c2["months_with_data"] == 2
        by_month = {m["month"]: m for m in c2["monthly"]}
        assert by_month["2098-12"]["net_revenue"] == 600
        assert by_month["2098-12"]["retur_revenue"] == 0
        assert by_month["2098-11"]["net_revenue"] == 400
        assert c2["total_revenue"] == 1000
        assert c2["average_revenue"] == 500
    finally:
        _cleanup()


def test_comparison_is_branch_scoped_for_non_global_manager():
    """Supervisor hanya melihat data cabangnya sendiri."""
    _cleanup()
    manager = _seed_user("MANAGER", None)
    supervisor = _seed_user("SUPERVISOR", USER_BRANCH)
    manager_token = _token(manager, "MANAGER", None)
    supervisor_token = _token(supervisor, "SUPERVISOR", USER_BRANCH)
    client = TestClient(app)

    try:
        # 500 di BANJARMASIN bulan lalu, 900 di BARABAI bulan lalu
        _import(client, manager_token, [_row("T1", "P001", 1, 500, sale_date="2098-12-10")])
        _import(client, manager_token, [_row("T2", "P002", 1, 900, sale_date="2098-12-10", branch="BARABAI")])

        c_sup = _comparison(client, supervisor_token, "months=1").json()
        assert c_sup["scope"] == USER_BRANCH
        assert c_sup["months_with_data"] == 1
        assert c_sup["monthly"][0]["net_revenue"] == 500

        c_mgr = _comparison(client, manager_token, "months=1&branch=BARABAI").json()
        assert c_mgr["monthly"][0]["net_revenue"] == 900
    finally:
        _cleanup()


def test_comparison_empty_month_returns_zero_average():
    """Tanpa data sama sekali, average 0 dan monthly kosong."""
    _cleanup()
    manager = _seed_user("MANAGER", None)
    token = _token(manager, "MANAGER", None)
    client = TestClient(app)

    try:
        c = _comparison(client, token, "months=6").json()
        assert c["months_with_data"] == 0
        assert c["total_revenue"] == 0
        assert c["average_revenue"] == 0
        assert c["monthly"] == []
    finally:
        _cleanup()


def test_comparison_include_product_gives_average_per_item():
    """Detail produk di pembanding: total dibagi jumlah bulan berdata."""
    _cleanup()
    manager = _seed_user("MANAGER", None)
    token = _token(manager, "MANAGER", None)
    client = TestClient(app)

    try:
        # Produk A: 100 di 2098-11, 200 di 2098-12 → total 300 / 2 bulan = 150
        # Produk B: 300 di 2098-12 saja → total 300 / 2 bulan = 150
        # Bulan terpilih 2099-01 (diekspirkan dari pembanding): 500 di Produk C
        _import(client, token, [_row("T1", "P001", 1, 100, sale_date="2098-11-10")])
        _import(client, token, [_row("T2", "P001", 1, 200, sale_date="2098-12-10")])
        _import(client, token, [_row("T3", "P002", 1, 300, sale_date="2098-12-10")])
        _import(client, token, [_row("T4", "P003", 1, 500, sale_date="2099-01-15")])

        c = _comparison(client, token, "months=3&include=product").json()
        assert c["months_with_data"] == 2
        by_product = {p["product_kode"]: p for p in c["by_product"]}
        assert set(by_product.keys()) == {"P001", "P002"}
        assert by_product["P001"]["revenue"] == 300
        assert by_product["P001"]["average_revenue"] == 150
        assert by_product["P002"]["revenue"] == 300
        assert by_product["P002"]["average_revenue"] == 150
        # Produk C (bulan terpilih) tidak boleh muncul
        assert "P003" not in by_product
    finally:
        _cleanup()


def test_comparison_include_customer_and_divisi():
    """Detail pelanggan dan divisi juga dikembalikan dengan average_revenue."""
    _cleanup()
    manager = _seed_user("MANAGER", None)
    token = _token(manager, "MANAGER", None)
    client = TestClient(app)

    try:
        _import(client, token, [_row("T1", "P001", 1, 200, sale_date="2098-11-10", customer_kode="C001")])
        _import(client, token, [_row("T2", "P001", 1, 300, sale_date="2098-12-10", customer_kode="C002")])
        _import(client, token, [_row("T3", "P001", 1, 100, sale_date="2098-12-10", customer_kode="C001")])

        c = _comparison(client, token, "months=3&include=customer").json()
        assert c["months_with_data"] == 2

        by_customer = {cu["customer_kode"]: cu for cu in c["by_customer"]}
        assert by_customer["C001"]["revenue"] == 300
        assert by_customer["C001"]["average_revenue"] == 150
        assert by_customer["C002"]["revenue"] == 300
        assert by_customer["C002"]["average_revenue"] == 150
    finally:
        _cleanup()


def test_comparison_include_nets_returns():
    """Detail dimensi sudah dikurangi retur."""
    _cleanup()
    manager = _seed_user("MANAGER", None)
    token = _token(manager, "MANAGER", None)
    client = TestClient(app)

    try:
        # Produk A: jual 500 di 2098-12, retur 100 di 2098-12 → net 400 / 1 bulan = 400
        _import(client, token, [_row("T1", "P001", 1, 500, sale_date="2098-12-10")])
        _import_returns(client, token, _return_row(total=100, margin=0, sale_date="2098-12-15", mother_sku=""))

        c = _comparison(client, token, "months=2&include=product").json()
        assert c["months_with_data"] == 1
        by_product = {p["product_kode"]: p for p in c["by_product"]}
        assert by_product["P001"]["net_revenue"] == 400 if "net_revenue" in by_product["P001"] else True
        # read_summary_range returns "revenue" as net already
        assert by_product["P001"]["revenue"] == 400
        assert by_product["P001"]["average_revenue"] == 400
    finally:
        _cleanup()
