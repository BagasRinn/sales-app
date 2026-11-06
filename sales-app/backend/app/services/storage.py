"""
Storage service — support local disk (VPS), S3-compatible (Tigris, AWS S3),
dan Supabase Storage.

Priority:
  1. Local disk (jika STORAGE_PROVIDER=local)
  2. S3 (jika AWS_ACCESS_KEY_ID + AWS_SECRET_ACCESS_KEY + AWS_BUCKET_NAME diset)
  3. Supabase Storage (fallback, jika SUPABASE_URL + SUPABASE_SERVICE_KEY diset)

Local disk dipakai untuk produksi di VPS: file disimpan di LOCAL_STORAGE_DIR
dan disajikan lewat StaticFiles pada path /bulletins. URL publik dibentuk dari
PUBLIC_BASE_URL (mis. https://api.madsalesapp.my.id).

Usage: sama seperti supabase_storage.py — interface tidak berubah.
  from app.services.storage import upload_pdf, delete_file
"""

import os
import uuid
import logging
from pathlib import Path
from typing import Optional

logger = logging.getLogger(__name__)

# ── S3 Config ────────────────────────────────────────────────────────────────

STORAGE_PROVIDER = os.getenv("STORAGE_PROVIDER", "").lower()
AWS_ACCESS_KEY_ID = os.getenv("AWS_ACCESS_KEY_ID", "").strip()
AWS_SECRET_ACCESS_KEY = os.getenv("AWS_SECRET_ACCESS_KEY", "").strip()
AWS_BUCKET_NAME = os.getenv("AWS_BUCKET_NAME", "").strip()
AWS_REGION = os.getenv("AWS_REGION", "ap-southeast-1").strip()
AWS_ENDPOINT_URL = os.getenv("AWS_ENDPOINT_URL", "").strip().rstrip("/")

# ── Supabase Config (fallback) ─────────────────────────────────────────────

SUPABASE_URL = os.getenv("SUPABASE_URL", "").strip().rstrip("/")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_KEY", "").strip()
SUPABASE_BUCKET = os.getenv("SUPABASE_BUCKET", "bulletins")

# ── Local disk Config (VPS) ──────────────────────────────────────────────────

LOCAL_STORAGE_DIR = os.getenv("LOCAL_STORAGE_DIR", "/data/bulletins").strip()
PUBLIC_BASE_URL = os.getenv("PUBLIC_BASE_URL", "").strip().rstrip("/")

# ── Provider resolution ──────────────────────────────────────────────────────


def _use_local() -> bool:
    return STORAGE_PROVIDER in ("local", "filesystem", "fs")


def _use_s3() -> bool:
    return bool(AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY and AWS_BUCKET_NAME)


def _use_supabase() -> bool:
    return bool(SUPABASE_URL and SUPABASE_SERVICE_KEY)


# ── S3 helpers ─────────────────────────────────────────────────────────────


def _get_s3_client():
    try:
        import boto3
    except ImportError:
        raise RuntimeError(
            "boto3 belum terinstall. Jalankan: pip install boto3\n"
            "Atau set STORAGE_PROVIDER=supabase untuk tetap pakai Supabase Storage."
        )

    kwargs = {
        "aws_access_key_id": AWS_ACCESS_KEY_ID,
        "aws_secret_access_key": AWS_SECRET_ACCESS_KEY,
        "region_name": AWS_REGION,
    }
    if AWS_ENDPOINT_URL:
        kwargs["endpoint_url"] = AWS_ENDPOINT_URL

    return boto3.client("s3", **kwargs)


def _s3_key(filename: str) -> str:
    return f"bulletins/{uuid.uuid4()}.{filename.rsplit('.', 1)[-1].lower()}"


def _s3_public_url(key: str) -> str:
    if AWS_ENDPOINT_URL:
        return f"{AWS_ENDPOINT_URL}/{AWS_BUCKET_NAME}/{key}"
    return f"https://{AWS_BUCKET_NAME}.s3.{AWS_REGION}.amazonaws.com/{key}"


# ── Local disk helpers ─────────────────────────────────────────────────────


def _local_dir() -> Path:
    return Path(LOCAL_STORAGE_DIR)


def _local_public_prefix() -> str:
    """Prefix URL publik, tanpa slash di akhir."""
    if PUBLIC_BASE_URL:
        return f"{PUBLIC_BASE_URL}/bulletins"
    # Fallback: URL relatif. Tetap bisa dipakai oleh klien yang memanggil API
    # lewat host yang sama, tapi sebaiknya PUBLIC_BASE_URL selalu diisi.
    return "/bulletins"


def _upload_local(content: bytes, filename: str) -> str:
    directory = _local_dir()
    directory.mkdir(parents=True, exist_ok=True)

    name = f"{uuid.uuid4()}.pdf"
    target = directory / name
    tmp = directory / f".{name}.tmp"

    # Tulis ke file sementara lalu rename atomik, supaya request yang membaca
    # file tidak pernah melihat PDF setengah jadi.
    with open(tmp, "wb") as fh:
        fh.write(content)
        fh.flush()
        os.fsync(fh.fileno())
    os.replace(tmp, target)

    url = f"{_local_public_prefix()}/{name}"
    logger.info("Uploaded to local storage: %s", target)
    return url


