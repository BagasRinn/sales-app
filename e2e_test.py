"""Comprehensive end-to-end test for all mobile-facing backend endpoints.
Uses TestClient + real DB. Cleans up test data after each run.

NOTE: This test uses TestClient which runs endpoints in a separate session
from the test code. The Supabase pooler in use doesn't always show
fresh-commit visibility across sessions — we dispose the engine after
each request group to force connection recycling.
"""
import sys
import uuid as uuid_mod
from pathlib import Path
from datetime import datetime, timezone

sys.path.insert(0, str(Path(__file__).resolve().parent / "sales-app" / "backend"))

# Force UTF-8 stdout for Windows
import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

from fastapi.testclient import TestClient
from app.main import app
from app.models.database import SessionLocal, engine
from app.models.models import (
    Customer, CustomerAssignment, Order, OrderItem, Product,
    CustomerRegistrationSubmission, User as UserModel,
)


def refresh_db():
    """Dispose engine to force fresh connections (workaround for pooler)."""
    engine.dispose()


client = TestClient(app)
PASS = 0
FAIL = 0
FAILS = []


def check(name, fn):
    global PASS, FAIL
    try:
        result = fn()
        if result is True:
            print(f"  PASS  {name}")
            PASS += 1
        else:
            print(f"  FAIL  {name}: {result}")
            FAIL += 1
            FAILS.append((name, str(result)))
    except Exception as e:
        print(f"  FAIL  {name}: {type(e).__name__}: {e}")
        FAIL += 1
        FAILS.append((name, f"{type(e).__name__}: {e}"))


def login(username, password):
    r = client.post('/api/v1/auth/login', json={'username': username, 'password': password})
    if r.status_code != 200:
        raise RuntimeError(f"Login {username} failed: {r.status_code} {r.text[:200]}")
    return r.json()['access_token']


def get_user_id(username):
    db = SessionLocal()
    u = db.query(UserModel).filter(UserModel.username == username).first()
    db.close()
    return str(u.id) if u else None


def cleanup_test_data():
    db = SessionLocal()
    try:
        test_subs = db.query(CustomerRegistrationSubmission).filter(
            CustomerRegistrationSubmission.nama_langganan.like('TEST_%')
        ).all()
        for s in test_subs:
            if s.bareng_customer_id:
                order = db.query(Order).filter(Order.customer_id == s.bareng_customer_id).first()
                if order:
                    db.query(OrderItem).filter(OrderItem.order_id == order.id).delete()
                    db.delete(order)
                db.query(CustomerAssignment).filter(
                    CustomerAssignment.customer_id == s.bareng_customer_id
                ).delete()
                cust = db.query(Customer).filter(Customer.id == s.bareng_customer_id).first()
                if cust:
                    cust.deleted_at = datetime.now(timezone.utc)
            db.delete(s)
        test_orders = db.query(Order).filter(Order.store_name.like('TEST_%')).all()
        for o in test_orders:
            db.query(OrderItem).filter(OrderItem.order_id == o.id).delete()
            db.delete(o)
        test_custs = db.query(Customer).filter(Customer.nama_toko.like('TEST_%')).all()
        for c in test_custs:
            db.query(CustomerAssignment).filter(CustomerAssignment.customer_id == c.id).delete()
            c.deleted_at = datetime.now(timezone.utc)
        db.commit()
    finally:
        db.close()


print("\n=== Setup ===")
cleanup_test_data()
print("  Cleanup done")


# ============================================================
print("\n=== Auth ===")


def t_login_sales():
    r = client.post('/api/v1/auth/login', json={'username': 'sales.default', 'password': 'sales123'})
    return r.status_code == 200
check("Login sales.default", t_login_sales)


def t_login_admin():
    r = client.post('/api/v1/auth/login', json={'username': 'admin.default', 'password': 'admin123'})
    return r.status_code == 200
check("Login admin.default", t_login_admin)


def t_login_manager():
    r = client.post('/api/v1/auth/login', json={'username': 'manager.default', 'password': 'manager123'})
    return r.status_code == 200
check("Login manager.default", t_login_manager)


def t_login_bad_password():
    r = client.post('/api/v1/auth/login', json={'username': 'sales.default', 'password': 'wrong'})
    return r.status_code == 401
check("Reject wrong password", t_login_bad_password)


def t_login_unknown_user():
    r = client.post('/api/v1/auth/login', json={'username': 'nobody', 'password': 'x'})
    return r.status_code == 401
check("Reject unknown user", t_login_unknown_user)


SALES_TOKEN = login('sales.default', 'sales123')
SALES_HEADERS = {'Authorization': f'Bearer {SALES_TOKEN}'}
ADMIN_TOKEN = login('admin.default', 'admin123')
ADMIN_HEADERS = {'Authorization': f'Bearer {ADMIN_TOKEN}'}
MGR_TOKEN = login('manager.default', 'manager123')
MGR_HEADERS = {'Authorization': f'Bearer {MGR_TOKEN}'}


