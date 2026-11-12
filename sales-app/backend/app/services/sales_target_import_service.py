"""Import monthly revenue targets for the Data Penjualan dashboard."""
import logging
import re
from dataclasses import dataclass
from datetime import date, datetime
from decimal import Decimal, InvalidOperation
from io import BytesIO
from typing import Any, Dict, List, Optional, Tuple

from fastapi import HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session

import openpyxl

from app.core.branch import get_branch_nama, get_valid_branch_codes
from app.models.models import DataPenjualanTarget, ImportLog
from app.services.sales_import_service import (
    MAX_ROW_ERRORS,
    _detect_excel_format,
    _norm_header,
    _read_xls_matrices,
    _to_date,
)
from app.services.db_locks import acquire_advisory_xact_locks

logger = logging.getLogger(__name__)

_ALIASES = {
    "branch": ("cabang", "branch", "kode cabang"),
    "period": (
        "periode",
        "period",
        "bulan",
        "periode yyyy mm",
        "periode penjualan",
    ),
    "sales": (
        "sales",
        "nama sales",
        "nama salesman",
        "salesman",
    ),
    "supplier": (
        "supplier",
        "nama supplier",
        "last supplier",
        "supplier name",
    ),
    "entity": ("entitas",),
    "target": (
        "target",
        "target omzet",
        "target penjualan",
        "target revenue",
        "nilai target",
    ),
}
_MAX_HEADER_SCAN_ROWS = 200
_UPSERT_CHUNK_SIZE = 500
_TARGET_TYPES = ("SALES", "SUPPLIER")


@dataclass(frozen=True)
class _TargetRow:
    branch: str
    period: str
    target_type: str
    name: str
    name_key: str
    value: int
    sheet: str


def normalize_target_name(value: Any) -> str:
    """Normalize entity labels for stable matching across imported files."""
    normalized = re.sub(r"[^A-Z0-9]+", " ", str(value or "").upper())
    return " ".join(normalized.split())


def _column_map(headers: List[Any]) -> Dict[str, int]:
    result: Dict[str, int] = {}
    normalized = [_norm_header(value) for value in headers]
    for field, aliases in _ALIASES.items():
        for index, header in enumerate(normalized):
            if header in aliases:
                result[field] = index
                break
    return result


def _nonempty(row: List[Any]) -> bool:
    return any(value is not None and str(value).strip() for value in row)


def _data_row_count(matrix: List[List[Any]], header_index: int) -> int:
    return sum(1 for row in matrix[header_index + 1 :] if _nonempty(row))


def _classify_sheet(
    sheet_name: str,
    matrix: List[List[Any]],
) -> Optional[Tuple[str, int, Dict[str, int], int]]:
    candidates: List[Tuple[int, int, str, int, Dict[str, int]]] = []
    for header_index, header in enumerate(matrix[:_MAX_HEADER_SCAN_ROWS]):
        columns = _column_map(header)
        if not {"branch", "period", "target"} <= columns.keys():
            continue

        has_sales = "sales" in columns or "entity" in columns
        has_supplier = "supplier" in columns or "entity" in columns
        if not has_sales and not has_supplier:
            continue

        explicit_sales = "sales" in columns
        explicit_supplier = "supplier" in columns
        if explicit_sales and not explicit_supplier:
            target_type = "SALES"
        elif explicit_supplier and not explicit_sales:
            target_type = "SUPPLIER"
        elif explicit_sales and explicit_supplier:
            title = sheet_name.lower()
            if "supplier" in title:
                target_type = "SUPPLIER"
            elif "sales" in title:
                target_type = "SALES"
            else:
                continue
        else:
            title = sheet_name.lower()
            if "supplier" in title:
                target_type = "SUPPLIER"
            elif "sales" in title:
                target_type = "SALES"
            else:
                continue

        row_count = _data_row_count(matrix, header_index)
        score = 4 + int(
            (target_type == "SALES" and explicit_sales)
            or (target_type == "SUPPLIER" and explicit_supplier)
        )
        candidates.append((score, row_count, target_type, header_index, columns))

    if not candidates:
        return None

    _, row_count, target_type, header_index, columns = max(
        candidates, key=lambda candidate: (candidate[0], candidate[1])
    )
    return target_type, header_index, columns, row_count


