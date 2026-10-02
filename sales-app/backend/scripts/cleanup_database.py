"""Wipe database, keep 3 default users.

Default users (auto-seeded kalau belum ada):
  - admin.default    (ADMIN)    password: admin.default
  - manager.default  (MANAGER)  password: manager.default
  - sales.default    (SALES)    password: sales.default

CARA PAKAI:
    cd sales-app/backend
    python scripts/cleanup_database.py

Script ini:
  1. Verifikasi 3 user default ada (auto-seed kalau missing).
  2. Tampilin row counts SEBELUM wipe.
  3. Prompt konfirmasi — harus ketik YES persis.
  4. Wipe 11 tabel transaksional + master non-user dalam 1 transaksi.
  5. DELETE user lain (selain 3 default).
  6. Bump token_version 3 user default → invalidate sesi lama.
  7. Tampilin row counts SESUDAH wipe.

Semua step gagal → exit non-zero, tidak ada perubahan ke DB.
"""
import sys
import os

# Tambah parent dir supaya bisa import app.* ketika script dijalankan dari mana saja
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from sqlalchemy import text
from app.models.database import engine
from app.models.models import User
from app.core.security import get_password_hash


KEEP_USERS = ["admin.default", "manager.default", "sales.default"]
DEFAULT_USER_SEED = [
    # (username, password, role)
    ("admin.default",   "admin.default",   "ADMIN"),
    ("manager.default", "manager.default", "MANAGER"),
    ("sales.default",   "sales.default",   "SALES"),
]
WIPE_TABLES = [
    "order_items",
    "orders",
    "stok_log",
    "sync_validation_errors",
    "import_logs",
    "customer_registration_submissions",
    "customers",
    "products",
    "sales_targets",
    "bulletin_dismisses",
    "bulletins",
]
COUNT_TABLES = WIPE_TABLES + ["users"]


def _format_url(url: str) -> str:
    """Hide password di DATABASE_URL untuk display."""
    if "@" in url and ":" in url.split("@")[0]:
        prefix, rest = url.split("@", 1)
        if ":" in prefix.split("//")[-1]:
            scheme_user, host = prefix.rsplit(":", 1)
            user = scheme_user.split("//")[-1]
            return f"{scheme_user.split('//')[0]}//{user}:****@{host}"
    return url


def _get_row_counts(conn) -> dict:
    counts = {}
    for table in COUNT_TABLES:
        r = conn.execute(text(f"SELECT COUNT(*) FROM {table}"))
        counts[table] = r.scalar()
    return counts


def _print_counts(label: str, counts: dict) -> None:
    print(f"\n[{label}]")
    for table in COUNT_TABLES:
        print(f"  {table:<32} {counts[table]}")


def _ensure_default_users(conn) -> None:
    """Kalau salah satu dari 3 default user belum ada, auto-seed.
    Idempotent — kalau sudah ada, skip."""
    rows = conn.execute(
        text("SELECT username FROM users WHERE username = ANY(:names)"),
        {"names": KEEP_USERS},
    ).fetchall()
    existing = {row[0] for row in rows}

    for username, password, role in DEFAULT_USER_SEED:
        if username in existing:
            print(f"  ~ {username} ({role}) — sudah ada")
            continue
        user = User(
            username=username,
            password_hash=get_password_hash(password),
            role=role,
            nama=f"Default {role.title()}",
            is_active=True,
        )
        conn.add(user)
        conn.flush()
        print(f"  + {username} ({role}) — di-seed (password: {password})")


def _prompt_yes() -> bool:
    print("\n" + "=" * 60)
    print("  ⚠  PERINGATAN: SEMUA DATA AKAN DIHAPUS")
    print("  Yang disisakan: 3 user default (admin/manager/sales)")
    print("=" * 60)
    try:
        answer = input("\nKetik YES (persis) untuk lanjut: ").strip()
    except EOFError:
        return False
    return answer == "YES"


def main() -> int:
    url = os.getenv("DATABASE_URL", "")
    print(f"Database: {_format_url(url)}")
    print(f"\n[1/4] Pre-flight: memastikan 3 user default ada...")

    try:
        with engine.begin() as conn:
            _ensure_default_users(conn)
    except Exception as e:
        print(f"  [ERROR] Pre-flight gagal: {e}")
        return 1

    print("\n[2/4] Row counts sebelum wipe...")
    with engine.connect() as conn:
        before = _get_row_counts(conn)
    _print_counts("SEBELUM", before)

    if not _prompt_yes():
        print("\nDibatalkan — tidak ada perubahan ke DB.")
        return 0

    print("\n[3/4] Wipe dalam 1 transaksi...")
    try:
        with engine.begin() as conn:
            tables_csv = ", ".join(WIPE_TABLES)
            conn.execute(text(f"TRUNCATE TABLE {tables_csv} RESTART IDENTITY CASCADE"))
            conn.execute(
                text(
                    "DELETE FROM users "
                    "WHERE username <> ALL(:names) AND deleted_at IS NULL"
                ),
                {"names": KEEP_USERS},
            )
            conn.execute(
                text(
                    "UPDATE users SET token_version = token_version + 1, "
                    "updated_at = NOW() WHERE username = ANY(:names)"
                ),
                {"names": KEEP_USERS},
            )
    except Exception as e:
        print(f"  [ERROR] Wipe gagal: {e}")
        print("  Transaksi di-rollback otomatis. DB tidak berubah.")
        return 1

    print("\n[4/4] Row counts sesudah wipe...")
    with engine.connect() as conn:
        after = _get_row_counts(conn)
    _print_counts("SESUDAH", after)

    print("\n[OK] Database berhasil di-reset.")
    print("      Sesi 3 user default sudah di-invalidate (token_version +1).")
    print("      Device sales harus login ulang pakai sales.default.")
    return 0


if __name__ == "__main__":
    sys.exit(main())