# ============================================================
print("\n=== Customer Submission: basic ===")


def t_submit_basic():
    payload = {
        'nama_langganan': 'TEST_basic',
        'nama_kontak_pemilik': 'Owner',
        'telpon_hp': '081111',
        'alamat_kirim': 'Alamat',
        'propinsi': 'Jawa',
        'kecamatan': 'Kec',
        'kota': 'Kota',
        'kelurahan': 'Kel',
        'tipe_langganan': 'NON PASAR',
        'tipe_pembayaran': 'TUNAI',
        'channel_kategori': 'GT',
        'siklus_kunjungan': 'W (Mingguan)',
        'hari_kunjungan': 'Senin',
    }
    r = client.post('/api/v1/customer-submissions', json=payload, headers=SALES_HEADERS)
    if r.status_code != 201:
        return f"Expected 201, got {r.status_code}: {r.text[:200]}"
    data = r.json()
    if data['status'] != 'PENDING':
        return f"status={data['status']}"
    if data['bareng_customer_id']:
        return f"bareng_customer_id unexpectedly set"
    return True
check("Submit basic customer (TUNAI)", t_submit_basic)


def t_submit_missing_required():
    r = client.post('/api/v1/customer-submissions',
                    json={'nama_langganan': 'TEST_X'}, headers=SALES_HEADERS)
    return r.status_code == 422
check("Reject missing required fields (422)", t_submit_missing_required)


def t_submit_kredit_valid():
    payload = {
        'nama_langganan': 'TEST_kredit',
        'nama_kontak_pemilik': 'Owner',
        'telpon_hp': '081',
        'alamat_kirim': 'Alamat',
        'propinsi': 'Jawa',
        'kecamatan': 'Kec',
        'kota': 'Kota',
        'kelurahan': 'Kel',
        'tipe_langganan': 'NON PASAR',
        'tipe_pembayaran': 'KREDIT',
        'jangka_kredit_hari': 14,
        'batas_kredit_rupiah': 1000000,
        'channel_kategori': 'GT',
        'siklus_kunjungan': 'W (Mingguan)',
        'hari_kunjungan': 'Senin',
    }
    r = client.post('/api/v1/customer-submissions', json=payload, headers=SALES_HEADERS)
    return r.status_code == 201
check("Submit KREDIT with jangka_kredit + batas_kredit", t_submit_kredit_valid)


def t_submit_kredit_missing_fields():
    payload = {
        'nama_langganan': 'TEST_kredit_missing',
        'nama_kontak_pemilik': 'Owner',
        'telpon_hp': '081',
        'alamat_kirim': 'Alamat',
        'propinsi': 'Jawa',
        'kecamatan': 'Kec',
        'kota': 'Kota',
        'kelurahan': 'Kel',
        'tipe_langganan': 'NON PASAR',
        'tipe_pembayaran': 'KREDIT',
        'channel_kategori': 'GT',
        'siklus_kunjungan': 'W (Mingguan)',
        'hari_kunjungan': 'Senin',
    }
    r = client.post('/api/v1/customer-submissions', json=payload, headers=SALES_HEADERS)
    return r.status_code == 422
check("Reject KREDIT without kredit fields (422)", t_submit_kredit_missing_fields)


def t_submit_invalid_tipe_pembayaran():
    payload = {
        'nama_langganan': 'TEST_invalid_tipe',
        'nama_kontak_pemilik': 'Owner',
        'telpon_hp': '081',
        'alamat_kirim': 'Alamat',
        'propinsi': 'Jawa',
        'kecamatan': 'Kec',
        'kota': 'Kota',
        'kelurahan': 'Kel',
        'tipe_langganan': 'NON PASAR',
        'tipe_pembayaran': 'INVALID',
        'channel_kategori': 'GT',
        'siklus_kunjungan': 'W (Mingguan)',
        'hari_kunjungan': 'Senin',
    }
    r = client.post('/api/v1/customer-submissions', json=payload, headers=SALES_HEADERS)
    return r.status_code == 422
check("Reject invalid tipe_pembayaran (422)", t_submit_invalid_tipe_pembayaran)


# ============================================================
print("\n=== Customer Submission: bareng_order (recent fix) ===")


