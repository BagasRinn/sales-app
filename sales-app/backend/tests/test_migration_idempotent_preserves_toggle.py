from sqlalchemy import text
from app.models.database import engine
import importlib.util
import pathlib

MIG_PATH = pathlib.Path(__file__).resolve().parent.parent / "migrate_2026_10_15_supplier_active.py"
spec = importlib.util.spec_from_file_location("mig", MIG_PATH)
mig = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mig)

TEST_SUP = "TEST-SUP-IDEMPOTENT"
TEST_BRANCH = "TEST-B-IDEMPOTENT"
TEST_PROD = "TEST-PROD-IDEMP"


def _cleanup():
    # Run upgrade first so the table is guaranteed to exist before DELETE
    # (upgrade is idempotent — safe on every call).
    mig.upgrade()
    with engine.begin() as conn:
        conn.execute(text("DELETE FROM products WHERE id = :i"), {"i": TEST_PROD})
        conn.execute(text("DELETE FROM suppliers WHERE name = :n"), {"n": TEST_SUP})


def _seed_product():
    """Insert a product with nama_supplier=TEST_SUP so the migration backfill
    will create the supplier row. (Backfill reads from products.nama_supplier.)"""
    with engine.begin() as conn:
        conn.execute(text(
            "INSERT INTO products (id, branch, nama_barang, harga, stok_diterima, "
            "order_type, nama_supplier) "
            "VALUES (:i, :b, 'N', 1000, 0, 'REGULER', :s) "
            "ON CONFLICT (id, branch) DO UPDATE SET nama_supplier = EXCLUDED.nama_supplier"
        ), {"i": TEST_PROD, "b": TEST_BRANCH, "s": TEST_SUP})


def test_migration_idempotent_preserves_toggle():
    _cleanup()
    _seed_product()
    # 1. Run once: backfill creates TEST_SUP as active
    mig.upgrade()
    with engine.connect() as conn:
        row = conn.execute(
            text("SELECT is_active FROM suppliers WHERE name = :n"), {"n": TEST_SUP}
        ).first()
        assert row is not None
        assert row[0] is True

    # 2. Manager manually deactivates
    with engine.begin() as conn:
        conn.execute(
            text("UPDATE suppliers SET is_active = false WHERE name = :n"),
            {"n": TEST_SUP},
        )

    # 3. Re-run migration: must NOT overwrite the manual toggle
    mig.upgrade()
    with engine.connect() as conn:
        is_active = conn.execute(
            text("SELECT is_active FROM suppliers WHERE name = :n"), {"n": TEST_SUP}
        ).scalar()
        assert is_active is False, "re-run must not overwrite manual is_active toggle"

    _cleanup()
