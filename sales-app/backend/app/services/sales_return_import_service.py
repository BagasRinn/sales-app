"""Import and idempotent upsert for return rows."""
from __future__ import annotations

import logging
from dataclasses import dataclass, field
from datetime import date, datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional, Sequence, Set, Tuple, Union

from sqlalchemy.orm import Session

from app.core.branch import is_valid_branch
from app.models.models import (
    ImportLog,
    ImportedReturn,
    ImportedSale,
    SyncValidationError,
)
from app.services.db_locks import acquire_advisory_xact_locks
from app.services.sales_import_keys import build_dedupe_key, canonical_return_key
from app.services.sales_import_service import (
    MAX_ROW_ERRORS,
    _add_error,
    _clean_str,
    _iter_sales_excel,
    _resolve_row_branch,
    _to_date,
    _to_int,
)
from app.services.sales_import_versions import (
    GLOBAL_SCOPE,
    bump_versions_for_changes,
    parse_month,
)
from app.services.sales_summary_service import recompute_summary
from app.services.import_progress import ImportProgressReporter

logger = logging.getLogger(__name__)

_RETURN_FIELDS = (
    "branch",
    "sale_date",
    "product_kode",
    "product_nama",
    "mother_sku",
    "divisi",
    "supplier",
    "customer_kode",
    "customer_nama",
    "sales_nama",
    "revenue",
    "margin",
)


@dataclass
class ReturnRow:
    sale_date: date
    revenue: int
    branch: Optional[str] = None
    product_kode: Optional[str] = None
    product_nama: Optional[str] = None
    mother_sku: Optional[str] = None
    divisi: Optional[str] = None
    supplier: Optional[str] = None
    customer_kode: Optional[str] = None
    customer_nama: Optional[str] = None
    sales_nama: Optional[str] = None
    margin: Optional[int] = None

    @property
    def month(self) -> str:
        return self.sale_date.strftime("%Y-%m")

    @property
    def base_key(self) -> str:
        return canonical_return_key(
            branch=self.branch,
            sale_date=self.sale_date,
            product_kode=self.product_kode,
            customer_kode=self.customer_kode,
            sales_nama=self.sales_nama,
            supplier=self.supplier,
        )

    def to_model(self, import_log_id: Any, dedupe_key: str) -> ImportedReturn:
        return ImportedReturn(
            import_log_id=import_log_id,
            dedupe_key=dedupe_key,
            **{name: getattr(self, name) for name in _RETURN_FIELDS},
        )

    def differs_from(self, model: ImportedReturn) -> bool:
        return any(
            getattr(model, name) != getattr(self, name) for name in _RETURN_FIELDS
        )

    def apply_to(self, model: ImportedReturn) -> None:
        for name in _RETURN_FIELDS:
            setattr(model, name, getattr(self, name))
        model.updated_at = datetime.now(timezone.utc)


@dataclass
class _UpsertResult:
    inserted: int = 0
    updated: int = 0
    changed_pairs: Set[Tuple[Optional[str], str]] = field(default_factory=set)


def _lock_keys(pairs: Set[Tuple[Optional[str], str]]) -> List[str]:
    return sorted({
        key
        for branch, month in pairs
        for key in (
            f"sales-import:{GLOBAL_SCOPE}:{month}",
            f"sales-import:{branch or GLOBAL_SCOPE}:{month}",
        )
    })