def t_submit_bareng_order():
    payload = {
        'nama_langganan': 'TEST_bareng',
        'nama_kontak_pemilik': 'Owner',
        'telpon_hp': '081',
        'alamat_kirim': 'Alamat',
        'propinsi': 'Jawa',
        'kecamatan': 'Kec',
        'kota': 'Kota',
        'kelurahan': 'Kel',
        'tipe_langganan': 'NON PASAR',
        'tipe_pembayaran': 'TUNAI',
        'channel_kategori': 'GT',
        'siklus_kunjungan': 'W (Mingguan)',
        'hari_kunjungan': 'Senin',
        'bareng_order': True,
    }
    r = client.post('/api/v1/customer-submissions', json=payload, headers=SALES_HEADERS)
    if r.status_code != 201:
        return f"Expected 201, got {r.status_code}: {r.text[:300]}"
    data = r.json()
    if not data['bareng_customer_id']:
        return f"Expected bareng_customer_id"
    if not data.get('order'):
        return f"Expected nested order"
    if data['order']['status'] != 'DRAFT':
        return f"Expected order status DRAFT, got {data['order']['status']}"
    if len(data['order']['items']) != 0:
        return f"Expected empty items, got {len(data['order']['items'])}"
    return True
check("Submit bareng_order (no order_items, recent fix)", t_submit_bareng_order)


def t_submit_bareng_4p():
    """4P order type juga harus jalan."""
    payload = {
        'nama_langganan': 'TEST_bareng_4p',
        'nama_kontak_pemilik': 'Owner',
        'telpon_hp': '081',
        'alamat_kirim': 'Alamat',
        'propinsi': 'Jawa',
        'kecamatan': 'Kec',
        'kota': 'Kota',
        'kelurahan': 'Kel',
        'tipe_langganan': 'NON PASAR',
        'tipe_pembayaran': 'TUNAI',
        'channel_kategori': 'GT',
        'siklus_kunjungan': 'W (Mingguan)',
        'hari_kunjungan': 'Senin',
        'bareng_order': True,
        'order_type': '4P',
    }
    r = client.post('/api/v1/customer-submissions', json=payload, headers=SALES_HEADERS)
    if r.status_code != 201:
        return f"Expected 201, got {r.status_code}: {r.text[:300]}"
    data = r.json()
    if data['order']['order_type'] != '4P':
        return f"Expected order_type 4P, got {data['order']['order_type']}"
    return True
check("Submit bareng_order with order_type=4P", t_submit_bareng_4p)


def t_submit_bareng_invalid_order_type():
    payload = {
        'nama_langganan': 'TEST_bad_type',
        'nama_kontak_pemilik': 'Owner',
        'telpon_hp': '081',
        'alamat_kirim': 'Alamat',
        'propinsi': 'Jawa',
        'kecamatan': 'Kec',
        'kota': 'Kota',
        'kelurahan': 'Kel',
        'tipe_langganan': 'NON PASAR',
        'tipe_pembayaran': 'TUNAI',
        'channel_kategori': 'GT',
        'siklus_kunjungan': 'W (Mingguan)',
        'hari_kunjungan': 'Senin',
        'bareng_order': True,
        'order_type': 'INVALID_TYPE',
    }
    r = client.post('/api/v1/customer-submissions', json=payload, headers=SALES_HEADERS)
    return r.status_code == 400
check("Reject invalid order_type (400)", t_submit_bareng_invalid_order_type)


# ============================================================
print("\n=== My Submissions ===")


def t_list_my():
    r = client.get('/api/v1/customer-submissions/my', headers=SALES_HEADERS)
    if r.status_code != 200:
        return f"Expected 200, got {r.status_code}"
    data = r.json()
    if len(data) < 3:
        return f"Expected >=3, got {len(data)}"
    return True
check("List my submissions", t_list_my)


def t_list_my_unauth():
    r = client.get('/api/v1/customer-submissions/my')
    return r.status_code == 401
check("List my submissions without auth (401)", t_list_my_unauth)


# ============================================================
print("\n=== Get submission detail ===")


def t_get_own_submission():
    db = SessionLocal()
    sub = db.query(CustomerRegistrationSubmission).filter(
        CustomerRegistrationSubmission.nama_langganan == 'TEST_basic',
    ).first()
    db.close()
    if not sub:
        return f"No submission to test"
    r = client.get(f'/api/v1/customer-submissions/{sub.id}', headers=SALES_HEADERS)
    return r.status_code == 200
check("Get own submission detail", t_get_own_submission)


def t_get_other_sales_submission():
    """sales.default coba akses submission sales lain -> 403."""
    db = SessionLocal()
    sales_default_id = get_user_id('sales.default')
    other = db.query(CustomerRegistrationSubmission).filter(
        CustomerRegistrationSubmission.sales_id != uuid_mod.UUID(sales_default_id),
    ).first()
    db.close()
    if not other:
        return True  # No other sales submissions to test with
    r = client.get(f'/api/v1/customer-submissions/{other.id}', headers=SALES_HEADERS)
    return r.status_code == 403
check("Sales cannot view other sales' submissions (403)", t_get_other_sales_submission)


