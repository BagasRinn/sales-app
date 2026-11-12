import pytest
from fastapi import HTTPException

from app.services.sales_import_versions import months_in_range


def test_months_in_range_includes_end_month_and_crosses_years():
    assert months_in_range("2026-01", 3) == [
        "2025-11", "2025-12", "2026-01"
    ]
    assert months_in_range("2026-11", 1) == ["2026-11"]


def test_months_in_range_rejects_unsupported_ranges():
    with pytest.raises(HTTPException) as exc_info:
        months_in_range("2026-11", 2)
    assert exc_info.value.status_code == 400
