"""Integration tests for product-stock import (Value Good) endpoints.

Live DB (same style as test_sales_imports_version.py). Test rows are
identified by the ``TEST-PRODSTK-`` file prefix and month ``2099-02``, then
cleaned up in ``finally``.
"""
import uuid
from io import BytesIO

from fastapi.testclient import TestClient
from openpyxl import Workbook
from sqlalchemy import text

from app.core.security import create_access_token
from app.main import _ensure_imported_product_stocks, app
from app.models.database import engine
from app.models.models import Base

TEST_MONTH = "2099-02"
TEST_PREFIX = "TEST-PRODSTK-"
API = "/api/v1"

STOCK_HEADERS = [
    "Cabang", "Kode Barang", "Nama Barang", "Satuan", "Stok Good",
    "Good Amount", "Supplier", "Mother SKU", "Divisi",
]

# Header persis seperti file Master Stock gudang: kode produk = CCODE,
# Mother SKU hanya generalisasi.
CCODE_HEADERS = [
    "Cabang", "CCODE", "Nama Barang", "Satuan", "Stok Good",
    "Good Amount", "Supplier", "Mother SKU", "Divisi",
]

Base.metadata.create_all(bind=engine)
# TestClient dipakai tanpa context manager sehingga lifespan tidak jalan;
# migrasi kolom harus dipanggil eksplisit (idempotent).
_ensure_imported_product_stocks()


def _stock_row(
    branch: str,
    kode: str,
    good_amount: int,
    nama: str | None = None,
    mother_sku: str | None = None,
    divisi: str | None = "SNACK",
    supplier: str = "Supplier A",
    stok_good: int = 1,
) -> list:
    return [
        branch,
        kode,
        nama or f"Produk {kode}",
        "pcs",
        stok_good,
        good_amount,
        supplier,
        mother_sku or "",
        divisi,
    ]


def _xlsx(rows: list[list], headers: list[str]) -> bytes:
    wb = Workbook()
    ws = wb.active
    ws.append(headers)
    for row in rows:
        ws.append(row)
    buf = BytesIO()
    wb.save(buf)
    return buf.getvalue()