def t_get_invalid_uuid():
    r = client.get('/api/v1/customer-submissions/not-a-uuid', headers=SALES_HEADERS)
    return r.status_code == 422
check("Invalid UUID in path (422)", t_get_invalid_uuid)


def t_get_nonexistent():
    r = client.get('/api/v1/customer-submissions/00000000-0000-0000-0000-000000000000',
                   headers=SALES_HEADERS)
    return r.status_code == 404
check("Nonexistent submission (404)", t_get_nonexistent)


# ============================================================
print("\n=== Admin: list all submissions ===")


def t_admin_list_all():
    r = client.get('/api/v1/customer-submissions', headers=ADMIN_HEADERS)
    return r.status_code == 200
check("Admin list all submissions", t_admin_list_all)


def t_admin_list_filtered():
    r = client.get('/api/v1/customer-submissions', params={'status': 'PENDING'},
                   headers=ADMIN_HEADERS)
    return r.status_code == 200
check("Admin list filter by status PENDING", t_admin_list_filtered)


def t_sales_cannot_list_all():
    r = client.get('/api/v1/customer-submissions', headers=SALES_HEADERS)
    return r.status_code == 403
check("Sales cannot list all submissions (403)", t_sales_cannot_list_all)


# ============================================================
print("\n=== Admin: approve submission ===")


def t_admin_approve_basic():
    db = SessionLocal()
    sub = db.query(CustomerRegistrationSubmission).filter(
        CustomerRegistrationSubmission.nama_langganan == 'TEST_basic',
        CustomerRegistrationSubmission.status == 'PENDING',
        CustomerRegistrationSubmission.bareng_customer_id.is_(None),
    ).first()
    db.close()
    if not sub:
        return f"No PENDING basic submission"
    r = client.post(f'/api/v1/customer-submissions/{sub.id}/approve',
                    json={'kode': 'T1000', 'nama_toko': 'TEST_approved', 'alamat': 'A'},
                    headers=ADMIN_HEADERS)
    return r.status_code == 201
check("Admin approve basic submission", t_admin_approve_basic)


def t_admin_approve_duplicate_kode():
    """Approve dengan kode yang sudah dipakai -> 409."""
    db = SessionLocal()
    sub = db.query(CustomerRegistrationSubmission).filter(
        CustomerRegistrationSubmission.nama_langganan == 'TEST_kredit',
        CustomerRegistrationSubmission.status == 'PENDING',
    ).first()
    db.close()
    if not sub:
        return f"No submission"
    r = client.post(f'/api/v1/customer-submissions/{sub.id}/approve',
                    json={'kode': 'T1000'},  # already used
                    headers=ADMIN_HEADERS)
    return r.status_code == 409
check("Admin approve duplicate kode (409)", t_admin_approve_duplicate_kode)


def t_sales_cannot_approve():
    db = SessionLocal()
    sub = db.query(CustomerRegistrationSubmission).filter(
        CustomerRegistrationSubmission.status == 'PENDING',
    ).first()
    db.close()
    if not sub:
        return True
    r = client.post(f'/api/v1/customer-submissions/{sub.id}/approve',
                    json={'kode': 'X001'}, headers=SALES_HEADERS)
    return r.status_code == 403
check("Sales cannot approve (403)", t_sales_cannot_approve)


def t_admin_approve_bareng():
    db = SessionLocal()
    sub = db.query(CustomerRegistrationSubmission).filter(
        CustomerRegistrationSubmission.nama_langganan == 'TEST_bareng',
        CustomerRegistrationSubmission.status == 'PENDING',
    ).first()
    if not sub:
        db.close()
        return f"No bareng submission"
    order = db.query(Order).filter(Order.customer_id == sub.bareng_customer_id).first()
    db.close()
    r = client.post(f'/api/v1/customer-submissions/{sub.id}/approve',
                    json={'kode': 'TB001', 'nama_toko': 'TEST_bareng_approved'},
                    headers=ADMIN_HEADERS)
    if r.status_code != 201:
        return f"Expected 201, got {r.status_code}: {r.text[:300]}"
    db = SessionLocal()
    order = db.query(Order).filter(Order.customer_id == sub.bareng_customer_id).first()
    if order.status != 'PENDING':
        db.close()
        return f"Order not transitioned to PENDING: {order.status}"
    db.close()
    return True
check("Admin approve bareng (order DRAFT -> PENDING)", t_admin_approve_bareng)


# ============================================================
print("\n=== Admin: reject submission ===")


def t_admin_reject():
    db = SessionLocal()
    sub = db.query(CustomerRegistrationSubmission).filter(
        CustomerRegistrationSubmission.nama_langganan == 'TEST_kredit',
        CustomerRegistrationSubmission.status == 'PENDING',
    ).first()
    db.close()
    if not sub:
        return f"No submission"
    r = client.post(f'/api/v1/customer-submissions/{sub.id}/reject',
                    json={'reject_reason': 'Alamat tidak valid'},
                    headers=ADMIN_HEADERS)
    return r.status_code == 200
