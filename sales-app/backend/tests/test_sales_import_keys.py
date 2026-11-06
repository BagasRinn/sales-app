"""Unit tests for the deterministic sales-import dedupe keys (no DB)."""
from datetime import date, datetime

import pytest

from app.services.sales_import_keys import (
    build_dedupe_key,
    canonical_sales_key,
    parse_dedupe_key,
)


def _natural(**overrides):
    values = {
        "branch": "BANJARMASIN",
        "sale_date": date(2026, 1, 15),
        "trans_no": "T1",
        "product_kode": "P001",
    }
    values.update(overrides)
    return canonical_sales_key(**values)


def _fingerprint(**overrides):
    values = {
        "branch": "BANJARMASIN",
        "sale_date": date(2026, 1, 15),
        "trans_no": None,
        "product_kode": "P001",
        "customer_kode": "C001",
        "qty": 2,
        "total_amount": 20000,
        "diskon": 0,
        "net_per_unit": 10000,
        "sales_kode": "S1",
        "channel": "REGULER",
    }
    values.update(overrides)
    return canonical_sales_key(**values)


def test_natural_key_normalizes_case_whitespace_and_date_type():
    base = _natural()
    assert _natural(branch=" banjarmasin ", trans_no=" t1 ", product_kode="p001") == base
    assert _natural(sale_date=datetime(2026, 1, 15, 13, 45)) == base


def test_natural_key_changes_with_branch_date_trans_no_or_product():
    base = _natural()
    assert _natural(branch="BARABAI") != base
    assert _natural(sale_date=date(2026, 1, 16)) != base
    assert _natural(trans_no="T2") != base
    assert _natural(product_kode="P002") != base


def test_fingerprint_key_is_stable_and_sensitive_to_financial_fields():
    base = _fingerprint()
    assert _fingerprint() == base
    assert _fingerprint(qty=3) != base
    assert _fingerprint(total_amount=21000) != base
    assert _fingerprint(diskon=1000) != base
    assert _fingerprint(net_per_unit=9000) != base
    assert _fingerprint(customer_kode="C002") != base
    assert _fingerprint(channel="GROSIR") != base


def test_blank_trans_no_falls_back_to_fingerprint():
    assert _fingerprint(trans_no="") == _fingerprint(trans_no=None)
    # A natural key and a fingerprint are never confused.
    assert _natural(trans_no="") != _fingerprint()


def test_build_and_parse_roundtrip():
    base = _natural()
    key = build_dedupe_key(base, 3)
    assert key == f"{base}#3"
    assert parse_dedupe_key(key) == (base, 3)


def test_invalid_keys_are_rejected():
    with pytest.raises(ValueError):
        build_dedupe_key("", 0)
    with pytest.raises(ValueError):
        build_dedupe_key("abc", -1)
    with pytest.raises(ValueError):
        parse_dedupe_key("no-separator")
    with pytest.raises(ValueError):
        parse_dedupe_key("abc#not-a-number")
