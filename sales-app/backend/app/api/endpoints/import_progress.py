"""Progress polling + dependency for Excel import endpoints."""

from __future__ import annotations

from typing import Iterator, Optional

from fastapi import APIRouter, Depends, Header, HTTPException

from app.core.security import CurrentUser, require_auth
from app.services.import_progress import (
    ImportProgressReporter,
    get_import_progress,
)

router = APIRouter(prefix="/import-progress", tags=["Import Progress"])

JOB_ID_HEADER = "X-Import-Job-Id"


def import_progress_reporter(
    x_import_job_id: Optional[str] = Header(None, alias=JOB_ID_HEADER),
    current_user: CurrentUser = Depends(require_auth),
) -> Iterator[ImportProgressReporter]:
    """Create/finish the job attached to an import POST.

    Endpoints call ``reporter.update(...)`` from their services. The dependency
    fails the job when an exception escapes the endpoint and finishes it when
    the import completes, so clients never keep polling a stale job.
    """
    reporter = ImportProgressReporter(
        (x_import_job_id or "").strip() or None,
        current_user.get("user_id"),
    )
    try:
        yield reporter
    except Exception as exc:  # noqa: BLE001 - report any endpoint failure
        reporter.fail(str(exc))
        raise
    else:
        reporter.finish()


@router.get("/{job_id}")
def read_import_progress(
    job_id: str,
    current_user: CurrentUser = Depends(require_auth),
):
    snapshot = get_import_progress(job_id, current_user.get("user_id"))
    if snapshot is None:
        raise HTTPException(
            status_code=404,
            detail="Progres import tidak ditemukan atau sudah kedaluwarsa",
        )
    return snapshot