def _import(client: TestClient, token: str, rows: list[list], month: str = TEST_MONTH, headers: list[str] | None = None):
    return client.post(
        f"{API}/product-stocks/import-excel",
        params={"month": month},
        headers={"Authorization": f"Bearer {token}"},
        files={
            "file": (
                f"{TEST_PREFIX}stocks.xlsx",
                _xlsx(rows, headers or STOCK_HEADERS),
                "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            )
        },
    )


def test_import_maps_ccode_and_generalizes_via_mother_sku():
    """Header file Master Stock: kode produk = CCODE; Mother SKU = generalisasi.

    Dua CCODE berbeda dengan Mother SKU sama harus jadi satu grup Value Good
    (generalisasi), dan CCODE tidak boleh tertukar dengan kolom Mother SKU.
    """
    _cleanup()
    manager = _seed_user("MANAGER", None)
    token = _token(manager, "MANAGER", None)
    client = TestClient(app)

    rows = [
        ["BANJARMASIN", "62011816", "SARI MURNI 1L", "pcs", 12, 480000, "Supplier A", "SARI MURNI 1L", "MIX"],
        ["BANJARMASIN", "62011817", "SARI MURNI 2L", "pcs", 5, 350000, "Supplier A", "SARI MURNI 1L", "MIX"],
        ["BANJARMASIN", "99000001", "PRODUK TANPA MOTHER", "pcs", 2, 50000, "Supplier A", "", "MIX"],
    ]

    try:
        resp = _import(client, token, rows, headers=CCODE_HEADERS)
        assert resp.status_code == 200, resp.text
        # 2 grup: "SARI MURNI 1L" (generalisasi 2 CCODE) + "99000001".
        assert resp.json()["inserted"] == 2

        s = _summary(client, token).json()
        assert s["total_good_amount"] == 880000  # 830k (grup) + 50k (tanpa mother)
        by_key = {p["key"]: p for p in s["by_product"]}
        assert by_key["SARI MURNI 1L"]["good_amount"] == 830000
        assert by_key["99000001"]["good_amount"] == 50000
    finally:
        _cleanup()


def test_delete_product_stock_month_branch_scoped():
    _cleanup()
    manager = _seed_user("MANAGER", None)
    token = _token(manager, "MANAGER", None)
    client = TestClient(app)

    try:
        _import(
            client,
            token,
            [
                _stock_row("BANJARMASIN", "P1", 100),
                _stock_row("BARABAI", "P2", 200),
            ],
        )

        # Hapus hanya cabang BANJARMASIN.
        resp = client.delete(
            f"{API}/product-stocks/month?month={TEST_MONTH}&branch=BANJARMASIN",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp.status_code == 200, resp.text
        assert resp.json()["deleted"] == 1

        s = _summary(client, token).json()
        assert s["total_good_amount"] == 200  # BARABAI tersisa

        # Hapus semua cabang.
        resp_all = client.delete(
            f"{API}/product-stocks/month?month={TEST_MONTH}&all_branches=true",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp_all.status_code == 200, resp_all.text
        assert resp_all.json()["deleted"] == 1

        s_empty = _summary(client, token).json()
        assert s_empty["total_good_amount"] == 0
        assert s_empty["sku_count"] == 0

        # Paramater ambigu (branch + all_branches) ditolak.
        resp_bad = client.delete(
            f"{API}/product-stocks/month?month={TEST_MONTH}"
            "&branch=BANJARMASIN&all_branches=true",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert resp_bad.status_code == 400
    finally:
        _cleanup()


def test_summary_limit_can_cover_all_products_for_sales_lookup():
    """Ringkasan stok tidak terpotong pada Top 10/50 sales ranking."""
    _cleanup()
    manager = _seed_user("MANAGER", None)
    token = _token(manager, "MANAGER", None)
    client = TestClient(app)

    try:
        rows = [
            _stock_row("BANJARMASIN", f"CCODE-{i:04d}", 10000 - i)
            for i in range(105)
        ]
        response = _import(client, token, rows)
        assert response.status_code == 200, response.text

        summary = _summary(client, token, "limit=5000").json()
        # Lebih banyak dari limit ranking sales yang umum (Top 50), semua
        # baris tersedia untuk Value Stok lookup pada item sales.
        assert len(summary["by_product"]) == 105
    finally:
        _cleanup()


def _summary(client: TestClient, token: str, query: str = ""):
    suffix = f"&{query}" if query else ""
    return client.get(
        f"{API}/product-stocks/summary?month={TEST_MONTH}{suffix}",
        headers={"Authorization": f"Bearer {token}"},
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


def _cleanup() -> None:
    with engine.begin() as conn:
        conn.execute(
            text(
                "DELETE FROM imported_product_stocks WHERE month = :m "
                "OR import_log_id IN "
                "(SELECT id FROM import_logs WHERE file_name LIKE :p)"
            ),
            {"m": TEST_MONTH, "p": f"{TEST_PREFIX}%"},
        )
        conn.execute(
            text("DELETE FROM import_logs WHERE file_name LIKE :p"),
            {"p": f"{TEST_PREFIX}%"},
        )
        conn.execute(
            text("DELETE FROM users WHERE username LIKE :p"),
            {"p": f"{TEST_PREFIX}%"},
        )


def _manager_token() -> str:
    return _token(_seed_user("MANAGER", None), "MANAGER", None)


def test_import_merges_mother_sku_and_replaces_on_reimport():
    _cleanup()
    manager = _seed_user("MANAGER", None)
    token = _token(manager, "MANAGER", None)
    client = TestClient(app)

    try:
        # Cabang 1: SKU-A-1 lewat Mother SKU (beda kapital + spasi -> merge),
        # SKU-A-2 tanpa Mother SKU -> grupnya kode barang sendiri.
        # Cabang 2: Mother SKU sama dengan baris pertama -> merge lintas cabang.
        rows = [
            _stock_row("BANJARMASIN", "SKU-A-1", 300, mother_sku="sku-palm15 "),
            _stock_row("BANJARMASIN", "SKU-A-2", 200, mother_sku=""),
            _stock_row("BARABAI", "SKU-B-1", 100, mother_sku="SKU-PALM15"),
        ]
        resp = _import(client, token, rows)
        assert resp.status_code == 200, resp.text
        body = resp.json()
        assert body["success"] is True
        # BANJARMASIN: 2 grup (SKU-PALM15, SKU-A-2); BARABAI: 1 grup.
        assert body["branches"]["BANJARMASIN"] == 2
        assert body["branches"]["BARABAI"] == 1
        assert body["total_good_amount"] == 600

        s = _summary(client, token).json()
        assert s["scope"] == "GLOBAL"
        assert s["total_good_amount"] == 600
        assert s["sku_count"] == 3
        by_key = {p["key"]: p for p in s["by_product"]}
        assert by_key["SKU-PALM15"]["good_amount"] == 400  # 300 (BJM) + 100 (BRA)
        assert by_key["SKU-A-2"]["good_amount"] == 200

        # Scope cabang: hanya baris cabang itu.
        s_bjm = _summary(client, token, "branch=BANJARMASIN").json()
        assert s_bjm["total_good_amount"] == 500
        assert s_bjm["sku_count"] == 2

        # Re-import cabang BANJARMASIN dengan nilai baru -> replace penuh,
        # BARABAI tidak tersentuh.
        rows2 = [_stock_row("BANJARMASIN", "SKU-A-1", 1000, mother_sku="SKU-PALM15")]
        resp2 = _import(client, token, rows2)
        assert resp2.status_code == 200, resp2.text

        s2 = _summary(client, token).json()
        assert s2["total_good_amount"] == 1100  # 1000 (BJM replace) + 100 (BRA)
        assert s2["sku_count"] == 2
        by_key2 = {p["key"]: p for p in s2["by_product"]}
        assert by_key2["SKU-PALM15"]["good_amount"] == 1100
        assert "SKU-A-2" not in by_key2  # baris lama BJM sudah ter-replace
    finally:
        _cleanup()


def test_import_rejects_non_global_manager_and_bad_rows():
    _cleanup()
    manager = _seed_user("MANAGER", None)
    supervisor = _seed_user("SUPERVISOR", "BANJARMASIN")
    mgr_token = _token(manager, "MANAGER", None)
    sup_token = _token(supervisor, "SUPERVISOR", "BANJARMASIN")
    client = TestClient(app)

    try:
        # User cabang ditolak.
        resp_sup = _import(client, sup_token, [_stock_row("BANJARMASIN", "P1", 100)])
        assert resp_sup.status_code == 403, resp_sup.text

        # Global manager: baris cabang tak dikenal + good amount teks -> skip,
        # baris valid tetap masuk.
        rows = [
            _stock_row("BANJARMASIN", "P1", 100),
            _stock_row("CABANG NGACO", "P2", 200),
            _stock_row("BANJARMASIN", "P3", "bukan angka"),
            _stock_row("BANJARMASIN", "", 300),
        ]
        resp = _import(client, mgr_token, rows)
        assert resp.status_code == 200, resp.text
        body = resp.json()
        assert body["inserted"] == 1
        assert body["skipped"] == 3
        assert len(body["errors"]) == 3

        # Bulan lain tidak tersentuh.
        s_other = client.get(
            f"{API}/product-stocks/summary?month=2099-01",
            headers={"Authorization": f"Bearer {mgr_token}"},
        ).json()
        assert s_other["total_good_amount"] == 0
    finally:
        _cleanup()


def test_import_accepts_long_product_codes():
    """Kode barang di laporan stok nyata bisa deskripsi >50 karakter.

    Kunci grup (mother_sku bila ada, else kode) juga bisa panjang; insert
    tidak boleh gagal StringDataRightTruncation (VARCHAR(50) lama).
    """
    _cleanup()
    manager = _seed_user("MANAGER", None)
    token = _token(manager, "MANAGER", None)
    client = TestClient(app)

    long_kode = "BAYFRESH REED JAVA TEA REFILL 30ML PACK 12 BOTOL EKSPOR"
    long_mother = "MOTHER-" + "X" * 120  # 127 karakter, >100 pun ter-truncasi 200
    try:
        rows = [
            _stock_row("BANJARMASIN", long_kode, 5000, mother_sku=long_mother),
            _stock_row("BANJARMASIN", long_kode + " #2", 7000, mother_sku=long_mother),
        ]
        resp = _import(client, token, rows)
        assert resp.status_code == 200, resp.text
        # Kedua CCODE berbeda dengan Mother SKU sama -> satu grup
        # generalisasi, value dijumlahkan (bukan saling mengganti).
        assert resp.json()["inserted"] == 1

        s = _summary(client, token).json()
        assert s["sku_count"] == 1
        assert s["total_good_amount"] == 12000
        assert s["by_product"][0]["key"].startswith("MOTHER-")
    finally:
        _cleanup()
