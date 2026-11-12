"""Deterministic dedupe keys for imported sales rows.

Re-importing the same Excel file must not append the same transactions again.
We therefore give every imported row a stable key:

* Rows that carry a ``trans_no`` use a **natural key** made from
  ``(branch, sale_date, trans_no, product_kode)``.
* Rows without a ``trans_no`` (the in-app report export) use a **content
  fingerprint** made from branch/date/customer/product/qty/amount/discount/
  net/sales/channel.

The base key is an md5 hex digest. A row that is legitimately repeated inside
one file (same natural key or same fingerprint) gets an ``#<occurrence>``
suffix, so identical rows stay separate while a re-import of the same file
matches them one-for-one::

    base#0, base#1, base#2, ...

Keeping this module free of ORM/HTTP imports makes it usable from the import
service, the lazy legacy migration and the backfill script alike.
"""
from __future__ import annotations

import hashlib
import json
from datetime import date, datetime
from typing import Any, Optional, Tuple

DEDUPE_SEPARATOR = "#"
MAX_DEDUPE_KEY_LENGTH = 64


def _text(value: Any) -> str:
    """Normalize a text-ish key component.

    Case and surrounding/inner whitespace differences between exports must not
    create a new row, so everything is upper-cased and whitespace-collapsed.
    Dates are rendered as ISO ``YYYY-MM-DD`` so ``date``/``datetime``/string
    inputs produce the same key.
    """
    if value is None:
        return ""
    if isinstance(value, datetime):
        value = value.date()
    if isinstance(value, date):
        return value.isoformat()
    return " ".join(str(value).strip().upper().split())


def _number(value: Any) -> str:
    if value is None:
        return ""
    try:
        return str(int(value))
    except (TypeError, ValueError):
        return _text(value)


def canonical_sales_key(
    *,
    branch: Optional[str],
    sale_date: Any,
    trans_no: Optional[str],
    product_kode: Optional[str],
    customer_kode: Optional[str] = None,
    qty: Any = None,
    total_amount: Any = None,
    diskon: Any = None,
    net_per_unit: Any = None,
    sales_kode: Optional[str] = None,
    channel: Optional[str] = None,
) -> str:
    """Return the stable base key (md5 hex) for one sales row.

    ``branch`` and ``sale_date`` are part of both key shapes, so the same
    transaction in two branches or two months never collides. A natural key
    deliberately ignores mutable descriptive fields (customer name, address,
    ...) while the fingerprint includes the financial values that identify a
    row when no transaction number is available.
    """
    if _text(trans_no):
        payload = [
            "natural",
            _text(branch),
            _text(sale_date),
            _text(trans_no),
            _text(product_kode),
        ]
    else:
        payload = [
            "fingerprint",
            _text(branch),
            _text(sale_date),
            _text(customer_kode),
            _text(product_kode),
            _number(qty),
            _number(total_amount),
            _number(diskon),
            _number(net_per_unit),
            _text(sales_kode),
            _text(channel),
        ]

    encoded = json.dumps(
        payload,
        ensure_ascii=False,
        separators=(",", ":"),
    ).encode("utf-8")
    return hashlib.md5(encoded).hexdigest()


def canonical_sales_key_v2(
    *,
    branch: Optional[str],
    sale_date: Any,
    customer_kode: Optional[str],
    product_kode: Optional[str],
    sales_nama: Optional[str],
    supplier: Optional[str],
) -> str:
    """Return a stable v2 key that excludes mutable financial/descriptive data."""
    payload = [
        "v2",
        _text(branch),
        _text(sale_date),
        _text(customer_kode),
        _text(product_kode),
        _text(sales_nama),
        _text(supplier),
    ]
    encoded = json.dumps(
        payload,
        ensure_ascii=False,
        separators=(",", ":"),
    ).encode("utf-8")
    return hashlib.md5(encoded).hexdigest()


def canonical_return_key(
    *,
    branch: Optional[str],
    sale_date: Any,
    product_kode: Optional[str],
    customer_kode: Optional[str],
    sales_nama: Optional[str],
    supplier: Optional[str],
) -> str:
    """Return a stable identity key for one imported return row."""
    payload = [
        "return",
        _text(branch),
        _text(sale_date),
        _text(product_kode),
        _text(customer_kode),
        _text(sales_nama),
        _text(supplier),
    ]
    encoded = json.dumps(
        payload,
        ensure_ascii=False,
        separators=(",", ":"),
    ).encode("utf-8")
    return hashlib.md5(encoded).hexdigest()


def build_dedupe_key(base: str, occurrence: int) -> str:
    """Combine a base key with a non-negative occurrence suffix."""
    if not base:
        raise ValueError("base key must not be empty")
    if occurrence < 0:
        raise ValueError("occurrence must be >= 0")
    key = f"{base}{DEDUPE_SEPARATOR}{occurrence}"
    if len(key) > MAX_DEDUPE_KEY_LENGTH:
        raise ValueError("dedupe key too long")
    return key


def parse_dedupe_key(key: str) -> Tuple[str, int]:
    """Split ``<base>#<occurrence>`` back into its parts."""
    base, separator, suffix = key.rpartition(DEDUPE_SEPARATOR)
    if not separator or not base:
        raise ValueError(f"invalid dedupe key: {key!r}")
    try:
        occurrence = int(suffix)
    except ValueError as exc:
        raise ValueError(f"invalid dedupe key occurrence: {key!r}") from exc
    if occurrence < 0:
        raise ValueError(f"invalid dedupe key occurrence: {key!r}")
    return base, occurrence
