"""Set is_active = FALSE untuk supplier tertentu (bulk).

Daftar nama dibaca dari file teks, satu nama per baris, harus SAMA PERSIS
dengan suppliers.name (termasuk ", PT" / ", CV"). Baris kosong dan baris
diawali '#' diabaikan.

Nama yang tidak ada di tabel suppliers dilaporkan, tidak di-silent-skip,
supaya typo kelihatan sebelum update jalan.

    cd backend
    python deactivate_suppliers.py suppliers_inactive.txt --dry-run   # cek dulu
    python deactivate_suppliers.py suppliers_inactive.txt

Rollback: UPDATE suppliers SET is_active = TRUE WHERE name IN (...).
"""
import argparse
from pathlib import Path

from sqlalchemy import bindparam, text

from app.models.database import engine


def load_names(path: str) -> list[str]:
    # utf-8-sig: file yang di-save dari Notepad/PowerShell bisa ada BOM.
    lines = Path(path).read_text(encoding="utf-8-sig").splitlines()
    return [n.strip() for n in lines if n.strip() and not n.strip().startswith("#")]


def main() -> None:
    ap = argparse.ArgumentParser(description="Nonaktifkan supplier (is_active=FALSE)")
    ap.add_argument("names_file", nargs="?", default="suppliers_inactive.txt")
    ap.add_argument("--dry-run", action="store_true", help="cuma tampilkan hasil, tidak update")
    args = ap.parse_args()

    names = load_names(args.names_file)
    if not names:
        raise SystemExit(f"[ERROR] tidak ada nama supplier di {args.names_file}")

    with engine.begin() as conn:
        rows = conn.execute(
            text("SELECT name, is_active FROM suppliers WHERE name IN :names").bindparams(
                bindparam("names", expanding=True)
            ),
            {"names": names},
        ).all()

        found = {r.name: r.is_active for r in rows}
        missing = [n for n in names if n not in found]
        already = [n for n, active in found.items() if not active]
        target = [n for n, active in found.items() if active]

        print(f"[INFO] {len(names)} nama di file | ketemu: {len(found)} | sudah nonaktif: {len(already)} | tidak ketemu: {len(missing)}")
        if missing:
            print("[WARN] Nama berikut tidak ada di tabel suppliers (cek typo):")
            for n in missing:
                print(f"       - {n}")

        if args.dry_run:
            print(f"[DRY-RUN] {len(target)} supplier akan di-set is_active=FALSE:")
            for n in sorted(target):
                print(f"       - {n}")
            return

        if not target:
            print("[OK] Tidak ada yang perlu diubah")
            return

        result = conn.execute(
            text(
                "UPDATE suppliers SET is_active = FALSE, updated_at = NOW() "
                "WHERE name IN :names AND is_active"
            ).bindparams(bindparam("names", expanding=True)),
            {"names": target},
        )
        print(f"[OK] {result.rowcount} supplier di-set is_active=FALSE")


if __name__ == "__main__":
    main()
