"""Supabase Storage service — upload dan hapus file PDF bulletin."""
import os
import uuid
import httpx

SUPABASE_URL = os.getenv("SUPABASE_URL", "").strip().rstrip("/")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_KEY", "").strip()
BUCKET = os.getenv("SUPABASE_BUCKET", "bulletins")


def _headers() -> dict:
    return {"Authorization": f"Bearer {SUPABASE_SERVICE_KEY}", "apikey": SUPABASE_SERVICE_KEY}


def upload_pdf(content: bytes, filename: str) -> str:
    """Upload PDF ke Supabase Storage, return public URL."""
    if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
        raise RuntimeError("SUPABASE_URL dan SUPABASE_SERVICE_KEY harus diset")

    ext = filename.rsplit(".", 1)[-1].lower()
    if ext not in ("pdf",):
        raise ValueError("Hanya file PDF yang diizinkan")

    storage_path = f"{BUCKET}/bulletins/{uuid.uuid4()}.{ext}"

    with httpx.Client(timeout=60) as client:
        # Upload ke Supabase Storage (REST API)
        res = client.request(
            "POST",
            f"{SUPABASE_URL}/storage/v1/object/{storage_path}",
            headers={
                ** _headers(),
                "Content-Type": "application/pdf",
                "x-upsert": "false",
            },
            content=content,
        )
        if res.status_code not in (200, 201):
            raise RuntimeError(f"Upload gagal ({res.status_code}): {res.text}")

    # Public URL
    return f"{SUPABASE_URL}/storage/v1/object/public/{storage_path}"


def delete_file(public_url: str) -> None:
    """Hapus file dari Supabase Storage berdasarkan public URL-nya."""
    if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
        return  # Tidak ada storage configured — skip

    if not public_url or not public_url.startswith(SUPABASE_URL):
        return  # Bukan file dari storage kita — skip

    # Ekstrak storage path dari public URL
    prefix = f"{SUPABASE_URL}/storage/v1/object/public/"
    if not public_url.startswith(prefix):
        return

    storage_path = public_url[len(prefix):]

    with httpx.Client(timeout=30) as client:
        res = client.request(
            "DELETE",
            f"{SUPABASE_URL}/storage/v1/object/{storage_path}",
            headers=_headers(),
        )
        # 200, 404 = sukses (404 = sudah tidak ada)
        if res.status_code not in (200, 204, 404):
            raise RuntimeError(f"Hapus file gagal ({res.status_code}): {res.text}")