def _resolve_branch(value: Any) -> Optional[str]:
    raw = str(value or "").strip()
    if not raw:
        return None

    normalized = " ".join(raw.upper().split())
    codes = get_valid_branch_codes()
    if normalized in codes:
        return normalized
    branch_name = normalized.removeprefix("CABANG ")
    for code in codes:
        label = " ".join((get_branch_nama(code) or "").upper().split())
        if label == normalized:
            return code
        if label.removeprefix("CABANG ") == branch_name:
            return code
    return None


def _parse_period(value: Any) -> Optional[str]:
    if isinstance(value, datetime):
        parsed = value.date()
    elif isinstance(value, date):
        parsed = value
    else:
        raw = str(value or "").strip()
        match = re.fullmatch(r"(\d{4})[-/.](\d{1,2})", raw)
        if match:
            year, month = int(match.group(1)), int(match.group(2))
            if 1 <= month <= 12:
                return f"{year:04d}-{month:02d}"
            return None
        parsed = _to_date(value)
        if parsed is None:
            return None
    return parsed.strftime("%Y-%m")


def _parse_target_value(value: Any) -> Optional[int]:
    if value is None or isinstance(value, bool):
        return None
    if isinstance(value, (int, float, Decimal)):
        try:
            decimal_value = Decimal(str(value))
        except InvalidOperation:
            return None
    else:
        raw = str(value).strip()
        if not raw:
            return None
        negative = raw.startswith("(") and raw.endswith(")")
        raw = raw.strip("()")
        raw = re.sub(r"(?i)\b(?:rp|idr)\.?", "", raw)
        raw = raw.replace(" ", "").replace("\u00a0", "")
        if not raw:
            return None

        if "." in raw and "," in raw:
            decimal_separator = "." if raw.rfind(".") > raw.rfind(",") else ","
            thousands_separator = "," if decimal_separator == "." else "."
            raw = raw.replace(thousands_separator, "")
            raw = raw.replace(decimal_separator, ".")
        elif raw.count(".") > 1:
            raw = raw.replace(".", "")
        elif raw.count(",") > 1:
            raw = raw.replace(",", "")
        elif "." in raw or "," in raw:
            separator = "." if "." in raw else ","
            whole, fraction = raw.rsplit(separator, 1)
            if len(fraction) == 3 and whole.isdigit():
                raw = whole + fraction
            else:
                raw = whole + "." + fraction
        try:
            decimal_value = Decimal(raw)
        except InvalidOperation:
            return None
        if negative:
            decimal_value = -decimal_value

    if (
        not decimal_value.is_finite()
        or decimal_value != decimal_value.to_integral_value()
        or decimal_value > 9223372036854775807
    ):
        return None
    return int(decimal_value)


def _read_workbook(
    file_bytes: bytes,
    file_name: str,
) -> List[Tuple[str, List[List[Any]]]]:
    excel_format = _detect_excel_format(file_bytes, file_name)
    if excel_format == "xlsx":
        workbook = openpyxl.load_workbook(
            BytesIO(file_bytes), read_only=True, data_only=True
        )
        try:
            return [
                (
                    worksheet.title,
                    [
                        list(row)
                        for row in worksheet.iter_rows(values_only=True)
                    ],
                )
                for worksheet in workbook.worksheets
            ]
        finally:
            workbook.close()
    return _read_xls_matrices(file_bytes)