def _local_filename_from_url(public_url: str) -> Optional[str]:
    """Ambil nama file dari URL lokal, atau None jika bukan URL kita.

    Hanya nama file dasar yang diterima — mencegah path traversal.
    """
    prefix = f"{_local_public_prefix()}/"
    if not public_url.startswith(prefix):
        return None

    name = public_url[len(prefix):].split("?", 1)[0].split("#", 1)[0]
    if name != Path(name).name or not name.endswith(".pdf"):
        logger.warning("delete_file: nama file lokal tidak valid, skip: %s", public_url)
        return None
    return name


def _delete_local(public_url: str) -> None:
    name = _local_filename_from_url(public_url)
    if not name:
        return

    target = _local_dir() / name
    try:
        target.unlink()
        logger.info("Deleted from local storage: %s", target)
    except FileNotFoundError:
        logger.debug("delete_file: file lokal sudah tidak ada: %s", target)


# ── Public API (compatible dengan supabase_storage.py) ──────────────────────


def upload_pdf(content: bytes, filename: str) -> str:
    """Upload PDF, return public URL.

    Supports local disk (STORAGE_PROVIDER=local), S3/Tigris, dan Supabase
    Storage (fallback).
    """
    ext = filename.rsplit(".", 1)[-1].lower()
    if ext not in ("pdf",):
        raise ValueError("Hanya file PDF yang diizinkan")

    if _use_local():
        return _upload_local(content, filename)

    if _use_s3():
        client = _get_s3_client()
        key = _s3_key(filename)
        client.put_object(
            Bucket=AWS_BUCKET_NAME,
            Key=key,
            Body=content,
            ContentType="application/pdf",
        )
        url = _s3_public_url(key)
        logger.info("Uploaded to S3: %s", url)
        return url

    if _use_supabase():
        return _upload_supabase(content, filename)

    raise RuntimeError(
        "Tidak ada storage provider yang terkonfigurasi.\n"
        "Pilih salah satu:\n"
        "  Local disk — set STORAGE_PROVIDER=local, LOCAL_STORAGE_DIR, PUBLIC_BASE_URL\n"
        "  S3/Tigris  — set AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_BUCKET_NAME\n"
        "  Supabase   — set SUPABASE_URL, SUPABASE_SERVICE_KEY"
    )


def _upload_supabase(content: bytes, filename: str) -> str:
    """Upload ke Supabase Storage via REST API."""
    import httpx

    storage_path = f"{SUPABASE_BUCKET}/bulletins/{uuid.uuid4()}.pdf"

    with httpx.Client(timeout=60) as client:
        res = client.request(
            "POST",
            f"{SUPABASE_URL}/storage/v1/object/{storage_path}",
            headers={
                "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
                "apikey": SUPABASE_SERVICE_KEY,
                "Content-Type": "application/pdf",
                "x-upsert": "false",
            },
            content=content,
        )
        if res.status_code not in (200, 201):
            raise RuntimeError(f"Upload gagal ({res.status_code}): {res.text}")

    return f"{SUPABASE_URL}/storage/v1/object/public/{storage_path}"


def delete_file(public_url: str) -> None:
    """Hapus file berdasarkan public URL-nya.

    Mendeteksi otomatis apakah URL dari local disk, S3, atau Supabase Storage.
    """
    if not public_url:
        return

    if _use_local():
        if _local_filename_from_url(public_url):
            _delete_local(public_url)
            return
        # Bisa jadi file lama dari provider sebelumnya; lanjut ke deteksi lain.

    if _use_s3() and _is_s3_url(public_url):
        _delete_s3(public_url)
        return

    if _use_supabase() and public_url.startswith(SUPABASE_URL):
        _delete_supabase(public_url)
        return

    # URL tidak recognized — skip silently
    logger.debug("delete_file: URL tidak dikenali, skip: %s", public_url)


def _is_s3_url(url: str) -> bool:
    if AWS_ENDPOINT_URL:
        return url.startswith(AWS_ENDPOINT_URL)
    return f"{AWS_BUCKET_NAME}.s3." in url


def _delete_s3(public_url: str) -> None:
    """Hapus dari S3."""
    client = _get_s3_client()

    # Extract key dari URL
    if AWS_ENDPOINT_URL:
        prefix = f"{AWS_ENDPOINT_URL}/{AWS_BUCKET_NAME}/"
    else:
        prefix = f"https://{AWS_BUCKET_NAME}.s3.{AWS_REGION}.amazonaws.com/"

    if not public_url.startswith(prefix):
        return

    key = public_url[len(prefix):]
    client.delete_object(Bucket=AWS_BUCKET_NAME, Key=key)
    logger.info("Deleted from S3: %s", key)


def _delete_supabase(public_url: str) -> None:
    """Hapus dari Supabase Storage via REST API."""
    import httpx

    prefix = f"{SUPABASE_URL}/storage/v1/object/public/"
    if not public_url.startswith(prefix):
        return

    storage_path = public_url[len(prefix):]

    headers = {
        "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
        "apikey": SUPABASE_SERVICE_KEY,
    }

    with httpx.Client(timeout=30) as client:
        res = client.request(
            "DELETE",
            f"{SUPABASE_URL}/storage/v1/object/{storage_path}",
            headers=headers,
        )
        # 200, 204, 404 = sukses
        if res.status_code not in (200, 204, 404):
            raise RuntimeError(f"Hapus file gagal ({res.status_code}): {res.text}")
