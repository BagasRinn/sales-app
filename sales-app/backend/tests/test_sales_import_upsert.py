"""Unit tests for the reusable sales-row upsert helpers (no DB)."""
from datetime import date

from app.services.sales_import_upsert import SalesRow


def _row(**overrides):
    values = {
        "sale_date": date(2026, 1, 15),
        "branch": "BANJARMASIN",
        "trans_no": "T1",
        "product_kode": "P001",
        "customer_kode": "C001",
        "qty": 1,
        "total_amount": 10000,
        "diskon": 0,
        "net_per_unit": 10000,
        "sales_kode": "S1",
        "channel": "REGULER",
    }
    values.update(overrides)
    return SalesRow(**values)


def test_sales_row_to_model_and_diff_roundtrip():
    row = _row()
    model = row.to_model("import-log-id", "base#0")

    assert model.import_log_id == "import-log-id"
    assert model.dedupe_key == "base#0"
    assert model.branch == "BANJARMASIN"
    assert not row.differs_from(model)

    changed = _row(total_amount=25000)
    assert changed.differs_from(model)
    changed.apply_to(model)
    assert model.total_amount == 25000
    assert not changed.differs_from(model)


def test_bookkeeping_fields_do_not_count_as_data_changes():
    row = _row()
    model = row.to_model("first-log", "base#0")

    # A re-import of the same file changes neither the log reference nor the
    # dedupe key, and must not be treated as a data change.
    assert not row.differs_from(model)


def test_sales_row_month_and_base_key():
    row = _row()
    assert row.month == "2026-01"
    assert row.base_key == _row().base_key
    assert row.base_key != _row(branch="BARABAI").base_key
