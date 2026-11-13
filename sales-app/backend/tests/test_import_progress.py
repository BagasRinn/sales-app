"""Unit tests for the in-memory Excel import progress registry."""

from app.api.endpoints.import_progress import import_progress_reporter
from app.services.import_progress import (
    ImportProgressReporter,
    clear_import_progress,
    get_import_progress,
)


def _start_job(job_id: str, user_id: str = "u-1"):
    generator = import_progress_reporter(
        x_import_job_id=job_id,
        current_user={"user_id": user_id},
    )
    return generator, next(generator)


def test_reporter_without_job_id_is_a_noop():
    reporter = ImportProgressReporter(None, user_id="u-1")

    assert reporter.enabled is False
    reporter.update(50, "Tidak berpengaruh")
    reporter.row_progress(10, 100, "Baris")
    reporter.finish()
    reporter.fail("gagal")

    assert get_import_progress("tanpa-job", "u-1") is None


def test_update_is_monotonic_and_capped_before_finish():
    job_id = "test-monotonic"
    reporter = ImportProgressReporter(job_id, user_id="u-1")
    try:
        snapshot = get_import_progress(job_id, "u-1")
        assert snapshot == {
            "percent": 1,
            "stage": "Menyiapkan import...",
            "done": False,
            "success": None,
            "error": None,
        }

        reporter.update(40, "Memproses")
        reporter.update(20, "Tidak boleh turun")
        assert get_import_progress(job_id, "u-1")["percent"] == 40

        reporter.update(150, "Melewati batas")
        snapshot = get_import_progress(job_id, "u-1")
        assert snapshot["percent"] == 99
        assert snapshot["stage"] == "Melewati batas"
        assert snapshot["done"] is False
    finally:
        clear_import_progress(job_id)


def test_row_progress_reports_counts_and_percentage():
    job_id = "test-row-progress"
    reporter = ImportProgressReporter(job_id, user_id="u-1")
    try:
        reporter.row_progress(1500, 3000, "Memvalidasi", start=20, end=50)
        snapshot = get_import_progress(job_id, "u-1")
        assert snapshot["percent"] == 35
        assert snapshot["stage"] == "Memvalidasi (1.500 / 3.000 baris)"

        # Total tidak diketahui: persen naik perlahan dan berhenti di `end`.
        reporter.row_progress(500000, 0, "Memproses", start=8, end=45)
        snapshot = get_import_progress(job_id, "u-1")
        assert snapshot["percent"] == 45
        assert snapshot["stage"] == "Memproses (500.000 baris)"
    finally:
        clear_import_progress(job_id)


def test_finish_and_fail_mark_the_job_done():
    job_id = "test-finish"
    reporter = ImportProgressReporter(job_id, user_id="u-1")
    try:
        reporter.update(70, "Menyimpan")
        reporter.finish("Import selesai")
        snapshot = get_import_progress(job_id, "u-1")
        assert snapshot == {
            "percent": 100,
            "stage": "Import selesai",
            "done": True,
            "success": True,
            "error": None,
        }

        # Job selesai tidak bisa diubah lagi.
        reporter.update(10, "Terlambat")
        assert get_import_progress(job_id, "u-1")["percent"] == 100
    finally:
        clear_import_progress(job_id)

    failed_job = "test-fail"
    failing = ImportProgressReporter(failed_job, user_id="u-1")
    try:
        failing.fail("File rusak")
        snapshot = get_import_progress(failed_job, "u-1")
        assert snapshot["done"] is True
        assert snapshot["success"] is False
        assert snapshot["error"] == "File rusak"
        assert snapshot["stage"] == "Import gagal"
    finally:
        clear_import_progress(failed_job)


def test_snapshot_is_scoped_to_the_owner():
    job_id = "test-owner"
    ImportProgressReporter(job_id, user_id="u-1")
    try:
        assert get_import_progress(job_id, "u-1") is not None
        assert get_import_progress(job_id, "u-2") is None
    finally:
        clear_import_progress(job_id)


def test_endpoint_dependency_finishes_the_job_on_success():
    job_id = "dep-finish"
    generator, reporter = _start_job(job_id)
    try:
        reporter.update(40, "Memproses")
        try:
            next(generator)
        except StopIteration:
            pass

        snapshot = get_import_progress(job_id, "u-1")
        assert snapshot["percent"] == 100
        assert snapshot["stage"] == "Import selesai"
        assert snapshot["done"] is True
        assert snapshot["success"] is True
    finally:
        clear_import_progress(job_id)


def test_endpoint_dependency_marks_the_job_failed_on_error():
    job_id = "dep-fail"
    generator, _ = _start_job(job_id)
    try:
        try:
            generator.throw(RuntimeError("boom"))
        except RuntimeError:
            pass

        snapshot = get_import_progress(job_id, "u-1")
        assert snapshot["done"] is True
        assert snapshot["success"] is False
        assert snapshot["error"] == "boom"
    finally:
        clear_import_progress(job_id)
