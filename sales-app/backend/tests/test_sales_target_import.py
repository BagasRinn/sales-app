"""Coverage for Data Penjualan target parsing, permissions, and summaries."""
import uuid
from io import BytesIO

from fastapi.testclient import TestClient
from openpyxl import Workbook
from sqlalchemy import text

from app.core.security import create_access_token
from app.main import app
from app.models.database import engine
from app.models.models import Base
from app.services.sales_target_import_service import (
    _parse_period,
    _parse_target_value,
    normalize_target_name,
)

API = "/api/v1"
TEST_PREFIX = "TEST-TARGET-"
TEST_MONTH = "2099-01"

Base.metadata.create_all(bind=engine)


def _workbook_bytes() -> bytes:
    workbook = Workbook()
    supplier = workbook.active
    supplier.title = "Target Supplier"
    supplier.append(["Cabang", "Periode", "Supplier", "Target"])
    supplier.append(["BANJARMASIN", TEST_MONTH, "Candra Food CV", 100])
    supplier.append(["BARABAI", TEST_MONTH, "CANDRA FOOD, CV", 200])
    supplier.append(["SAMPIT", "2098-12", "Candra Food CV", 75])
    supplier.append(["UNKNOWN", TEST_MONTH, "Invalid Branch Supplier", 5])
    supplier.append(["BANJARMASIN", "2099-01", "Negative Supplier", -1])

    sales = workbook.create_sheet("Target Sales")
    sales.append(["Cabang", "Periode", "Sales", "Target Omzet"])
    sales.append(["BANJARMASIN", TEST_MONTH, "Yusuf Hidayat", 500])

    buffer = BytesIO()
    workbook.save(buffer)
    return buffer.getvalue()


def _cleanup() -> None:
    with engine.begin() as connection:
        connection.execute(
            text(
                "DELETE FROM data_penjualan_targets "
                "WHERE import_log_id IN "
                "(SELECT id FROM import_logs WHERE file_name LIKE :prefix)"
            ),
            {"prefix": f"{TEST_PREFIX}%"},
        )
        connection.execute(
            text("DELETE FROM import_logs WHERE file_name LIKE :prefix"),
            {"prefix": f"{TEST_PREFIX}%"},
        )
        connection.execute(
            text("DELETE FROM users WHERE username LIKE :prefix"),
            {"prefix": f"{TEST_PREFIX}%"},
        )


def _user(role: str, branch: str | None) -> str:
    user_id = str(uuid.uuid4())
    with engine.begin() as connection:
        connection.execute(
            text(
                "INSERT INTO users (id, username, password_hash, role, branch, "
                "is_active, token_version) "
                "VALUES (:id, :username, 'test-hash', :role, :branch, true, 0)"
            ),
            {
                "id": user_id,
                "username": f"{TEST_PREFIX}{role}-{user_id[:8]}",
                "role": role,
                "branch": branch,
            },
        )
    return user_id


def _auth(user_id: str, role: str, branch: str | None) -> dict[str, str]:
    token = create_access_token(
        {
            "sub": user_id,
            "username": "test",
            "role": role,
            "branch": branch,
            "token_version": 0,
        }
    )
    return {"Authorization": f"Bearer {token}"}


def test_target_name_period_and_number_normalization():
    assert normalize_target_name("CANDRA FOOD, CV") == normalize_target_name(
        "Candra Food CV"
    )
    assert normalize_target_name("Yusuf Hidayat") == "YUSUF HIDAYAT"
    assert _parse_period("2099/1") == "2099-01"
    assert _parse_period("2099-01-15") == TEST_MONTH
    assert _parse_target_value("Rp 1.234.000") == 1234000
    assert _parse_target_value(0) == 0
    assert _parse_target_value("-1") == -1
    assert _parse_target_value("12.5") is None


