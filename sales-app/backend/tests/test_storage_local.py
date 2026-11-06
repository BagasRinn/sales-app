"""Unit test untuk provider local disk di app.services.storage."""

import pytest

from app.services import storage


@pytest.fixture
def local_storage(tmp_path, monkeypatch):
    """Arahkan provider local ke folder sementara."""
    bulletin_dir = tmp_path / "bulletins"
    monkeypatch.setattr(storage, "STORAGE_PROVIDER", "local")
    monkeypatch.setattr(storage, "LOCAL_STORAGE_DIR", str(bulletin_dir))
    monkeypatch.setattr(storage, "PUBLIC_BASE_URL", "https://api.example.test")
    return bulletin_dir


def test_upload_pdf_writes_file_and_returns_public_url(local_storage):
    content = b"%PDF-1.4\n% test\n%%EOF\n"

    url = storage.upload_pdf(content, "bulletin.pdf")

    assert url.startswith("https://api.example.test/bulletins/")
    name = url.rsplit("/", 1)[-1]
    assert name.endswith(".pdf")
    assert (local_storage / name).read_bytes() == content


def test_upload_pdf_creates_directory_when_missing(local_storage):
    assert not local_storage.exists()

    storage.upload_pdf(b"%PDF-1.4", "bulletin.pdf")

    assert local_storage.is_dir()


def test_delete_file_removes_local_pdf(local_storage):
    url = storage.upload_pdf(b"%PDF-1.4", "bulletin.pdf")
    target = local_storage / url.rsplit("/", 1)[-1]
    assert target.exists()

    storage.delete_file(url)

    assert not target.exists()


def test_delete_file_is_idempotent(local_storage):
    url = storage.upload_pdf(b"%PDF-1.4", "bulletin.pdf")
    storage.delete_file(url)

    # Menghapus dua kali tidak boleh melempar error.
    storage.delete_file(url)


def test_delete_file_rejects_path_traversal(local_storage):
    local_storage.mkdir(parents=True)
    victim = local_storage.parent / "victim.pdf"
    victim.write_bytes(b"%PDF-1.4")

    storage.delete_file("https://api.example.test/bulletins/../victim.pdf")

    assert victim.exists()


def test_delete_file_ignores_foreign_url(local_storage):
    local_storage.mkdir(parents=True)
    keep = local_storage / "keep.pdf"
    keep.write_bytes(b"%PDF-1.4")

    storage.delete_file("https://other.example.test/bulletins/keep.pdf")

    assert keep.exists()


def test_upload_rejects_non_pdf(local_storage):
    with pytest.raises(ValueError):
        storage.upload_pdf(b"not a pdf", "bulletin.txt")


def test_upload_uses_relative_url_without_public_base_url(local_storage, monkeypatch):
    monkeypatch.setattr(storage, "PUBLIC_BASE_URL", "")

    url = storage.upload_pdf(b"%PDF-1.4", "bulletin.pdf")

    assert url.startswith("/bulletins/")
    assert (local_storage / url.rsplit("/", 1)[-1]).exists()