check("Admin reject submission", t_admin_reject)


def t_admin_reject_already_approved():
    """Reject submission yang sudah di-approve -> 409."""
    db = SessionLocal()
    sub = db.query(CustomerRegistrationSubmission).filter(
        CustomerRegistrationSubmission.status == 'APPROVED',
    ).first()
    db.close()
    if not sub:
        return True  # no approved to test
    r = client.post(f'/api/v1/customer-submissions/{sub.id}/reject',
                    json={}, headers=ADMIN_HEADERS)
    return r.status_code == 409
check("Admin reject already-approved (409)", t_admin_reject_already_approved)


# ============================================================
print("\n=== Sales: cancel submission ===")


def t_sales_cancel_own():
    db = SessionLocal()
    sub = db.query(CustomerRegistrationSubmission).filter(
        CustomerRegistrationSubmission.sales_id == uuid_mod.UUID(get_user_id('sales.default')),
        CustomerRegistrationSubmission.status == 'PENDING',
    ).first()
    db.close()
    if not sub:
        return f"No submission to cancel"
    r = client.post(f'/api/v1/customer-submissions/{sub.id}/cancel',
                    json={}, headers=SALES_HEADERS)
    return r.status_code == 200
check("Sales cancel own submission", t_sales_cancel_own)


# ============================================================
print("\n=== Orders: list & create ===")


def t_mgr_list_orders():
    r = client.get('/api/v1/orders', headers=MGR_HEADERS)
    return r.status_code == 200
check("Manager list all orders", t_mgr_list_orders)


def t_create_order_with_items():
    """Create order dengan items, test Decimal discount serialization."""
    db = SessionLocal()
    sales_id = get_user_id('sales.default')
    cust = db.query(Customer).join(CustomerAssignment).filter(
        CustomerAssignment.sales_id == uuid_mod.UUID(sales_id),
        Customer.deleted_at.is_(None),
    ).first()
    product = db.query(Product).filter(
        Product.order_type == 'REGULER', Product.stok_sistem > 10
    ).first()
    db.close()
    if not cust or not product:
        return f"No customer/product (cust={cust}, product={product})"
    payload = {
        'customer_id': str(cust.id),
        'order_type': 'REGULER',
        'store_name': 'TEST_decimal_order',
        'items': [{
            'product_id': product.id,
            'qty': 1,
            'discount_type': 'PERCENT',
            'discount_percent': 15.5,
            'discount_nominal': 0,
        }],
    }
    r = client.post('/api/v1/orders', json=payload, headers=SALES_HEADERS)
    if r.status_code not in (200, 201):
        return f"Expected 200/201, got {r.status_code}: {r.text[:300]}"
    refresh_db()
    # Verify persisted
    db = SessionLocal()
    o = db.query(Order).filter(Order.store_name == 'TEST_decimal_order').first()
    db.close()
    if not o:
        return f"Order NOT persisted to DB after create!"
    return True
check("Create order with Decimal discount (15.5%)", t_create_order_with_items)


def t_create_order_no_items():
    """Create order tanpa items -> 400 by design."""
    db = SessionLocal()
    sales_id = get_user_id('sales.default')
    cust = db.query(Customer).join(CustomerAssignment).filter(
        CustomerAssignment.sales_id == uuid_mod.UUID(sales_id),
        Customer.deleted_at.is_(None),
    ).first()
    db.close()
    if not cust:
        return f"No customer"
    r = client.post('/api/v1/orders', json={
        'customer_id': str(cust.id),
        'order_type': 'REGULER',
        'store_name': 'TEST_no_items',
        'items': [],
    }, headers=SALES_HEADERS)
    return r.status_code == 400
check("Reject order with no items (400 by design)", t_create_order_no_items)


# ============================================================
print("\n=== Orders: submit, cancel items ===")


def t_submit_draft_order():
    """Create + submit DRAFT -> PENDING."""
    db = SessionLocal()
    sales_id = get_user_id('sales.default')
    cust = db.query(Customer).join(CustomerAssignment).filter(
        CustomerAssignment.sales_id == uuid_mod.UUID(sales_id),
        Customer.deleted_at.is_(None),
    ).first()
    product = db.query(Product).filter(
        Product.order_type == 'REGULER', Product.stok_sistem > 10
    ).first()
    db.close()
    if not cust or not product:
        return f"No customer/product"
    r = client.post('/api/v1/orders', json={
        'customer_id': str(cust.id),
        'order_type': 'REGULER',
        'store_name': 'TEST_submit',
        'items': [{
            'product_id': product.id,
            'qty': 1,
            'discount_type': 'PERCENT',
            'discount_percent': 0,
            'discount_nominal': 0,
        }],
    }, headers=SALES_HEADERS)
    if r.status_code not in (200, 201):
        return f"Create failed: {r.status_code}"
    order_id = r.json()['id']
    r = client.post(f'/api/v1/orders/{order_id}/submit', headers=SALES_HEADERS)
    if r.status_code != 200:
        return f"Submit failed: {r.status_code} {r.text[:200]}"
    if r.json()['status'] != 'PENDING':
        return f"Status={r.json()['status']}"
    refresh_db()
    return True