def import_sales_targets_from_excel(
    file_bytes: bytes,
    db: Session,
    current_user: Dict[str, Any],
    file_name: str,
) -> Dict[str, Any]:
    try:
        sheets = _read_workbook(file_bytes, file_name)
    except Exception as error:
        logger.warning("[SALES-TARGET-IMPORT] Could not read workbook: %s", error)
        raise HTTPException(
            status_code=400,
            detail=f"Gagal membaca file target Excel: {error}",
        ) from error

    recognized: List[Tuple[str, str, int, Dict[str, int], int, List[List[Any]]]] = []
    for sheet_name, matrix in sheets:
        classification = _classify_sheet(sheet_name, matrix)
        if classification is None:
            continue
        target_type, header_index, columns, row_count = classification
        recognized.append(
            (sheet_name, target_type, header_index, columns, row_count, matrix)
        )
    if not recognized:
        raise HTTPException(
            status_code=400,
            detail=(
                "File target tidak valid: sheet Target Sales / Target Supplier "
                "tidak ditemukan."
            ),
        )

    errors: List[Dict[str, Any]] = []
    skipped = 0
    total_rows = 0
    logs: Dict[str, Dict[str, int]] = {
        target_type.lower(): {
            "rows": 0,
            "inserted": 0,
            "updated": 0,
            "skipped": 0,
        }
        for target_type in _TARGET_TYPES
    }
    sheet_logs: List[Dict[str, Any]] = []
    upserts: Dict[Tuple[str, str, str, str], _TargetRow] = {}

    for sheet_name, target_type, header_index, columns, row_count, matrix in recognized:
        sheet_log = {
            "sheet": sheet_name,
            "type": target_type.lower(),
            "rows": row_count,
            "inserted": 0,
            "updated": 0,
            "skipped": 0,
        }
        logs[target_type.lower()]["rows"] += row_count
        total_rows += row_count
        for row_index in range(header_index + 1, len(matrix)):
            row = matrix[row_index]
            if not _nonempty(row):
                continue

            def value_for(field: str) -> Any:
                index = columns.get(field)
                if index is None and field in ("sales", "supplier"):
                    index = columns.get("entity")
                return row[index] if index is not None and index < len(row) else None

            raw_name = value_for(target_type.lower())
            branch = _resolve_branch(value_for("branch"))
            period = _parse_period(value_for("period"))
            name = str(raw_name or "").strip()
            name_key = normalize_target_name(name)
            target_value = _parse_target_value(value_for("target"))
            reason = None
            if branch is None:
                reason = "Cabang kosong atau tidak dikenal"
            elif period is None or len(period) != 7:
                reason = "Periode tidak valid; gunakan YYYY-MM atau tanggal"
            elif (
                not name
                or len(name) > 200
                or not name_key
                or len(name_key) > 200
            ):
                reason = "Nama sales/supplier kosong atau tidak valid"
            elif target_value is None or target_value < 0:
                reason = "Target harus berupa angka bulat minimal 0"

            if reason:
                skipped += 1
                sheet_log["skipped"] += 1
                logs[target_type.lower()]["skipped"] += 1
                if len(errors) < MAX_ROW_ERRORS:
                    errors.append(
                        {
                            "sheet": sheet_name,
                            "row": row_index + 1,
                            "reason": reason,
                        }
                    )
                continue

            target = _TargetRow(
                branch=branch,
                period=period,
                target_type=target_type,
                name=name,
                name_key=name_key,
                value=target_value,
                sheet=sheet_name,
            )
            upserts[(branch, period, target_type, name_key)] = target

        sheet_logs.append(sheet_log)

    import_log = ImportLog(
        user_id=current_user.get("user_id"),
        nama=current_user.get("nama"),
        import_type="SALES_TARGETS",
        total_rows=total_rows,
        inserted=0,
        updated=0,
        skipped=skipped,
        file_name=file_name,
        branch=current_user.get("branch"),
    )

    inserted = 0
    updated = 0
    try:
        acquire_advisory_xact_locks(
            db,
            (
                f"sales-target:{branch}:{period}:{target_type}"
                for branch, period, target_type, _ in upserts
            ),
        )
        db.add(import_log)
        db.flush()
        grouped: Dict[Tuple[str, str, str], List[_TargetRow]] = {}
        for target in upserts.values():
            grouped.setdefault(
                (target.branch, target.period, target.target_type), []
            ).append(target)

        for (branch, period, target_type), targets in grouped.items():
            for offset in range(0, len(targets), _UPSERT_CHUNK_SIZE):
                target_chunk = targets[offset : offset + _UPSERT_CHUNK_SIZE]
                keys = [target.name_key for target in target_chunk]
                existing_rows = (
                    db.query(DataPenjualanTarget)
                    .filter(
                        DataPenjualanTarget.branch == branch,
                        DataPenjualanTarget.period == period,
                        DataPenjualanTarget.target_type == target_type,
                        DataPenjualanTarget.name_key.in_(keys),
                    )
                    .all()
                )
                existing_by_key = {row.name_key: row for row in existing_rows}
                for target in target_chunk:
                    existing = existing_by_key.get(target.name_key)
                    if existing is None:
                        db.add(
                            DataPenjualanTarget(
                                branch=target.branch,
                                period=target.period,
                                target_type=target.target_type,
                                name=target.name,
                                name_key=target.name_key,
                                target_value=target.value,
                                import_log_id=import_log.id,
                            )
                        )
                        inserted += 1
                        next_action = "inserted"
                    elif (
                        existing.target_value != target.value
                        or existing.name != target.name
                    ):
                        existing.target_value = target.value
                        existing.name = target.name
                        existing.import_log_id = import_log.id
                        updated += 1
                        next_action = "updated"
                    else:
                        next_action = None

                    if next_action:
                        for sheet_log in sheet_logs:
                            if sheet_log["sheet"] == target.sheet:
                                sheet_log[next_action] += 1
                                logs[target_type.lower()][next_action] += 1
                                break

        import_log.inserted = inserted
        import_log.updated = updated
        db.commit()
    except Exception:
        db.rollback()
        logger.exception("[SALES-TARGET-IMPORT] Database upsert failed")
        raise

    return {
        "success": True,
        "total_rows": total_rows,
        "inserted": inserted,
        "updated": updated,
        "skipped": skipped,
        "errors": errors,
        "logs": logs,
        "sheets": sheet_logs,
    }


