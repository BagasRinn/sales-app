"""Idempotent upsert for imported sales rows (Phase 3).

The import path used to append every parsed row unconditionally. This module
turns that into a dedupe/upsert operation:

1. Assign deterministic keys to legacy rows that predate dedupe
   (``dedupe_key IS NULL``) inside the affected ``(branch, month)`` pairs.
2. Compute the same deterministic key for every incoming row.
3. Match by key: an existing row is updated only when a data field really
   changed; an identical row counts as ``updated`` but performs no write.
4. Rows with a new key are inserted.

Only ``changed_pairs`` (``(branch, month)`` where a row was inserted or a
field changed) are returned, so the caller bumps versions and rebuilds
summaries only for data that actually moved. A pure re-import of the same
file therefore leaves versions and snapshots untouched.

The module is intentionally independent from HTTP concerns so the import
service and the backfill script can share it.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date
from typing import Any, Dict, Iterable, List, Optional, Sequence, Set, Tuple

from sqlalchemy import and_, or_
from sqlalchemy.orm import Session

from app.models.models import ImportedSale
from app.services.db_locks import acquire_advisory_xact_locks
from app.services.sales_import_keys import (
    DEDUPE_SEPARATOR,
    build_dedupe_key,
    canonical_sales_key,
    parse_dedupe_key,
)
from app.services.sales_import_versions import GLOBAL_SCOPE

# Columns that participate in the upsert comparison. ``import_log_id`` and
# ``dedupe_key`` are bookkeeping fields, not data: a pure re-import must not
# rewrite them.
DATA_FIELDS: Tuple[str, ...] = (
    "branch",
    "trans_no",
    "sale_date",
    "customer_kode",
    "customer_nama",
    "channel",
    "kategori",
    "customer_group",
    "area",
    "alamat",
    "product_kode",
    "product_nama",
    "qty",
    "satuan_jual",
    "qtyi",
    "satuani",
    "diskon",
    "net_per_unit",
    "total_amount",
    "sales_kode",
    "sales_nama",
    "supplier",
)

# Bound the number of bind parameters per query. A 10 MiB Excel file can hold
# tens of thousands of rows; chunking keeps every statement comfortable.
_KEY_CHUNK_SIZE = 500
_BASE_CHUNK_SIZE = 200


@dataclass
class SalesRow:
    """One validated sales row, independent from the ORM model."""

    sale_date: date
    branch: Optional[str] = None
    trans_no: Optional[str] = None
    customer_kode: Optional[str] = None
    customer_nama: Optional[str] = None
    channel: Optional[str] = None
    kategori: Optional[str] = None
    customer_group: Optional[str] = None
    area: Optional[str] = None
    alamat: Optional[str] = None
    product_kode: Optional[str] = None
    product_nama: Optional[str] = None
    qty: Optional[int] = None
    satuan_jual: Optional[str] = None
    qtyi: Optional[int] = None
    satuani: Optional[str] = None
    diskon: Optional[int] = None
    net_per_unit: Optional[int] = None
    total_amount: Optional[int] = None
    sales_kode: Optional[str] = None
    sales_nama: Optional[str] = None
    supplier: Optional[str] = None

    @property
    def month(self) -> str:
        return self.sale_date.strftime("%Y-%m")

    @property
    def base_key(self) -> str:
        return canonical_sales_key(
            branch=self.branch,
            sale_date=self.sale_date,
            trans_no=self.trans_no,
            product_kode=self.product_kode,
            customer_kode=self.customer_kode,
            qty=self.qty,
            total_amount=self.total_amount,
            diskon=self.diskon,
            net_per_unit=self.net_per_unit,
            sales_kode=self.sales_kode,
            channel=self.channel,
        )

    def to_model(self, import_log_id: Any, dedupe_key: str) -> ImportedSale:
        return ImportedSale(
            import_log_id=import_log_id,
            dedupe_key=dedupe_key,
            **{name: getattr(self, name) for name in DATA_FIELDS},
        )

    def apply_to(self, model: ImportedSale) -> None:
        for name in DATA_FIELDS:
            setattr(model, name, getattr(self, name))

    def differs_from(self, model: ImportedSale) -> bool:
        return any(
            getattr(model, name) != getattr(self, name) for name in DATA_FIELDS
        )


@dataclass
class UpsertResult:
    inserted: int = 0
    updated: int = 0
    changed_pairs: Set[Tuple[Optional[str], str]] = field(default_factory=set)
    migrated_legacy_keys: int = 0


def _month_bounds(month: str) -> Tuple[date, date]:
    year, month_num = map(int, month.split("-"))
    start = date(year, month_num, 1)
    end = (
        date(year + 1, 1, 1)
        if month_num == 12
        else date(year, month_num + 1, 1)
    )
    return start, end


def _pair_conditions(
    pairs: Iterable[Tuple[Optional[str], str]],
):
    conditions = []
    for branch, month in pairs:
        start, end = _month_bounds(month)
        condition = and_(
            ImportedSale.sale_date >= start,
            ImportedSale.sale_date < end,
        )
        if branch is None:
            condition = and_(condition, ImportedSale.branch.is_(None))
        else:
            condition = and_(condition, ImportedSale.branch == branch)
        conditions.append(condition)
    return conditions


def _base_for_model(model: ImportedSale) -> str:
    return canonical_sales_key(
        branch=model.branch,
        sale_date=model.sale_date,
        trans_no=model.trans_no,
        product_kode=model.product_kode,
        customer_kode=model.customer_kode,
        qty=model.qty,
        total_amount=model.total_amount,
        diskon=model.diskon,
        net_per_unit=model.net_per_unit,
        sales_kode=model.sales_kode,
        channel=model.channel,
    )


def _max_occurrences(keys: Iterable[str]) -> Dict[str, int]:
    """Map base key -> highest occurrence suffix currently stored."""
    highest: Dict[str, int] = {}
    for key in keys:
        if not key:
            continue
        try:
            base, occurrence = parse_dedupe_key(key)
        except ValueError:
            # Ignore unexpected legacy values instead of aborting a migration.
            continue
        if occurrence > highest.get(base, -1):
            highest[base] = occurrence
    return highest


def _load_max_occurrences_for_condition(db: Session, condition) -> Dict[str, int]:
    keys = (
        db.query(ImportedSale.dedupe_key)
        .filter(ImportedSale.dedupe_key.isnot(None), condition)
        .all()
    )
    return _max_occurrences(key for (key,) in keys)


def _load_max_occurrences_for_bases(
    db: Session, bases: Set[str]
) -> Dict[str, int]:
    """Fallback for rows without a usable month (legacy NULL sale_date)."""
    ordered = sorted(bases)
    highest: Dict[str, int] = {}
    for offset in range(0, len(ordered), _BASE_CHUNK_SIZE):
        chunk = ordered[offset : offset + _BASE_CHUNK_SIZE]
        keys = (
            db.query(ImportedSale.dedupe_key)
            .filter(
                ImportedSale.dedupe_key.isnot(None),
                or_(
                    *[
                        ImportedSale.dedupe_key.like(
                            f"{base}{DEDUPE_SEPARATOR}%"
                        )
                        for base in chunk
                    ]
                ),
            )
            .all()
        )
        for (key,) in keys:
            try:
                base, occurrence = parse_dedupe_key(key)
            except ValueError:
                continue
            if occurrence > highest.get(base, -1):
                highest[base] = occurrence
    return highest


def _assign_keys(
    rows: Sequence[ImportedSale], highest: Dict[str, int]
) -> None:
    for row in rows:
        base = _base_for_model(row)
        occurrence = highest.get(base, -1) + 1
        row.dedupe_key = build_dedupe_key(base, occurrence)
        highest[base] = occurrence


def backfill_dedupe_keys(
    db: Session,
    *,
    pairs: Optional[Iterable[Tuple[Optional[str], str]]] = None,
) -> int:
    """Assign keys to legacy rows that still have ``dedupe_key IS NULL``.

    ``pairs`` limits the work to the ``(branch, month)`` combinations touched
    by an import. When omitted, every remaining NULL row is migrated (used by
    the one-off backfill script). Must run inside the caller's transaction;
    the caller commits.
    """
    if pairs is not None:
        pair_list = list(pairs)
        if not pair_list:
            return 0
        # Serialize with imports/other backfills on the same pairs. Advisory
        # locks are re-entrant for the same transaction, so the import caller
        # may already hold them without any issue.
        acquire_advisory_xact_locks(db, _import_lock_keys(pair_list))
        condition = or_(*_pair_conditions(pair_list))
        rows = (
            db.query(ImportedSale)
            .filter(ImportedSale.dedupe_key.is_(None), condition)
            .order_by(ImportedSale.created_at.asc(), ImportedSale.id.asc())
            .all()
        )
        if not rows:
            return 0
        highest = _load_max_occurrences_for_condition(db, condition)
        _assign_keys(rows, highest)
        db.flush()
        return len(rows)

    rows = (
        db.query(ImportedSale)
        .filter(ImportedSale.dedupe_key.is_(None))
        .order_by(ImportedSale.created_at.asc(), ImportedSale.id.asc())
        .all()
    )
    if not rows:
        return 0
    bases = {_base_for_model(row) for row in rows}
    highest = _load_max_occurrences_for_bases(db, bases)
    _assign_keys(rows, highest)
    db.flush()
    return len(rows)


def _load_rows_by_keys(
    db: Session, keys: Sequence[str]
) -> Dict[str, ImportedSale]:
    found: Dict[str, ImportedSale] = {}
    for offset in range(0, len(keys), _KEY_CHUNK_SIZE):
        chunk = keys[offset : offset + _KEY_CHUNK_SIZE]
        if not chunk:
            continue
        rows = (
            db.query(ImportedSale)
            .filter(ImportedSale.dedupe_key.in_(chunk))
            .all()
        )
        for row in rows:
            if row.dedupe_key:
                found[row.dedupe_key] = row
    return found


def _import_lock_keys(
    pairs: Iterable[Tuple[Optional[str], str]]
) -> List[str]:
    return [
        f"sales-import:{branch or GLOBAL_SCOPE}:{month}"
        for branch, month in pairs
    ]


def upsert_sales_rows(
    db: Session,
    import_log_id: Any,
    rows: Sequence[SalesRow],
) -> UpsertResult:
    """Insert new rows and update changed ones, matching by dedupe key.

    The caller is responsible for the transaction. Locks are transaction
    scoped, and the final ``flush`` makes the new/changed rows visible to the
    summary recompute that runs later in the same transaction.
    """
    result = UpsertResult()
    if not rows:
        return result

    pairs: Set[Tuple[Optional[str], str]] = {
        (row.branch, row.month) for row in rows
    }
    acquire_advisory_xact_locks(db, _import_lock_keys(pairs))

    # Migrate pre-dedupe rows first so the incoming file can match them by key
    # instead of inserting a second copy.
    result.migrated_legacy_keys = backfill_dedupe_keys(db, pairs=pairs)

    counters: Dict[str, int] = {}
    keyed_rows: List[Tuple[SalesRow, str]] = []
    for row in rows:
        base = row.base_key
        occurrence = counters.get(base, -1) + 1
        counters[base] = occurrence
        keyed_rows.append((row, build_dedupe_key(base, occurrence)))

    existing = _load_rows_by_keys(db, [key for _, key in keyed_rows])

    for row, key in keyed_rows:
        pair = (row.branch, row.month)
        model = existing.get(key)
        if model is None:
            model = row.to_model(import_log_id, key)
            db.add(model)
            existing[key] = model
            result.inserted += 1
            result.changed_pairs.add(pair)
            continue

        # A key match means "this file row is already stored". Count it as
        # updated even when nothing changed (the API has no `unchanged`
        # field), but only write/flag a change when a data field differs.
        result.updated += 1
        if row.differs_from(model):
            row.apply_to(model)
            model.import_log_id = import_log_id
            result.changed_pairs.add(pair)

    db.flush()
    return result
