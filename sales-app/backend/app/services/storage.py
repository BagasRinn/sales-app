"""
Storage service — support S3-compatible (Tigris, AWS S3) dan Supabase Storage.

Priority:
  1. S3 (jika AWS_ACCESS_KEY_ID + AWS_SECRET_ACCESS_KEY + AWS_BUCKET_NAME diset)
  2. Supabase Storage (fallback, jika SUPABASE_URL + SUPABASE_SERVICE_KEY diset)

Usage: sama seperti supabase_storage.py — interface tidak berubah.
  from app.services.storage import upload_pdf, delete_file
"""

import os
import uuid
import logging
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

# ── Provider resolution ──────────────────────────────────────────────────────


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


# ── Public API (compatible dengan supabase_storage.py) ──────────────────────


def upload_pdf(content: bytes, filename: str) -> str:
    """Upload PDF, return public URL.

    Supports S3/Tigris (优先) dan Supabase Storage (fallback).
    """
    ext = filename.rsplit(".", 1)[-1].lower()
    if ext not in ("pdf",):
        raise ValueError("Hanya file PDF yang diizinkan")

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

    Mendeteksi otomatis apakah URL dari S3 atau Supabase Storage.
    """
    if not public_url:
        return

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
