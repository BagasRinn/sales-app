"""Branch codes, display labels, and runtime cache.

History:
- Originally this module exported hardcoded BRANCH_CODES / BRANCH_LABELS dicts.
- migrate_2026_10_10_01 introduces a `branches` table as the new single source
  of truth. The constants below are kept as FALLBACK only — used when the DB
  table is missing (e.g. before migration runs) or unreachable.
- `load_branches_cache()` is called from main.py lifespan at startup. After
  every branch mutation (POST/PUT/PATCH in app/api/endpoints/branches.py),
  the same function is re-called to refresh this process's view.

Public API (used by auth/users/products/orders/customers/bulletins/
customer_submissions/reports endpoints):
- BRANCH_CODES, BRANCH_LABELS, ROLE_LABELS, is_valid_branch — original API,
  kept backward-compatible.
- get_valid_branch_codes() — DB-active codes, falls back to BRANCH_CODES.
- get_branch_nama(code) — DB label, falls back to BRANCH_LABELS.
- load_branches_cache() — refresh from DB; called at startup and after mutations.
"""
import logging

from sqlalchemy import text
from sqlalchemy.exc import ProgrammingError

from app.models.database import engine

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# Hardcoded constants — kept as FALLBACK for graceful degradation when DB
# is unreachable or branches table doesn't exist yet (pre-migration).
# ---------------------------------------------------------------------------
BRANCH_CODES = ["BANJARMASIN", "BATULICIN", "BARABAI", "PALANGKARAYA", "SAMPIT"]
BRANCH_LABELS = {
    "BANJARMASIN": "Cabang Banjarmasin",
    "BATULICIN": "Cabang Batulicin",
    "BARABAI": "Cabang Barabai",
    "PALANGKARAYA": "Cabang Palangkaraya",
    "SAMPIT": "Cabang Sampit",
}
ROLE_LABELS = {
    "ADMIN": "Admin",
    "SUPERVISOR": "Supervisor",
    "MANAGER": "Manager",
    "SALES": "Sales",
}


# ---------------------------------------------------------------------------
# Runtime cache — populated from DB at startup, refreshed after mutations.
# When None, callers fall back to the constants above.
# ---------------------------------------------------------------------------
_BRANCH_CACHE: dict[str, str] | None = None  # code -> nama
_BRANCH_CODES_CACHE: list[str] | None = None


def load_branches_cache() -> None:
    """Sync. Load active branches from DB into in-memory cache.

    Called from:
    - main.py lifespan at startup (after Base.metadata.create_all).
    - app/api/endpoints/branches.py after every mutation.

    On any failure (table missing, DB unreachable, ProgrammingError), the
    cache stays None and callers fall back to BRANCH_CODES / BRANCH_LABELS.
    This means the system stays functional even if the migration hasn't run
    yet — important for staged deploys.
    """
    global _BRANCH_CACHE, _BRANCH_CODES_CACHE
    try:
        with engine.connect() as conn:
            rows = conn.execute(
                text(
                    "SELECT code, nama FROM branches "
                    "WHERE is_active = true ORDER BY code"
                )
            ).all()
        _BRANCH_CACHE = {r[0]: r[1] for r in rows}
        _BRANCH_CODES_CACHE = [r[0] for r in rows]
        logger.info(
            f"[BRANCH CACHE] Loaded {len(_BRANCH_CACHE)} active branches from DB"
        )
    except ProgrammingError as e:
        # Table doesn't exist yet — pre-migration. Fall back silently.
        logger.warning(
            f"[BRANCH CACHE] branches table not available ({e.__class__.__name__}); "
            f"using hardcoded constants as fallback"
        )
        _BRANCH_CACHE = None
        _BRANCH_CODES_CACHE = None
    except Exception as e:
        logger.error(
            f"[BRANCH CACHE] Failed to load branches from DB: {e}; "
            f"using hardcoded constants as fallback"
        )
        _BRANCH_CACHE = None
        _BRANCH_CODES_CACHE = None


def get_branch_nama(code: str | None) -> str | None:
    """Resolve branch code → display label. Falls back to BRANCH_LABELS."""
    if code is None:
        return None
    if _BRANCH_CACHE is not None and code in _BRANCH_CACHE:
        return _BRANCH_CACHE[code]
    return BRANCH_LABELS.get(code, code)


def get_valid_branch_codes() -> list[str]:
    """Return active branch codes. Falls back to BRANCH_CODES."""
    if _BRANCH_CODES_CACHE is not None:
        return list(_BRANCH_CODES_CACHE)
    return list(BRANCH_CODES)


def is_valid_branch(code: str | None) -> bool:
    """Validate branch code — DB first, fall back to hardcoded list.

    Original signature preserved for backward compat with auth.py / users.py
    call sites. Note: this validates against ACTIVE branches only. Inactive
    branches (is_active=false) won't pass — but they shouldn't accept new
    references anyway. Existing rows referencing inactive branches remain
    untouched (soft-disable doesn't break FK).
    """
    if code is None:
        return False
    return code in get_valid_branch_codes()