check("Submit DRAFT order to PENDING", t_submit_draft_order)


def t_cancel_items_decimal():
    """The recent 422 bug with Decimal discount. Admin-only endpoint."""
    from sqlalchemy.orm import joinedload
    db = SessionLocal()
    order = db.query(Order).options(joinedload(Order.items)).filter(
        Order.store_name == 'TEST_decimal_order'
    ).first()
    if not order:
        db.close()
        return f"No order found with store_name=TEST_decimal_order"
    if not order.items:
        db.close()
        return f"Order exists but no items (order.id={order.id})"
    if order.status == 'DRAFT':
        r = client.post(f'/api/v1/orders/{order.id}/submit', headers=SALES_HEADERS)
        if r.status_code != 200:
            db.close()
            return f"Submit failed: {r.status_code}"
        db = SessionLocal()
        order = db.query(Order).options(joinedload(Order.items)).filter(
            Order.store_name == 'TEST_decimal_order'
        ).first()
    item_id = str(order.items[0].id)
    qty = order.items[0].qty
    order_id = str(order.id)
    db.close()
    # Cancel-items is ADMIN-only (admin web, not mobile)
    r = client.put(f'/api/v1/orders/{order_id}/cancel-items', json={
        'items': [{'item_id': item_id, 'qty': qty, 'reason': 'Stok rusak'}],
    }, headers=ADMIN_HEADERS)
    return r.status_code == 200
check("Cancel items with Decimal discount (was 422 bug)", t_cancel_items_decimal)


def t_cancel_items_short_reason():
    """Reason < 3 chars -> 422."""
    from sqlalchemy.orm import joinedload
    db = SessionLocal()
    order = db.query(Order).options(joinedload(Order.items)).filter(
        Order.store_name == 'TEST_submit',
    ).first()
    if not order or not order.items:
        db.close()
        return f"No order/items for TEST_submit"
    item = order.items[0]
    order_id = str(order.id)
    db.close()
    r = client.put(f'/api/v1/orders/{order_id}/cancel-items', json={
        'items': [{'item_id': str(item.id), 'qty': 1, 'reason': 'x'}],  # too short
    }, headers=ADMIN_HEADERS)
    return r.status_code == 422
check("Reject cancel reason < 3 chars (422)", t_cancel_items_short_reason)


def t_cancel_items_nonexistent_item():
    from sqlalchemy.orm import joinedload
    db = SessionLocal()
    order = db.query(Order).filter(Order.store_name == 'TEST_submit').first()
    if not order:
        db.close()
        return f"No order for TEST_submit"
    order_id = str(order.id)
    db.close()
    r = client.put(f'/api/v1/orders/{order_id}/cancel-items', json={
        'items': [{'item_id': '00000000-0000-0000-0000-000000000000', 'qty': 1, 'reason': 'test'}],
    }, headers=ADMIN_HEADERS)
    return r.status_code == 404
check("Cancel nonexistent item (404)", t_cancel_items_nonexistent_item)


def t_sales_cannot_cancel_items():
    """Sales role tidak boleh cancel items (admin-only endpoint)."""
    from sqlalchemy.orm import joinedload
    db = SessionLocal()
    order = db.query(Order).options(joinedload(Order.items)).filter(
        Order.store_name == 'TEST_submit',
    ).first()
    if not order or not order.items:
        db.close()
        return f"No order/items"
    item = order.items[0]
    order_id = str(order.id)
    db.close()
    r = client.put(f'/api/v1/orders/{order_id}/cancel-items', json={
        'items': [{'item_id': str(item.id), 'qty': 1, 'reason': 'Test sales cancel'}],
    }, headers=SALES_HEADERS)
    return r.status_code == 403
check("Sales cannot cancel items (403, admin-only)", t_sales_cannot_cancel_items)


# ============================================================
print("\n=== Products, customers, bulletins ===")


def t_list_products():
    r = client.get('/api/v1/products', headers=SALES_HEADERS)
    return r.status_code == 200
check("List products", t_list_products)


def t_list_my_customers():
    r = client.get('/api/v1/customers/my', headers=SALES_HEADERS)
    return r.status_code == 200
