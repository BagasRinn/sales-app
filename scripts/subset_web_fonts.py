#!/usr/bin/env python3
"""Subset font TTF aplikasi Flutter web supaya payload lebih kecil.

Flutter TIDAK men-subset font kustom saat `flutter build web`, jadi file
Plus Jakarta Sans (±129 KB per weight) ikut dikirim utuh ke browser. Script
ini memotong font ke karakter yang benar-benar dipakai aplikasi berbahasa
Indonesia + Latin umum, lalu menyimpannya sebagai file .ttf (Flutter tetap
dapat membacanya di web, Android, iOS, dan desktop).

Pemakaian:
    python scripts/subset_web_fonts.py sales-app/admin_web

Hasil:
    assets/fonts/*.ttf                 -> versi subset (dipakai aplikasi)
    assets/fonts/original/*.ttf        -> arsip file asli (tidak di-bundle)

Kalau nanti aplikasi butuh aksara lain (mis. Mandarin), tambahkan range
Unicode di UNICODE_RANGES lalu jalankan ulang script dari folder `original`.
"""

from __future__ import annotations

import argparse
import glob
import os
import sys

try:
    from fontTools import subset
except ImportError:  # pragma: no cover - pesan ramah untuk mesin baru
    sys.exit(
        "fonttools belum terpasang. Jalankan: python -m pip install fonttools"
    )

# Latin dasar + Latin-1 + Latin Extended-A (nama dengan aksen), tanda baca
# umum, mata uang, panah, dan simbol matematika dasar yang dipakai UI.
UNICODE_RANGES = [
    "U+0020-007E",  # ASCII printable
    "U+00A0-00FF",  # Latin-1 supplement (©, ×, ÷, ±, é, ...)
    "U+0100-017F",  # Latin Extended-A
    "U+2000-206F",  # General punctuation (– — ’ ” • … †)
    "U+20A0-20BF",  # Currency (€, ₹, ...)
    "U+2190-21FF",  # Arrows (→)
    "U+2212",  # Minus sign
    "U+2264-2265",  # ≤ ≥
    "U+2500-257F",  # Box drawing (dipakai tabel/teks terminal)
]

# Fitur OpenType yang dipertahankan. `kern`/`liga`/`calt` menjaga jarak dan
# ligatur agar tampilan sama seperti font asli.
LAYOUT_FEATURES = "kern,liga,calt,ccmp,locl,mark,mkmk,rlig"


def log(message: str) -> None:
    print(f"[subset] {message}")


def collect_chars(app_dir: str) -> set[str]:
    """Semua karakter non-ASCII yang muncul di kode Dart aplikasi."""
    chars: set[str] = set()
    patterns = [
        os.path.join(app_dir, "lib", "**", "*.dart"),
        os.path.join(app_dir, "packages", "**", "lib", "**", "*.dart"),
    ]
    files: list[str] = []
    for pattern in patterns:
        files.extend(glob.glob(pattern, recursive=True))

    for path in files:
        with open(path, encoding="utf-8") as handle:
            for char in handle.read():
                if ord(char) > 0x7F:
                    chars.add(char)
    return chars


def subset_font(source: str, target: str, extra_chars: set[str]) -> None:
    options = subset.Options()
    options.layout_features = LAYOUT_FEATURES.split(",")
    options.name_IDs = ["*"]
    options.name_legacy = True
    options.notdef_outline = True
    options.recommended_glyphs = True
    options.hinting = False
    options.desubroutinize = True
    options.drop_tables += ["DSIG"]

    font = subset.load_font(source, options)
    subsetter = subset.Subsetter(options=options)
    subsetter.populate(unicodes=[ord(c) for c in extra_chars] + _range_unicodes())
    subsetter.subset(font)
    subset.save_font(font, target, options)
    font.close()


def _range_unicodes() -> list[int]:
    unicodes: list[int] = []
    for item in UNICODE_RANGES:
        chunk = item[2:]
        if "-" in chunk:
            start, end = chunk.split("-")
            unicodes.extend(range(int(start, 16), int(end, 16) + 1))
        else:
            unicodes.append(int(chunk, 16))
    return unicodes


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "app",
        help="Folder aplikasi Flutter (contoh: sales-app/admin_web)",
    )
    args = parser.parse_args()

    app_dir = os.path.abspath(args.app)
    font_dir = os.path.join(app_dir, "assets", "fonts")
    original_dir = os.path.join(font_dir, "original")

    if not os.path.isdir(font_dir):
        print(f"[subset] folder font tidak ditemukan: {font_dir}")
        return 1

    fonts = sorted(glob.glob(os.path.join(font_dir, "*.ttf")))
    if not fonts:
        print(f"[subset] tidak ada file .ttf di {font_dir}")
        return 1

    os.makedirs(original_dir, exist_ok=True)
    extra_chars = collect_chars(app_dir)
    log(f"{len(fonts)} font, {len(extra_chars)} karakter non-ASCII dari kode")

    for font_path in fonts:
        name = os.path.basename(font_path)
        original_path = os.path.join(original_dir, name)
        # Simpan asli sekali saja, supaya script bisa dijalankan berkali-kali
        # tanpa menimpa arsip dengan hasil subset.
        if not os.path.exists(original_path):
            os.replace(font_path, original_path)
            source = original_path
            log(f"{name}: arsip asli -> assets/fonts/original/")
        else:
            source = original_path

        before = os.path.getsize(source)
        subset_font(source, font_path, extra_chars)
        after = os.path.getsize(font_path)
        log(f"{name}: {before / 1024:.0f} KB -> {after / 1024:.0f} KB")

    log("selesai")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
