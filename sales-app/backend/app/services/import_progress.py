"""In-memory progress registry for long-running Excel imports.

The import endpoints are synchronous, so the client only receives the final
result when the whole file has been processed. This registry lets the client
poll a real percentage while the POST is still running.

Progress is intentionally ephemeral (no database writes). Entries expire after
[_JOB_TTL_SECONDS]; a client may safely poll before the job exists and treat a
404 as "still uploading".

Deployment note: the registry lives in process memory, so it requires a single
backend worker (the provided Dockerfile runs one uvicorn process).
"""

from __future__ import annotations

import threading
import time
from typing import Any, Dict, Optional


_JOB_TTL_SECONDS = 15 * 60
_lock = threading.Lock()
_jobs: Dict[str, Dict[str, Any]] = {}


def _purge_locked(now: float) -> None:
    expired = [
        job_id
        for job_id, job in _jobs.items()
        if now - float(job.get("updated_at") or 0) > _JOB_TTL_SECONDS
    ]
    for job_id in expired:
        _jobs.pop(job_id, None)


def _public_snapshot(job: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "percent": int(job["percent"]),
        "stage": job["stage"],
        "done": bool(job["done"]),
        "success": job["success"],
        "error": job["error"],
    }


class ImportProgressReporter:
    """Tiny no-op-safe facade used by endpoints and import services.

    When ``job_id`` is missing (older clients / direct service calls in tests)
    every method is a no-op, so instrumentation never changes existing
    behaviour.
    """

    def __init__(self, job_id: Optional[str], user_id: Any):
        self.job_id = job_id
        self.user_id = user_id
        if not job_id:
            return
        now = time.monotonic()
        with _lock:
            _purge_locked(now)
            _jobs[job_id] = {
                "user_id": user_id,
                "percent": 1,
                "stage": "Menyiapkan import...",
                "done": False,
                "success": None,
                "error": None,
                "updated_at": now,
            }

    @property
    def enabled(self) -> bool:
        return bool(self.job_id)

    def update(self, percent: int, stage: str) -> None:
        if not self.job_id:
            return
        now = time.monotonic()
        with _lock:
            job = _jobs.get(self.job_id)
            if job is None or job["done"]:
                return
            job["percent"] = max(int(job["percent"]), min(99, int(percent)))
            job["stage"] = stage
            job["updated_at"] = now

    def row_progress(
        self,
        current: int,
        total: int,
        stage: str,
        start: int = 5,
        end: int = 50,
    ) -> None:
        """Report progress inside a row-processing loop.

        ``total`` may be unknown (0); in that case the percentage grows slowly
        by row count and caps at ``end`` while the message keeps counting rows.
        """
        if not self.job_id:
            return
        if total and total > 0:
            ratio = max(0.0, min(1.0, current / total))
            percent = start + int((end - start) * ratio)
            detail = f"{current:,} / {total:,} baris".replace(",", ".")
        else:
            percent = min(end, start + current // 1000)
            detail = f"{current:,} baris".replace(",", ".")
        self.update(percent, f"{stage} ({detail})")

    def finish(self, stage: str = "Import selesai") -> None:
        if not self.job_id:
            return
        now = time.monotonic()
        with _lock:
            job = _jobs.get(self.job_id)
            if job is None or job["done"]:
                return
            job.update(
                percent=100,
                stage=stage,
                done=True,
                success=True,
                error=None,
                updated_at=now,
            )

    def fail(self, message: str) -> None:
        if not self.job_id:
            return
        now = time.monotonic()
        with _lock:
            job = _jobs.get(self.job_id)
            if job is None:
                return
            job.update(
                stage="Import gagal",
                done=True,
                success=False,
                error=(message or "Import gagal")[:300],
                updated_at=now,
            )


def get_import_progress(
    job_id: str,
    user_id: Any,
) -> Optional[Dict[str, Any]]:
    """Return a snapshot for ``job_id`` owned by ``user_id`` (None otherwise)."""
    now = time.monotonic()
    with _lock:
        _purge_locked(now)
        job = _jobs.get(job_id)
        if job is None or job.get("user_id") != user_id:
            return None
        return _public_snapshot(job)


def clear_import_progress(job_id: str) -> None:
    """Remove a job (used by tests)."""
    with _lock:
        _jobs.pop(job_id, None)