def test_target_import_upserts_and_summary_scopes():
    _cleanup()
    manager_id = _user("MANAGER", None)
    supervisor_id = _user("SUPERVISOR", "BANJARMASIN")
    manager_headers = _auth(manager_id, "MANAGER", None)
    supervisor_headers = _auth(supervisor_id, "SUPERVISOR", "BANJARMASIN")
    file_name = f"{TEST_PREFIX}{uuid.uuid4().hex}.xlsx"
    try:
        with TestClient(app) as client:
            denied = client.post(
                f"{API}/sales-imports/targets/excel",
                headers=supervisor_headers,
                files={"file": (file_name, _workbook_bytes())},
            )
            assert denied.status_code == 403

            invalid_book = Workbook()
            invalid_book.active.append(
                ["Cabang", "Periode", "Supplier", "Nilai"]
            )
            invalid_buffer = BytesIO()
            invalid_book.save(invalid_buffer)
            invalid = client.post(
                f"{API}/sales-imports/targets/excel",
                headers=manager_headers,
                files={
                    "file": (
                        f"{TEST_PREFIX}invalid.xlsx",
                        invalid_buffer.getvalue(),
                    )
                },
            )
            assert invalid.status_code == 400

            imported = client.post(
                f"{API}/sales-imports/targets/excel",
                headers=manager_headers,
                files={"file": (file_name, _workbook_bytes())},
            )
            assert imported.status_code == 200, imported.text
            result = imported.json()
            assert result["total_rows"] == 6
            assert result["inserted"] == 4
            assert result["updated"] == 0
            assert result["skipped"] == 2
            assert [sheet["type"] for sheet in result["sheets"]] == [
                "supplier",
                "sales",
            ]

            repeated = client.post(
                f"{API}/sales-imports/targets/excel",
                headers=manager_headers,
                files={"file": (file_name, _workbook_bytes())},
            )
            assert repeated.status_code == 200
            assert repeated.json()["inserted"] == 0
            assert repeated.json()["updated"] == 0

            global_summary = client.get(
                f"{API}/sales-imports/summary",
                headers=manager_headers,
                params={"month": TEST_MONTH, "include": "supplier,sales"},
            )
            assert global_summary.status_code == 200
            summary = global_summary.json()
            assert summary["sales_targets"] == [
                {
                    "name": "Yusuf Hidayat",
                    "name_key": "YUSUF HIDAYAT",
                    "value": 500,
                }
            ]
            assert summary["supplier_targets"][0]["name_key"] == "CANDRA FOOD CV"
            assert summary["supplier_targets"][0]["value"] == 300
            assert summary["target_updated_at"] is not None

            range_summary = client.get(
                f"{API}/sales-imports/summary",
                headers=manager_headers,
                params={
                    "month": TEST_MONTH,
                    "range_months": 3,
                    "include": "supplier,sales",
                },
            )
            assert range_summary.status_code == 200
            assert range_summary.json()["supplier_targets"][0]["value"] == 375

            branch_summary = client.get(
                f"{API}/sales-imports/summary",
                headers=manager_headers,
                params={
                    "month": TEST_MONTH,
                    "branch": "BANJARMASIN",
                    "include": "supplier,sales",
                },
            )
            assert branch_summary.status_code == 200
            assert branch_summary.json()["supplier_targets"][0]["value"] == 100

            changed_book = Workbook()
            worksheet = changed_book.active
            worksheet.title = "Target Sales"
            worksheet.append(["Cabang", "Periode", "Nama Salesman", "Target"])
            worksheet.append(["BANJARMASIN", TEST_MONTH, "Yusuf Hidayat", 700])
            buffer = BytesIO()
            changed_book.save(buffer)
            changed = client.post(
                f"{API}/sales-imports/targets/excel",
                headers=manager_headers,
                files={
                    "file": (
                        f"{TEST_PREFIX}changed.xlsx",
                        buffer.getvalue(),
                    )
                },
            )
            assert changed.status_code == 200, changed.text
            assert changed.json()["updated"] == 1

            version = client.get(
                f"{API}/sales-imports/version",
                headers=manager_headers,
                params={"month": TEST_MONTH},
            )
            assert version.status_code == 200
            assert version.json()["target_updated_at"] is not None
    finally:
        _cleanup()