check("List my customers", t_list_my_customers)


def t_list_bulletins():
    r = client.get('/api/v1/bulletins', headers=SALES_HEADERS)
    return r.status_code == 200
check("List bulletins", t_list_bulletins)


# ============================================================
print("\n=== Security: SQL injection, XSS, edge cases ===")


def t_sql_injection():
    payload = {
        'nama_langganan': "TEST_'; DROP TABLE customers;--",
        'nama_kontak_pemilik': 'Owner',
        'telpon_hp': '081',
        'alamat_kirim': 'Alamat',
        'propinsi': 'Jawa',
        'kecamatan': 'Kec',
        'kota': 'Kota',
        'kelurahan': 'Kel',
        'tipe_langganan': 'NON PASAR',
        'tipe_pembayaran': 'TUNAI',
        'channel_kategori': 'GT',
        'siklus_kunjungan': 'W (Mingguan)',
        'hari_kunjungan': 'Senin',
    }
    r = client.post('/api/v1/customer-submissions', json=payload, headers=SALES_HEADERS)
    if r.status_code != 201:
        return f"Expected 201, got {r.status_code}: {r.text[:200]}"
    db = SessionLocal()
    cust_count = db.query(Customer).count()
    db.close()
    if cust_count < 1:
        return f"Customer table gone: {cust_count}"
    return True
check("SQL injection attempt safely stored", t_sql_injection)


def t_xss():
    payload = {
        'nama_langganan': 'TEST_<script>alert(1)</script>',
        'nama_kontak_pemilik': 'Owner<img src=x onerror=alert(1)>',
        'telpon_hp': '081',
        'alamat_kirim': 'Alamat',
        'propinsi': 'Jawa',
        'kecamatan': 'Kec',
        'kota': 'Kota',
        'kelurahan': 'Kel',
        'tipe_langganan': 'NON PASAR',
        'tipe_pembayaran': 'TUNAI',
        'channel_kategori': 'GT',
        'siklus_kunjungan': 'W (Mingguan)',
        'hari_kunjungan': 'Senin',
    }
    return client.post('/api/v1/customer-submissions', json=payload, headers=SALES_HEADERS).status_code == 201
check("XSS attempt stored as plain string", t_xss)


def t_long_string():
    payload = {
        'nama_langganan': 'TEST_' + 'A' * 300,
        'nama_kontak_pemilik': 'Owner',
        'telpon_hp': '081',
        'alamat_kirim': 'Alamat',
        'propinsi': 'Jawa',
        'kecamatan': 'Kec',
        'kota': 'Kota',
        'kelurahan': 'Kel',
        'tipe_langganan': 'NON PASAR',
        'tipe_pembayaran': 'TUNAI',
        'channel_kategori': 'GT',
        'siklus_kunjungan': 'W (Mingguan)',
        'hari_kunjungan': 'Senin',
    }
    return client.post('/api/v1/customer-submissions', json=payload, headers=SALES_HEADERS).status_code == 422
check("Reject overlong string (422)", t_long_string)


def t_empty_string():
    payload = {
        'nama_langganan': '',
        'nama_kontak_pemilik': 'Owner',
        'telpon_hp': '081',
        'alamat_kirim': 'Alamat',
        'propinsi': 'Jawa',
        'kecamatan': 'Kec',
        'kota': 'Kota',
        'kelurahan': 'Kel',
        'tipe_langganan': 'NON PASAR',
        'tipe_pembayaran': 'TUNAI',
        'channel_kategori': 'GT',
        'siklus_kunjungan': 'W (Mingguan)',
        'hari_kunjungan': 'Senin',
    }
    return client.post('/api/v1/customer-submissions', json=payload, headers=SALES_HEADERS).status_code == 422
check("Reject empty string for required (422)", t_empty_string)


def t_null_required():
    payload = {
        'nama_langganan': None,
        'nama_kontak_pemilik': 'Owner',
        'telpon_hp': '081',
        'alamat_kirim': 'Alamat',
        'propinsi': 'Jawa',
        'kecamatan': 'Kec',
        'kota': 'Kota',
        'kelurahan': 'Kel',
        'tipe_langganan': 'NON PASAR',
        'tipe_pembayaran': 'TUNAI',
        'channel_kategori': 'GT',
        'siklus_kunjungan': 'W (Mingguan)',
        'hari_kunjungan': 'Senin',
    }
    return client.post('/api/v1/customer-submissions', json=payload, headers=SALES_HEADERS).status_code == 422
check("Reject null for required (422)", t_null_required)


