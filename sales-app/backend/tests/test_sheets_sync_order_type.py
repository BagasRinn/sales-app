import openpyxl
from io import BytesIO
from sqlalchemy import text
from app.models.database import engine, SessionLocal
from app.services.sheets_sync import sync_products_from_excel

TEST_PREFIX = "TEST-SYNC-OT-"


def _cleanup():
    with engine.begin() as conn:
        # stok_log punya FK ke (products.id, products.branch) — hapus dulu.
        conn.execute(text(
            f"DELETE FROM stok_log WHERE product_id LIKE '{TEST_PREFIX}%'"
        ))
        conn.execute(text(f"DELETE FROM products WHERE id LIKE '{TEST_PREFIX}%'"))
        conn.execute(text(f"DELETE FROM suppliers WHERE name LIKE '{TEST_PREFIX}%'"))
        # ImportLog hasil sync ikut dihapus supaya panel Riwayat admin bersih.
        # ponytail: file_name di test selalu "test.xlsx"; kalau nanti test pakai
        # nama file lain, ikutkan di filter ini.
        conn.execute(text(
            "DELETE FROM sync_validation_errors WHERE import_log_id IN "
            "(SELECT id FROM import_logs WHERE file_name = 'test.xlsx')"
        ))
        conn.execute(text("DELETE FROM import_logs WHERE file_name = 'test.xlsx'"))


def test_sync_supplier_order_type_from_db():
    _cleanup()
    db = SessionLocal()
    try:
        user = {"nama": "Tester", "branch": "BANJARMASIN", "role": "ADMIN"}
        sup_4p_name = f"{TEST_PREFIX}4P-SUP"
        sup_reg_name = f"{TEST_PREFIX}REG-SUP"

        # Create suppliers in DB
        conn = engine.connect()
        conn.execute(text(f"INSERT INTO suppliers (name, is_active, order_type) VALUES ('{sup_4p_name}', true, '4P')"))
        conn.execute(text(f"INSERT INTO suppliers (name, is_active, order_type) VALUES ('{sup_reg_name}', true, 'REGULER')"))
        conn.commit()
        conn.close()

        wb = openpyxl.Workbook()
        ws = wb.active
        ws.append(["CCODE", "KATEGORI", "NAME ITEM", "GOOD", "OUM", "FIX", "LAST SUPPLIER"])
        ws.append([f"{TEST_PREFIX}SKU1", "KAT1", "PROD 1", 10, "PCS", 1000, sup_4p_name])
        ws.append([f"{TEST_PREFIX}SKU2", "KAT1", "PROD 2", 20, "PCS", 2000, sup_reg_name])
        ws.append([f"{TEST_PREFIX}SKU3", "KAT1", "PROD 3", 30, "PCS", 3000, f"{TEST_PREFIX}NEW-SUP"])
        out = BytesIO()
        wb.save(out)
        excel_bytes = out.getvalue()

        res = sync_products_from_excel(excel_bytes, db, user, "test.xlsx")
        assert res["inserted"] == 3

        p1 = db.execute(text(f"SELECT order_type FROM products WHERE id='{TEST_PREFIX}SKU1'")).fetchone()
        p2 = db.execute(text(f"SELECT order_type FROM products WHERE id='{TEST_PREFIX}SKU2'")).fetchone()
        p3 = db.execute(text(f"SELECT order_type, nama_supplier FROM products WHERE id='{TEST_PREFIX}SKU3'")).fetchone()

        assert p1[0] == "4P"
        assert p2[0] == "REGULER"
        assert p3[0] == "REGULER"
        assert p3[1] == f"{TEST_PREFIX}NEW-SUP"

        # Check auto insert new supplier
        s3 = db.execute(text(f"SELECT order_type FROM suppliers WHERE name='{TEST_PREFIX}NEW-SUP'")).fetchone()
        assert s3 is not None
        assert s3[0] == "REGULER"
    finally:
        db.close()
        _cleanup()


def test_sync_rejects_row_without_supplier():
    """Baris tanpa LAST SUPPLIER di-skip, tidak masuk DB, dan masuk riwayat error."""
    _cleanup()
    db = SessionLocal()
    try:
        user = {"nama": "Tester", "branch": "BANJARMASIN", "role": "ADMIN"}
        sku = f"{TEST_PREFIX}EXISTING"
        sup_orig = f"{TEST_PREFIX}ORIG-SUP"
        sku_new = f"{TEST_PREFIX}NOSUP"

        conn = engine.connect()
        conn.execute(text(
            f"INSERT INTO products (id, branch, nama_barang, harga, stok_sistem, stok_booking, stok_diterima, nama_supplier, order_type) "
            f"VALUES ('{sku}', 'BANJARMASIN', 'Existing Item', 5000, 10, 0, 0, '{sup_orig}', '4P')"
        ))
        conn.commit()
        conn.close()

        wb = openpyxl.Workbook()
        ws = wb.active
        ws.append(["CCODE", "KATEGORI", "NAME ITEM", "GOOD", "OUM", "FIX", "LAST SUPPLIER"])
        ws.append([sku, "KAT1", "Existing Item Updated", 15, "PCS", 5000, ""])
        ws.append([sku_new, "KAT1", "Produk Tanpa Supplier", 5, "PCS", 1000, ""])
        out = BytesIO()
        wb.save(out)
        excel_bytes = out.getvalue()

        res = sync_products_from_excel(excel_bytes, db, user, "test.xlsx")
        assert res["skipped"] == 2
        assert res["inserted"] == 0
        assert res["updated"] == 0
        assert all("LAST SUPPLIER" in e["reason"] for e in res["errors"])

        # DB tidak berubah: baris lama tetap, baris baru tidak dibuat.
        p = db.execute(text(f"SELECT stok_sistem, nama_supplier, order_type FROM products WHERE id='{sku}'")).fetchone()
        assert p[0] == 10
        assert p[1] == sup_orig
        assert p[2] == "4P"
        assert db.execute(text(f"SELECT count(*) FROM products WHERE id='{sku_new}'")).scalar() == 0

        # Riwayat error tersimpan + import log menghitung skip.
        err_rows = db.execute(text(
            "SELECT count(*) FROM sync_validation_errors WHERE import_log_id = "
            "(SELECT id FROM import_logs WHERE file_name = 'test.xlsx' ORDER BY created_at DESC LIMIT 1)"
        )).scalar()
        assert err_rows == 2
        logged_skipped = db.execute(text(
            "SELECT skipped FROM import_logs WHERE file_name = 'test.xlsx' ORDER BY created_at DESC LIMIT 1"
        )).scalar()
        assert logged_skipped == 2
    finally:
        db.close()
        _cleanup()
