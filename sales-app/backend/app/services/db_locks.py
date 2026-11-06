"""Reusable PostgreSQL transaction-scoped advisory locks.

Advisory locks serialize work that must not interleave for the same logical
key (one summary snapshot, one sales-import batch, ...) without taking a
table lock. PostgreSQL releases them automatically when the surrounding
transaction ends, so callers never need an explicit unlock.

The helpers are intentionally tiny: they only wrap ``pg_advisory_xact_lock``
and keep the "sort before locking" rule in one place so two transactions that
need the same set of keys cannot deadlock each other.
"""
from __future__ import annotations

from typing import Iterable

from sqlalchemy import text
from sqlalchemy.orm import Session


def acquire_advisory_xact_lock(db: Session, key: str) -> None:
    """Block until this transaction owns the advisory lock for ``key``."""
    if not key:
        raise ValueError("advisory lock key must not be empty")
    db.execute(
        text("SELECT pg_advisory_xact_lock(hashtext(:key)::bigint)"),
        {"key": key},
    )


def acquire_advisory_xact_locks(db: Session, keys: Iterable[str]) -> None:
    """Acquire several locks in a deterministic order.

    Sorting (and de-duplicating) the keys is what prevents a deadlock when
    two transactions need overlapping but differently-ordered lock sets.
    """
    for key in sorted({key for key in keys if key}):
        acquire_advisory_xact_lock(db, key)