def t_negative_qty():
    db = SessionLocal()
    sales_id = get_user_id('sales.default')
    cust = db.query(Customer).join(CustomerAssignment).filter(
        CustomerAssignment.sales_id == uuid_mod.UUID(sales_id),
        Customer.deleted_at.is_(None),
    ).first()
    product = db.query(Product).filter(
        Product.order_type == 'REGULER', Product.stok_sistem > 10
    ).first()
    db.close()
    if not cust or not product:
        return f"No customer/product"
    r = client.post('/api/v1/orders', json={
        'customer_id': str(cust.id),
        'order_type': 'REGULER',
        'store_name': 'TEST_neg_qty',
        'items': [{
            'product_id': product.id,
            'qty': -1,  # invalid
            'discount_type': 'PERCENT',
            'discount_percent': 0,
            'discount_nominal': 0,
        }],
    }, headers=SALES_HEADERS)
    return r.status_code == 422
check("Reject negative qty (422)", t_negative_qty)


def t_zero_qty():
    db = SessionLocal()
    sales_id = get_user_id('sales.default')
    cust = db.query(Customer).join(CustomerAssignment).filter(
        CustomerAssignment.sales_id == uuid_mod.UUID(sales_id),
        Customer.deleted_at.is_(None),
    ).first()
    product = db.query(Product).filter(
        Product.order_type == 'REGULER', Product.stok_sistem > 10
    ).first()
    db.close()
    if not cust or not product:
        return f"No customer/product"
    r = client.post('/api/v1/orders', json={
        'customer_id': str(cust.id),
        'order_type': 'REGULER',
        'store_name': 'TEST_zero_qty',
        'items': [{
            'product_id': product.id,
            'qty': 0,  # invalid (gt=0)
            'discount_type': 'PERCENT',
            'discount_percent': 0,
            'discount_nominal': 0,
        }],
    }, headers=SALES_HEADERS)
    return r.status_code == 422
check("Reject zero qty (422)", t_zero_qty)


def t_discount_percent_over_100():
    db = SessionLocal()
    sales_id = get_user_id('sales.default')
    cust = db.query(Customer).join(CustomerAssignment).filter(
        CustomerAssignment.sales_id == uuid_mod.UUID(sales_id),
        Customer.deleted_at.is_(None),
    ).first()
    product = db.query(Product).filter(
        Product.order_type == 'REGULER', Product.stok_sistem > 10
    ).first()
    db.close()
    if not cust or not product:
        return f"No customer/product"
    r = client.post('/api/v1/orders', json={
        'customer_id': str(cust.id),
        'order_type': 'REGULER',
        'store_name': 'TEST_pct_101',
        'items': [{
            'product_id': product.id,
            'qty': 1,
            'discount_type': 'PERCENT',
            'discount_percent': 101.0,  # invalid (le=100)
            'discount_nominal': 0,
        }],
    }, headers=SALES_HEADERS)
    return r.status_code == 422
check("Reject discount_percent > 100 (422)", t_discount_percent_over_100)


def t_negative_discount_nominal():
    db = SessionLocal()
    sales_id = get_user_id('sales.default')
    cust = db.query(Customer).join(CustomerAssignment).filter(
        CustomerAssignment.sales_id == uuid_mod.UUID(sales_id),
        Customer.deleted_at.is_(None),
    ).first()
    product = db.query(Product).filter(
        Product.order_type == 'REGULER', Product.stok_sistem > 10
    ).first()
    db.close()
    if not cust or not product:
        return f"No customer/product"
    r = client.post('/api/v1/orders', json={
        'customer_id': str(cust.id),
        'order_type': 'REGULER',
        'store_name': 'TEST_neg_disc',
        'items': [{
            'product_id': product.id,
            'qty': 1,
            'discount_type': 'NOMINAL',
            'discount_percent': 0,
            'discount_nominal': -100,  # invalid
        }],
    }, headers=SALES_HEADERS)
    return r.status_code == 422
check("Reject negative discount_nominal (422)", t_negative_discount_nominal)


# ============================================================
print("\n=== Dashboard & Reports ===")


def t_manager_dashboard():
    r = client.get('/api/v1/reports/sales-performance/dashboard', headers=MGR_HEADERS)
    return r.status_code == 200
check("Manager dashboard endpoint", t_manager_dashboard)


def t_sales_cannot_access_manager_dashboard():
    r = client.get('/api/v1/reports/sales-performance/dashboard', headers=SALES_HEADERS)
    return r.status_code == 403
check("Sales cannot access manager dashboard (403)",
      t_sales_cannot_access_manager_dashboard)


# ============================================================
print("\n=== Cleanup ===")
cleanup_test_data()
print("  Done")


# ============================================================
print(f"\n{'='*60}")
print(f"RESULTS: {PASS} pass, {FAIL} fail")
print(f"{'='*60}")
if FAILS:
    print("\nFailures:")
    for name, msg in FAILS:
        print(f"  - {name}")
        print(f"    {msg[:200]}")
sys.exit(0 if FAIL == 0 else 1)