def _upsert_return_rows(
    db: Session,
    import_log_id: Any,
    rows: Sequence[ReturnRow],
    occurrence_counters: Dict[str, int],
) -> _UpsertResult:
    result = _UpsertResult()
    if not rows:
        return result

    pairs = {(row.branch, row.month) for row in rows}
    acquire_advisory_xact_locks(db, _lock_keys(pairs))

    keyed_rows = []
    for row in rows:
        base = row.base_key
        occurrence = occurrence_counters.get(base, -1) + 1
        occurrence_counters[base] = occurrence
        keyed_rows.append((row, build_dedupe_key(base, occurrence)))

    keys = [key for _, key in keyed_rows]
    existing: Dict[str, ImportedReturn] = {}
    for offset in range(0, len(keys), 500):
        found = (
            db.query(ImportedReturn)
            .filter(ImportedReturn.dedupe_key.in_(keys[offset : offset + 500]))
            .all()
        )
        existing.update(
            {
                row.dedupe_key: row
                for row in found
                if row.dedupe_key is not None
            }
        )

    for row, key in keyed_rows:
        model = existing.get(key)
        if model is None:
            db.add(row.to_model(import_log_id, key))
            result.inserted += 1
            result.changed_pairs.add((row.branch, row.month))
        else:
            result.updated += 1
            if row.differs_from(model):
                row.apply_to(model)
                model.import_log_id = import_log_id
                result.changed_pairs.add((row.branch, row.month))

    db.flush()
    return result


