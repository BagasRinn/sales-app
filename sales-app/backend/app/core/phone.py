"""Utilitas normalisasi nomor WhatsApp.

Format penyimpanan standar proyek: ``628...`` (kode negara 62, tanpa ``+``,
tanpa spasi/tanda hubung). Dipakai oleh webhook absensi WhatsApp dan oleh
endpoint create/update user agar nomor dari aplikasi selalu seragam.
"""

import re

_NON_DIGIT = re.compile(r"\D")


def normalize_phone_number(phone: str | None) -> str:
    """Kembalikan nomor dalam format ``628...`` (string kosong jika tidak valid).

    Aturan:
    - Hanya digit yang dipertahankan (spasi, ``+``, ``-``, ``()`` dibuang).
    - ``08...`` / ``628...`` / ``6208...`` / ``8...`` → ``628...``.
    - Nomor lain (mis. LID WhatsApp) dikembalikan apa adanya sebagai digit.
    """
    if phone is None:
        return ""

    digits = _NON_DIGIT.sub("", str(phone))
    if not digits:
        return ""

    # Kode negara + trunk zero yang ikut terkirim: 62 0812... → 62812...
    if digits.startswith("620"):
        return "62" + digits[3:]
    # Nomor lokal Indonesia: 0812... → 62812...
    if digits.startswith("0"):
        return "62" + digits[1:]
    # Sudah format internasional.
    if digits.startswith("62"):
        return digits
    # Tanpa awalan apa pun: 812... → 62812...
    if digits.startswith("8"):
        return "62" + digits

    # Bukan nomor telepon Indonesia (mis. LID) — jangan dikarang.
    return digits
