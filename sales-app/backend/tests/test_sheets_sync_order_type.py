import openpyxl
from io import BytesIO
from sqlalchemy import text
from app.models.database import engine, SessionLocal
from app.services.sheets_sync import sync_products_from_excel

TEST_PREFIX = "TEST-SYNC-OT-"


def _cleanup():
    with engine.begin() as conn:
        conn.execute(text(f"DELETE FROM products WHERE id LIKE '{TEST_PREFIX}%'"))
        conn.execute(text(f"DELETE FROM suppliers WHERE name LIKE '{TEST_PREFIX}%'"))


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

        res = sync_products_from_excel(db, excel_bytes, "test.xlsx", user)
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


def test_sync_blank_supplier_preserves_existing_supplier_and_order_type():
    _cleanup()
    db = SessionLocal()
    try:
        user = {"nama": "Tester", "branch": "BANJARMASIN", "role": "ADMIN"}
        sku = f"{TEST_PREFIX}EXISTING"
        sup_orig = f"{TEST_PREFIX}ORIG-SUP"

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
        out = BytesIO()
        wb.save(out)
        excel_bytes = out.getvalue()

        res = sync_products_from_excel(db, excel_bytes, "test.xlsx", user)
        assert res["updated"] == 1

        p = db.execute(text(f"SELECT stok_sistem, nama_supplier, order_type FROM products WHERE id='{sku}'")).fetchone()
        assert p[0] == 15
        assert p[1] == sup_orig
        assert p[2] == "4P"
    finally:
        db.close()
        _cleanup()
