"""Self-check: _bulk_upsert must compile even when rows mix blank and filled
supplier/order_type (bulk INSERT requires identical key set per row).

Run: PYTHONPATH=. python tests/check_bulk_upsert_mixed_supplier.py
(PowerShell: $env:PYTHONPATH='.'; python tests/check_bulk_upsert_mixed_supplier.py)
"""
from collections import namedtuple

from sqlalchemy.dialects import postgresql

import app.services.sheets_sync as sheets_sync
from app.services.sheets_sync import _bulk_upsert

Row = namedtuple("Row", "id branch stok_sistem stok_booking stok_diterima")


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
        self.statements = []

    def query(self, *args, **kwargs):
        return _Query(self._existing_rows)

    def execute(self, stmt):
        stmt.compile(dialect=postgresql.dialect())  # raises CompileError if broken
        self.statements.append(stmt)


def _row(sku, stok, supplier=None, order_type=None):
    return {
        "sku": sku, "nama_barang": f"P-{sku}", "harga": 1000, "stok": stok,
        "kategori": "KAT", "satuan": "PCS",
        "nama_supplier": supplier, "order_type": order_type, "branch": "CBG",
    }


def main():
    sheets_sync.log_stock_change = lambda **kwargs: None
    db = FakeDB([
        Row("UPD-STOCK-SUP", "CBG", 5, 1, 0),     # stock changed, supplier filled
        Row("UPD-STOCK-NOSUP", "CBG", 5, 0, 0),   # stock changed, supplier blank
        Row("UPD-SAME-SUP", "CBG", 7, 0, 0),      # stock same, supplier filled
        Row("UPD-SAME-NOSUP", "CBG", 7, 0, 0),    # stock same, supplier blank
    ])
    rows = [
        _row("NEW-NOSUP", 1),                                  # insert path
        _row("NEW-SUP", 2, "SUP-A", "4P"),                     # insert path
        _row("UPD-STOCK-SUP", 3, "SUP-A", "4P"),
        _row("UPD-STOCK-NOSUP", 4),
        _row("UPD-SAME-SUP", 7, "SUP-B", "REGULER"),
        _row("UPD-SAME-NOSUP", 7),
    ]

    inserted, updated = _bulk_upsert(db, rows, "CBG")

    assert (inserted, updated) == (2, 4), (inserted, updated)
    assert len(db.statements) == 3, len(db.statements)  # to_insert, changed, unchanged
    print("OK: 3 bulk statements compiled with mixed supplier rows")


if __name__ == "__main__":
    main()
