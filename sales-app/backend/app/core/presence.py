"""Presence (status online / last seen) user untuk pemantauan MANAGER.

Cara kerja: setiap request terautentikasi melewati ``get_current_user`` yang
sudah membaca row ``User`` dari DB. Di titik itu ``users.last_seen_at``
di-update secara **throttled** — paling sering 1× per
``PRESENCE_TOUCH_INTERVAL`` per user — supaya endpoint yang di-poll agresif
(telusuri, auto-refresh dashboard, halaman Status Online sendiri) tidak
memicu banjir UPDATE ke tabel users.
"""
from datetime import datetime, timedelta, timezone
from typing import Optional

# Jarak minimum antar penulisan last_seen_at per user. 1 baris UPDATE per
# menit per user aktif — beban DB bisa diabaikan walau trafik tinggi.
PRESENCE_TOUCH_INTERVAL = timedelta(seconds=60)

# User dianggap "Online" bila request terautentikasinya dalam rentang ini.
PRESENCE_ONLINE_THRESHOLD = timedelta(minutes=5)


def utc_now() -> datetime:
    """Waktu sekarang dalam UTC (naive, konsisten dengan kolom timestamptz
    yang dikonversi SQLAlchemy menjadi naive-UTC saat dibaca kembali)."""
    return datetime.now(timezone.utc).replace(tzinfo=None)


def should_touch_last_seen(
    last_seen_at: Optional[datetime],
    now: Optional[datetime] = None,
    interval: timedelta = PRESENCE_TOUCH_INTERVAL,
) -> bool:
    """True bila last_seen_at perlu ditulis ulang (throttled).

    Null berarti user belum pernah terlihat → tulis. Selisih di bawah
    interval → lewati, agar N request dalam satu menit hanya menulis sekali.
    """
    if last_seen_at is None:
        return True
    current = now or utc_now()
    # Naive-vs-aware guard: kolom timestamptz Postgres dibaca naive-UTC oleh
    # psycopg, tapi jaga-jaga bila sumber lain mengirim nilai aware.
    if last_seen_at.tzinfo is not None:
        last_seen_at = last_seen_at.astimezone(timezone.utc).replace(tzinfo=None)
    return (current - last_seen_at) >= interval


def is_online(
    last_seen_at: Optional[datetime],
    now: Optional[datetime] = None,
    threshold: timedelta = PRESENCE_ONLINE_THRESHOLD,
) -> bool:
    """True bila user aktif dalam ``threshold`` terakhir.

    Null (belum pernah terlihat) bukan online — UI menampilkan label
    "Belum pernah online" yang berbeda dari Offline biasa.
    """
    if last_seen_at is None:
        return False
    current = now or utc_now()
    if last_seen_at.tzinfo is not None:
        last_seen_at = last_seen_at.astimezone(timezone.utc).replace(tzinfo=None)
    return (current - last_seen_at) <= threshold