def read_sales_target_summary(
    db: Session,
    scope: str,
    periods: List[str],
) -> Tuple[List[Dict[str, Any]], List[Dict[str, Any]], Optional[datetime]]:
    query = db.query(DataPenjualanTarget).filter(
        DataPenjualanTarget.period.in_(periods)
    )
    if scope != "GLOBAL":
        query = query.filter(DataPenjualanTarget.branch == scope)

    target_updated_at = query.with_entities(
        func.max(DataPenjualanTarget.updated_at)
    ).scalar()
    grouped = (
        query.with_entities(
            DataPenjualanTarget.target_type,
            DataPenjualanTarget.name_key,
            func.max(DataPenjualanTarget.name).label("name"),
            func.sum(DataPenjualanTarget.target_value).label("value"),
        )
        .group_by(
            DataPenjualanTarget.target_type,
            DataPenjualanTarget.name_key,
        )
        .order_by(
            func.sum(DataPenjualanTarget.target_value).desc(),
            DataPenjualanTarget.name_key.asc(),
        )
        .all()
    )
    sales_targets: List[Dict[str, Any]] = []
    supplier_targets: List[Dict[str, Any]] = []
    for target_type, name_key, name, value in grouped:
        entry = {
            "name": name,
            "name_key": name_key,
            "value": int(value or 0),
        }
        (sales_targets if target_type == "SALES" else supplier_targets).append(entry)
    return sales_targets, supplier_targets, target_updated_at


def read_sales_target_updated_at(
    db: Session,
    scope: str,
    periods: List[str],
) -> Optional[datetime]:
    query = db.query(func.max(DataPenjualanTarget.updated_at)).filter(
        DataPenjualanTarget.period.in_(periods)
    )
    if scope != "GLOBAL":
        query = query.filter(DataPenjualanTarget.branch == scope)
    return query.scalar()
