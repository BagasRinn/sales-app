#!/usr/bin/env python3
"""Cek sinkronisasi konstanta cabang di 4 file.

Konstanta cabang sengaja diduplikasi karena ketiga aplikasi Flutter adalah
project terpisah (tidak berbagi package selain datetime_utils). Duplikasi ini
rawan drift: menambah cabang di backend tapi lupa di salah satu klien membuat
dropdown/validasi tidak konsisten.

Script ini TIDAK menyentuh database. Hanya membaca file sumber dan
membandingkan daftar kode + label cabang.

Pemakaian:
    python scripts/check_branch_sync.py

Exit code 0 = sinkron, 1 = ada perbedaan (detail dicetak).
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

BACKEND = ROOT / "sales-app" / "backend" / "app" / "core" / "branch.py"
DART_FILES = [
    ROOT / "sales-app" / "lib" / "core" / "branch.dart",
    ROOT / "sales-app" / "sales_web" / "lib" / "core" / "branch.dart",
    ROOT / "sales-app" / "admin_web" / "lib" / "core" / "branch.dart",
]


def parse_backend(path: Path) -> tuple[list[str], dict[str, str]]:
    text = path.read_text(encoding="utf-8")

    codes_match = re.search(r"BRANCH_CODES\s*=\s*\[(.*?)\]", text, re.S)
    if not codes_match:
        raise ValueError(f"BRANCH_CODES tidak ditemukan di {path}")
    codes = re.findall(r"['\"]([A-Z0-9_]+)['\"]", codes_match.group(1))

    labels_match = re.search(r"BRANCH_LABELS\s*=\s*\{(.*?)\}", text, re.S)
    if not labels_match:
        raise ValueError(f"BRANCH_LABELS tidak ditemukan di {path}")
    labels = dict(re.findall(r"['\"]([A-Z0-9_]+)['\"]\s*:\s*['\"]([^'\"]+)['\"]", labels_match.group(1)))

    return codes, labels


def parse_dart(path: Path) -> tuple[list[str], dict[str, str]]:
    text = path.read_text(encoding="utf-8")

    constants = dict(re.findall(r"static const String (\w+)\s*=\s*'([^']+)';", text))

    all_match = re.search(r"static const List<String> all\s*=\s*\[(.*?)\];", text, re.S)
    if not all_match:
        raise ValueError(f"BranchCode.all tidak ditemukan di {path}")
    names = re.findall(r"(\w+)", all_match.group(1))
    codes = [constants.get(name, name) for name in names]

    labels_block = re.search(r"class BranchLabel\s*\{(.*?)\n\}", text, re.S)
    if not labels_block:
        raise ValueError(f"class BranchLabel tidak ditemukan di {path}")
    labels = dict(re.findall(r"'([A-Z0-9_]+)'\s*:\s*'([^']+)'", labels_block.group(1)))

    return codes, labels


def describe_diff(label: str, expected, actual) -> list[str]:
    problems: list[str] = []
    if isinstance(expected, list):
        missing = [x for x in expected if x not in actual]
        extra = [x for x in actual if x not in expected]
        if missing:
            problems.append(f"  - {label}: kurang {missing}")
        if extra:
            problems.append(f"  - {label}: kelebihan {extra}")
        if not missing and not extra and expected != actual:
            problems.append(f"  - {label}: urutan berbeda ({expected} vs {actual})")
    else:
        for key in sorted(set(expected) | set(actual)):
            if expected.get(key) != actual.get(key):
                problems.append(
                    f"  - {label}[{key}]: backend={expected.get(key)!r}, file={actual.get(key)!r}"
                )
    return problems


def main() -> int:
    backend_codes, backend_labels = parse_backend(BACKEND)
    failures: list[str] = []

    for dart_path in DART_FILES:
        relative = dart_path.relative_to(ROOT)
        codes, labels = parse_dart(dart_path)

        problems = describe_diff("kode", backend_codes, codes)
        problems += describe_diff("label", backend_labels, labels)

        if problems:
            failures.append(f"\n{relative}")
            failures.extend(problems)

    if failures:
        print("KONSTANTA CABANG TIDAK SINKRON")
        print("\n".join(failures))
        print(
            "\nSamakan isi BranchCode.all / BranchLabel.labels di file di atas "
            "dengan sales-app/backend/app/core/branch.py."
        )
        return 1

    print(
        f"OK: {len(backend_codes)} kode cabang sinkron di backend + "
        f"{len(DART_FILES)} file Dart."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