def import_returns_from_excel(
    source: Union[bytes, str, Path],
    db: Session,
    current_user: Dict[str, Any],
    file_name: str,
    progress: Optional[ImportProgressReporter] = None,
) -> Dict[str, Any]:
    """Validate, upsert, and summarize the return rows in an Excel file."""
    import_log = ImportLog(
        user_id=current_user.get("user_id"),
        nama=current_user.get("nama"),
        import_type="SALES_RETUR",
        file_name=file_name,
        branch=current_user.get("branch"),
    )
    db.add(import_log)
    db.flush()

    errors: List[Dict[str, Any]] = []
    occurrence_counters: Dict[str, int] = {}
    batch: List[ReturnRow] = []
    total_rows = inserted = updated = skipped = 0
    changed_pairs: Set[Tuple[Optional[str], str]] = set()
    suppliers_by_pair: Dict[Tuple[Optional[str], str], Dict[str, str]] = {}
    expected_rows = 0

    def _set_expected_rows(total: int) -> None:
        nonlocal expected_rows
        expected_rows = max(0, int(total or 0))

    def flush_batch() -> None:
        nonlocal inserted, updated
        outcome = _upsert_return_rows(
            db, import_log.id, batch, occurrence_counters
        )
        inserted += outcome.inserted
        updated += outcome.updated
        changed_pairs.update(outcome.changed_pairs)
        batch.clear()

    try:
        if progress:
            progress.update(8, "Membaca file Excel...")
        for row_number, row in _iter_sales_excel(
            source, file_name, on_total=_set_expected_rows
        ):
            total_rows += 1
            if progress and total_rows % 500 == 0:
                progress.row_progress(
                    total_rows, expected_rows, "Memproses baris retur", 8, 45
                )
            sale_date = _to_date(row.get("sale_date"))
            branch = _resolve_row_branch(row.get("branch"))
            product_kode = _clean_str(row.get("product_kode"))
            supplier = _clean_str(row.get("supplier"))
            customer_kode = _clean_str(row.get("customer_kode"))
            revenue = _to_int(row.get("total_amount"))
            raw_margin = row.get("margin")
            margin = _to_int(raw_margin)

            reason = None
            if sale_date is None:
                reason = "Tanggal retur tidak valid atau kosong"
            elif not branch or not is_valid_branch(branch):
                reason = "Cabang kosong atau tidak dikenal"
            elif not product_kode:
                reason = "Kode Item wajib diisi"
            elif not supplier:
                reason = "Supplier wajib diisi"
            elif not customer_kode:
                reason = "Kode Pelanggan wajib diisi"
            elif revenue is None or revenue < 0:
                reason = "TOTAL retur tidak valid atau harus >= 0"
            elif raw_margin is not None and _clean_str(raw_margin) and margin is None:
                reason = "MARGIN retur tidak valid"

            if reason:
                skipped += 1
                _add_error(errors, row_number, row, reason)
                continue

            batch.append(
                ReturnRow(
                    branch=branch,
                    sale_date=sale_date,
                    product_kode=product_kode,
                    product_nama=_clean_str(row.get("product_nama")),
                    mother_sku=_clean_str(row.get("mother_sku")),
                    divisi=_clean_str(row.get("divisi")),
                    supplier=supplier,
                    customer_kode=customer_kode,
                    customer_nama=_clean_str(row.get("customer_nama")),
                    sales_nama=_clean_str(row.get("sales_nama")),
                    revenue=revenue,
                    margin=margin,
                )
            )
            pair = (branch, sale_date.strftime("%Y-%m"))
            suppliers_by_pair.setdefault(pair, {}).setdefault(
                " ".join(supplier.upper().split()), supplier
            )
            if len(batch) >= 1000:
                flush_batch()
        flush_batch()
        if progress:
            progress.update(50, "Menyimpan data retur ke database...")
    except Exception as exc:
        logger.exception("[SALES-RETURN-IMPORT] Excel read failed")
        db.rollback()
        failed_log = ImportLog(
            user_id=current_user.get("user_id"),
            nama=current_user.get("nama"),
            import_type="SALES_RETUR",
            file_name=file_name,
            branch=current_user.get("branch"),
        )
        db.add(failed_log)
        db.flush()
        error = f"Gagal membaca file Excel: {exc}"
        db.add(
            SyncValidationError(
                import_log_id=failed_log.id,
                row_number=0,
                sku="",
                reason=error[:255],
            )
        )
        db.commit()
        if progress:
            progress.fail(error)
        return {
            "success": False,
            "total_rows": 0,
            "inserted": 0,
            "updated": 0,
            "skipped": 0,
            "errors": [{"row": 0, "sku": "", "reason": error}],
            "versions": [],
        }

    if total_rows == 0:
        _add_error(errors, 0, {}, "File tidak berisi baris data")
    elif inserted + updated == 0 and not errors:
        _add_error(errors, 0, {}, "Tidak ada baris valid untuk diimport")

    import_log.total_rows = total_rows
    import_log.inserted = inserted
    import_log.updated = updated
    import_log.skipped = skipped
    for error in errors:
        db.add(
            SyncValidationError(
                import_log_id=import_log.id,
                row_number=error.get("row") or 0,
                sku=error.get("sku") or "",
                reason=(error.get("reason") or "")[:255],
            )
        )

    unmatched_suppliers: Set[str] = set()
    for (branch, month), suppliers in suppliers_by_pair.items():
        _, start, month_end = parse_month(month)
        sales_suppliers = {
            " ".join((supplier or "").upper().split())
            for (supplier,) in db.query(ImportedSale.supplier)
            .filter(
                ImportedSale.branch == branch,
                ImportedSale.sale_date >= start.date(),
                ImportedSale.sale_date < month_end.date(),
            )
            .distinct()
            .all()
            if supplier
        }
        unmatched_suppliers.update(
            name
            for normalized, name in suppliers.items()
            if normalized not in sales_suppliers
        )

    versions = bump_versions_for_changes(db, changed_pairs) if changed_pairs else []
    version_by_key = {
        (row["scope"], row["month"]): int(row["version"] or 0)
        for row in versions
    }
    affected = {
        (scope, month)
        for branch, month in changed_pairs
        for scope in (GLOBAL_SCOPE, branch)
        if scope
    }
    ordered_affected = sorted(affected)
    if progress:
        progress.update(60, "Menghitung ulang ringkasan retur...")
    for index, (scope, month) in enumerate(ordered_affected, start=1):
        _, start, month_end = parse_month(month)
        recompute_summary(
            db,
            scope,
            month,
            start,
            month_end,
            version_by_key.get((scope, month), 0),
        )
        if progress:
            progress.update(
                60 + int(35 * index / len(ordered_affected)),
                f"Menghitung ringkasan {scope} {month}...",
            )

    if progress:
        progress.update(97, "Menyelesaikan import retur...")
    db.commit()
    if progress:
        progress.finish()
    return {
        "success": bool(inserted or updated),
        "total_rows": total_rows,
        "inserted": inserted,
        "updated": updated,
        "skipped": skipped,
        "errors": errors,
        "versions": versions,
        "unmatched_suppliers": sorted(unmatched_suppliers),
    }
