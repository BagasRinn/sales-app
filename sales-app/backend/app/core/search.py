"""Helpers for literal, wildcard-safe ``LIKE`` / ``ILIKE`` search filters.

Search input is always sent to PostgreSQL as a bind parameter, so it can never
break out of the SQL statement. However, ``LIKE``/``ILIKE`` treats ``%`` and
``_`` as wildcards. Without escaping, a search for ``%`` matches every row and
forces a full table scan ("wildcard injection"): correctness and performance
problem, not SQL injection.

Use :func:`ilike_contains` for the common ``column ILIKE '%value%'`` case, or
:func:`contains_pattern` when the caller needs to build the pattern manually
(e.g. ``func.lower(column).like(...)``). Always pass ``escape=LIKE_ESCAPE_CHAR``
when using the pattern directly.
"""

from __future__ import annotations

from typing import Any

# Postgres treats the escape character literally inside the ESCAPE clause.
LIKE_ESCAPE_CHAR = "\\"


def escape_like_literal(value: str | None) -> str:
    """Escape ``%``, ``_`` and the escape character itself for LIKE/ILIKE.

    The result is safe to embed between ``%`` wildcards in a pattern.
    """
    if not value:
        return ""
    return (
        value.replace(LIKE_ESCAPE_CHAR, LIKE_ESCAPE_CHAR * 2)
        .replace("%", LIKE_ESCAPE_CHAR + "%")
        .replace("_", LIKE_ESCAPE_CHAR + "_")
    )


def contains_pattern(value: str | None) -> str:
    """Build a literal ``%value%`` pattern for LIKE/ILIKE ``contains`` search."""
    return f"%{escape_like_literal(value)}%"


def ilike_contains(column: Any, value: str | None):
    """Return ``column ILIKE '%value%'`` with wildcard characters escaped."""
    return column.ilike(contains_pattern(value), escape=LIKE_ESCAPE_CHAR)
