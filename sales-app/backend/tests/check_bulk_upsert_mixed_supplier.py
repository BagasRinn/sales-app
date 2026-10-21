"""Self-check: _bulk_upsert must emit one INSERT per group (insert / changed /
unchanged) with identical keys per row and a NON-NULL order_type for update rows
(Excel blank supplier must preserve the existing value).

Run: PYTHONPATH=. python tests/check_bulk_upsert_mixed_supplier.py
(PowerShell: $env:PYTHONPATH='.'; python tests/check_bulk_upsert_mixed_supplier.py)
"""
import re
from collections import namedtuple

from sqlalchemy.dialects import postgresql

import app.services.sheets_sync as sheets_sync
from app.services.sheets_sync import _bulk_upsert

Row = namedtuple("Row", "id branch stok_sistem stok_booking stok_diterima nama_supplier order_type")


class _Query:
    def __init__(self, rows):
        self._rows = rows

    def filter(self, *args, **kwargs):
        return self

    def with_entities(self, *cols):
        return self

    def all(self):
        return self._rows


class FakeDB:
    def __init__(self, existing_rows):
        self._existing_rows = existing_rows
        self.param_rows = []  # list of dicts, one per compiled statement

    def query(self, *args, **kwargs):
        return _Query(self._existing_rows)

    def execute(self, stmt):
        compiled = stmt.compile(dialect=postgresql.dialect())  # CompileError if keys differ
        row_count = max(
            (int(m.group(1)) for k in compiled.params for m in [re.search(r"_m(\d+)$", k)] if m),
            default=0,
        ) + 1
        self.param_rows.append({
            col: [compiled.params.get(f"{col}_m{i}") for i in range(row_count)]
            for col in ("order_type", "nama_supplier")
        })


def _row(sku, stok, supplier=None, order_type=None):
    return {
        "sku": sku, "nama_barang": f"P-{sku}", "harga": 1000, "stok": stok,
        "kategori": "KAT", "satuan": "PCS",
        "nama_supplier": supplier, "order_type": order_type, "branch": "CBG",
    }


def main():
    sheets_sync.log_stock_change = lambda **kwargs: None
    db = FakeDB([
        Row("UPD-STOCK-SUP", "CBG", 5, 1, 0, "SUP-OLD", "4P"),      # stock changed, Excel supplier blank
        Row("UPD-STOCK-NOSUP", "CBG", 5, 0, 0, None, "REGULER"),     # stock changed, no supplier either
        Row("UPD-SAME-SUP", "CBG", 7, 0, 0, "SUP-OLD", "4P"),        # stock same, Excel supplier blank
        Row("UPD-SAME-NOSUP", "CBG", 7, 0, 0, None, "REGULER"),      # stock same, no supplier either
    ])
    rows = [
        _row("NEW-NOSUP", 1),                       # insert path, blank supplier
        _row("NEW-SUP", 2, "SUP-A", "4P"),           # insert path, filled supplier
        _row("UPD-STOCK-SUP", 3),                    # changed + blank
        _row("UPD-STOCK-NOSUP", 4),                  # changed + blank
        _row("UPD-SAME-SUP", 7),                     # unchanged + blank
        _row("UPD-SAME-NOSUP", 7),                   # unchanged + blank
    ]

    inserted, updated = _bulk_upsert(db, rows, "CBG")

    assert (inserted, updated) == (2, 4), (inserted, updated)
    assert len(db.param_rows) == 3, len(db.param_rows)  # insert, changed, unchanged

    insert_p, changed_p, unchanged_p = db.param_rows

    # order_type must never be NULL (products.order_type is NOT NULL, checked pre-conflict)
    for params in db.param_rows:
        assert all(params["order_type"]), params["order_type"]

    assert insert_p["order_type"] == ["REGULER", "4P"], insert_p["order_type"]
    assert insert_p["nama_supplier"] == [None, "SUP-A"], insert_p["nama_supplier"]

    # blank in Excel keeps the existing supplier / order_type
    assert changed_p["order_type"] == ["4P", "REGULER"], changed_p["order_type"]
    assert changed_p["nama_supplier"] == ["SUP-OLD", None], changed_p["nama_supplier"]
    assert unchanged_p["order_type"] == ["4P", "REGULER"], unchanged_p["order_type"]
    assert unchanged_p["nama_supplier"] == ["SUP-OLD", None], unchanged_p["nama_supplier"]

    print("OK: mixed supplier batches compile with non-null order_type")


if __name__ == "__main__":
    main()
