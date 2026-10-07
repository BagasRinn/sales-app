"""E2E test for admin web features — admin-only endpoints.
Uses TestClient + real DB. Cleans up test data.
"""
import sys
import uuid as uuid_mod
from pathlib import Path
from datetime import datetime, timezone

sys.path.insert(0, str(Path(__file__).resolve().parent / "sales-app" / "backend"))

import io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

from fastapi.testclient import TestClient
from app.main import app
from app.models.database import SessionLocal
from app.models.models import (
    Customer, CustomerAssignment, Order, OrderItem, Product,
    CustomerRegistrationSubmission, User as UserModel,
    Bulletin, BulletinDismiss,
)
from sqlalchemy.orm import joinedload

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
        raise RuntimeError(f"Login {username} failed: {r.status_code}")
    return r.json()['access_token']


def get_user_id(username):
    db = SessionLocal()
    u = db.query(UserModel).filter(UserModel.username == username).first()
    db.close()
    return str(u.id) if u else None


def cleanup_test_data():
    """Hard-delete all test data (including soft-deleted) to ensure clean state."""
    db = SessionLocal()
    try:
        # Hard-delete customers (skip FK constraints)
        for c in db.query(Customer).filter(Customer.nama_toko.like('TEST_%')).all():
            db.query(CustomerAssignment).filter(CustomerAssignment.customer_id == c.id).delete()
            db.delete(c)  # hard delete
        for s in db.query(CustomerRegistrationSubmission).filter(
            CustomerRegistrationSubmission.nama_langganan.like('TEST_%')
        ).all():
            db.delete(s)
        for o in db.query(Order).filter(Order.store_name.like('TEST_%')).all():
            db.query(OrderItem).filter(OrderItem.order_id == o.id).delete()
            db.delete(o)
        for b in db.query(Bulletin).filter(Bulletin.title.like('TEST_%')).all():
            db.query(BulletinDismiss).filter(BulletinDismiss.bulletin_id == b.id).delete()
            db.delete(b)
        for p in db.query(Product).filter(Product.id.like('TEST_%')).all():
            db.delete(p)
        for u in db.query(UserModel).filter(UserModel.username.like('test_%')).all():
            db.delete(u)
        db.commit()
    finally:
        db.close()


print("\n=== Setup ===")
cleanup_test_data()
print("  Cleanup done")


# ============================================================
print("\n=== Auth ===")


def t_login_admin():
    r = client.post('/api/v1/auth/login', json={'username': 'admin.default', 'password': 'admin123'})
    return r.status_code == 200
check("Login admin.default", t_login_admin)


def t_login_manager():
    r = client.post('/api/v1/auth/login', json={'username': 'manager.default', 'password': 'manager123'})
    return r.status_code == 200
check("Login manager.default", t_login_manager)


ADMIN_TOKEN = login('admin.default', 'admin123')
ADMIN_HEADERS = {'Authorization': f'Bearer {ADMIN_TOKEN}'}
MGR_TOKEN = login('manager.default', 'manager123')
MGR_HEADERS = {'Authorization': f'Bearer {MGR_TOKEN}'}
SALES_TOKEN = login('sales.default', 'sales123')
SALES_HEADERS = {'Authorization': f'Bearer {SALES_TOKEN}'}


# ============================================================
print("\n=== Products: read-only (admin) ===")
# NOTE: products hanya bisa di-manage via Excel import, tidak ada POST/PUT/DELETE
# individual. Tests di sini cover GET endpoints + stock override.


def t_admin_list_products():
    r = client.get('/api/v1/products', headers=ADMIN_HEADERS)
    return r.status_code == 200
check("Admin list products", t_admin_list_products)


def t_admin_list_products_paginated():
    r = client.get('/api/v1/products?skip=0&limit=10', headers=ADMIN_HEADERS)
    if r.status_code != 200:
        return f"Expected 200, got {r.status_code}"
    return True
check("Admin list products with pagination", t_admin_list_products_paginated)


def t_admin_list_products_search():
    r = client.get('/api/v1/products?search=indomie', headers=ADMIN_HEADERS)
    return r.status_code == 200
check("Admin list products with search", t_admin_list_products_search)


def t_admin_get_product_detail():
    # Pick any existing product
    r = client.get('/api/v1/products', headers=ADMIN_HEADERS)
    if r.status_code != 200 or not r.json():
        return f"No products to test"
    pid = r.json()[0]['id']
    r2 = client.get(f'/api/v1/products/{pid}', headers=ADMIN_HEADERS)
    return r2.status_code == 200
check("Admin get product detail", t_admin_get_product_detail)


def t_admin_update_product():
    """PUT /products/{id} — typically used for soft update of fields."""
    r = client.get('/api/v1/products', headers=ADMIN_HEADERS)
    if r.status_code != 200 or not r.json():
        return f"No products"
    pid = r.json()[0]['id']
    payload = {'nama_barang': r.json()[0].get('nama_barang', 'Updated')}
    r2 = client.put(f'/api/v1/products/{pid}', json=payload, headers=ADMIN_HEADERS)
    return r2.status_code == 200
check("Admin update product", t_admin_update_product)


def t_admin_override_stock():
    r = client.get('/api/v1/products', headers=ADMIN_HEADERS)
    if r.status_code != 200 or not r.json():
        return f"No products"
    pid = r.json()[0]['id']
    r2 = client.put(f'/api/v1/products/{pid}/stock', json={'stok_sistem': 300}, headers=ADMIN_HEADERS)
    return r2.status_code == 200
check("Admin override product stock (PUT /stock)", t_admin_override_stock)


def t_sales_cannot_override_stock():
    r = client.get('/api/v1/products', headers=ADMIN_HEADERS)
    if r.status_code != 200 or not r.json():
        return f"No products"
    pid = r.json()[0]['id']
    r2 = client.put(f'/api/v1/products/{pid}/stock', json={'stok_sistem': 500}, headers=SALES_HEADERS)
    return r2.status_code == 403
check("Sales cannot override stock (403)", t_sales_cannot_override_stock)


def t_admin_get_product_categories():
    r = client.get('/api/v1/products/kategori', headers=ADMIN_HEADERS)
    return r.status_code == 200
check("Admin get product categories", t_admin_get_product_categories)


def t_admin_get_product_stats():
    r = client.get('/api/v1/products/stats', headers=ADMIN_HEADERS)
    return r.status_code == 200
check("Admin get product stats", t_admin_get_product_stats)


def t_admin_get_product_count():
    r = client.get('/api/v1/products/count', headers=ADMIN_HEADERS)
    return r.status_code == 200
check("Admin get product count", t_admin_get_product_count)


def t_admin_get_suppliers_4p():
    r = client.get('/api/v1/products/suppliers/4p', headers=ADMIN_HEADERS)
    return r.status_code == 200
check("Admin get 4P suppliers", t_admin_get_suppliers_4p)


def t_admin_import_excel():
    """POST /products/import-excel — admin can import products via Excel."""
    # Use a tiny dummy Excel — endpoint expects multipart upload
    # Just check the endpoint exists (returns 400/422 for empty file is OK)
    files = {'file': ('test.xlsx', b'', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')}
    r = client.post('/api/v1/products/import-excel', files=files, headers=ADMIN_HEADERS)
    return r.status_code in (200, 400, 422)
check("Admin import-excel endpoint exists", t_admin_import_excel)


# ============================================================
print("\n=== Customers CRUD (admin only) ===")


def t_admin_list_customers():
    r = client.get('/api/v1/customers', headers=ADMIN_HEADERS)
    return r.status_code == 200
check("Admin list all customers", t_admin_list_customers)


def t_admin_list_customers_paginated():
    r = client.get('/api/v1/customers?skip=0&limit=10', headers=ADMIN_HEADERS)
    if r.status_code != 200:
        return f"Expected 200, got {r.status_code}"
    return True
check("Admin list customers paginated", t_admin_list_customers_paginated)


def t_admin_create_customer():
    payload = {
        'nama_toko': 'TEST Customer 1',
        'alamat': 'Test Alamat',
    }
    r = client.post('/api/v1/customers', json=payload, headers=ADMIN_HEADERS)
    return r.status_code in (200, 201)
check("Admin create customer", t_admin_create_customer)


def t_admin_create_customer_duplicate():
    payload = {
        'nama_toko': 'TEST Customer 1',
        'alamat': 'Test Alamat',
    }
    r = client.post('/api/v1/customers', json=payload, headers=ADMIN_HEADERS)
    return r.status_code in (400, 409)
check("Reject duplicate customer (nama+alamat)", t_admin_create_customer_duplicate)


def t_admin_get_customer_detail():
    db = SessionLocal()
    cust = db.query(Customer).filter(Customer.nama_toko.like('TEST Customer%')).first()
    db.close()
    if not cust:
        return f"No customer found"
    r = client.get(f'/api/v1/customers/{cust.id}', headers=ADMIN_HEADERS)
    return r.status_code == 200
check("Admin get customer detail", t_admin_get_customer_detail)


def t_admin_update_customer():
    db = SessionLocal()
    cust = db.query(Customer).filter(Customer.nama_toko.like('TEST Customer%')).first()
    db.close()
    if not cust:
        return f"No customer"
    r = client.put(f'/api/v1/customers/{cust.id}',
                   json={'nama_toko': 'TEST Customer Updated', 'alamat': 'New alamat'},
                   headers=ADMIN_HEADERS)
    return r.status_code == 200
check("Admin update customer", t_admin_update_customer)


def t_admin_get_customer_assignments():
    db = SessionLocal()
    cust = db.query(Customer).filter(Customer.nama_toko.like('TEST Customer%')).first()
    db.close()
    if not cust:
        return f"No customer"
    r = client.get(f'/api/v1/customers/{cust.id}/assignments', headers=ADMIN_HEADERS)
    return r.status_code == 200
check("Admin get customer assignments", t_admin_get_customer_assignments)


def t_admin_put_customer_assignments():
    db = SessionLocal()
    cust = db.query(Customer).filter(Customer.nama_toko.like('TEST Customer%')).first()
    sales = db.query(UserModel).filter(UserModel.username == 'sales.default').first()
    db.close()
    if not cust or not sales:
        return f"No customer/sales"
    payload = {'sales_ids': [str(sales.id)]}
    r = client.put(f'/api/v1/customers/{cust.id}/assignments', json=payload, headers=ADMIN_HEADERS)
    return r.status_code == 200
check("Admin assign customer to sales", t_admin_put_customer_assignments)


def t_admin_get_kode_areas():
    r = client.get('/api/v1/customers/kode-areas', headers=ADMIN_HEADERS)
    return r.status_code == 200
check("Admin get kode areas (for customer form)", t_admin_get_kode_areas)


def t_admin_get_customer_count():
    r = client.get('/api/v1/customers/count', headers=ADMIN_HEADERS)
    return r.status_code == 200
check("Admin get customer count", t_admin_get_customer_count)


# ============================================================
print("\n=== Orders: admin operations ===")


def _create_test_order_with_items():
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
        return None
    r = client.post('/api/v1/orders', json={
        'customer_id': str(cust.id),
        'order_type': 'REGULER',
        'store_name': 'TEST_admin_ops',
        'items': [{
            'product_id': product.id,
            'qty': 2,
            'discount_type': 'PERCENT',
            'discount_percent': 10.0,
            'discount_nominal': 0,
        }],
    }, headers=SALES_HEADERS)
    if r.status_code not in (200, 201):
        return None
    return r.json()


def t_admin_list_orders_paginated():
    r = client.get('/api/v1/orders?skip=0&limit=20', headers=ADMIN_HEADERS)
    if r.status_code != 200:
        return f"Expected 200, got {r.status_code}"
    return True
check("Admin list orders paginated", t_admin_list_orders_paginated)


def t_admin_list_orders_filtered_by_status():
    r = client.get('/api/v1/orders?status=APPROVED', headers=ADMIN_HEADERS)
    if r.status_code != 200:
        return f"Expected 200, got {r.status_code}"
    return True
check("Admin list orders filter by status", t_admin_list_orders_filtered_by_status)


def t_admin_list_orders_search():
    r = client.get('/api/v1/orders?search=TEST', headers=ADMIN_HEADERS)
    if r.status_code != 200:
        return f"Expected 200, got {r.status_code}"
    return True
check("Admin search orders", t_admin_list_orders_search)


def t_admin_list_orders_date_range():
    today = datetime.now().strftime('%Y-%m-%d')
    r = client.get(f'/api/v1/orders?date_from={today}&date_to={today}', headers=ADMIN_HEADERS)
    if r.status_code != 200:
        return f"Expected 200, got {r.status_code}"
    return True
check("Admin list orders date range", t_admin_list_orders_date_range)


def t_admin_x_total_count_header():
    r = client.get('/api/v1/orders?limit=5', headers=ADMIN_HEADERS)
    if r.status_code != 200:
        return f"Expected 200, got {r.status_code}"
    total = r.headers.get('x-total-count')
    if total is None:
        return f"X-Total-Count header missing"
    return True
check("Admin: X-Total-Count header returned", t_admin_x_total_count_header)


def t_admin_list_pending_orders():
    r = client.get('/api/v1/orders/pending', headers=ADMIN_HEADERS)
    if r.status_code != 200:
        return f"Expected 200, got {r.status_code}"
    return True
check("Admin list pending orders", t_admin_list_pending_orders)


def t_admin_get_order_detail():
    order = _create_test_order_with_items()
    if not order:
        return f"Setup failed"
    r = client.get(f'/api/v1/orders/{order["id"]}', headers=ADMIN_HEADERS)
    return r.status_code == 200
check("Admin get order detail", t_admin_get_order_detail)


def t_admin_approve_order():
    order = _create_test_order_with_items()
    if not order:
        return f"Setup failed"
    r = client.post(f'/api/v1/orders/{order["id"]}/submit', headers=SALES_HEADERS)
    if r.status_code != 200:
        return f"Submit failed: {r.status_code}"
    r = client.post(f'/api/v1/orders/{order["id"]}/approve', headers=ADMIN_HEADERS)
    if r.status_code != 200:
        return f"Approve failed: {r.status_code}"
    if r.json()['status'] != 'APPROVED':
        return f"Expected APPROVED, got {r.json()['status']}"
    return True
check("Admin approve order (PENDING→APPROVED)", t_admin_approve_order)


def t_admin_reject_order():
    order = _create_test_order_with_items()
    if not order:
        return f"Setup failed"
    r = client.post(f'/api/v1/orders/{order["id"]}/submit', headers=SALES_HEADERS)
    if r.status_code != 200:
        return f"Submit failed: {r.status_code}"
    r = client.post(f'/api/v1/orders/{order["id"]}/reject',
                    json={'reject_reason': 'Stok habis'},
                    headers=ADMIN_HEADERS)
    if r.status_code != 200:
        return f"Reject failed: {r.status_code}"
    if r.json()['status'] != 'REJECTED':
        return f"Expected REJECTED, got {r.json()['status']}"
    return True
check("Admin reject order (PENDING→REJECTED)", t_admin_reject_order)


def t_admin_update_discounts():
    order = _create_test_order_with_items()
    if not order:
        return f"Setup failed"
    r = client.post(f'/api/v1/orders/{order["id"]}/submit', headers=SALES_HEADERS)
    if r.status_code != 200:
        return f"Submit failed: {r.status_code}"
    db = SessionLocal()
    o = db.query(Order).options(joinedload(Order.items)).filter(
        Order.id == uuid_mod.UUID(order["id"])
    ).first()
    if not o or not o.items:
        db.close()
        return f"No items"
    item_id = str(o.items[0].id)
    db.close()
    r = client.put(f'/api/v1/orders/{order["id"]}/discounts', json={
        'items': [{'item_id': item_id, 'discount_type': 'PERCENT',
                    'discount_percent': 25.5, 'discount_nominal': 0}],
    }, headers=ADMIN_HEADERS)
    if r.status_code != 200:
        return f"Update failed: {r.status_code} {r.text[:200]}"
    return True
check("Admin update order discounts with Decimal", t_admin_update_discounts)


def t_admin_cancel_items():
    order = _create_test_order_with_items()
    if not order:
        return f"Setup failed"
    r = client.post(f'/api/v1/orders/{order["id"]}/submit', headers=SALES_HEADERS)
    if r.status_code != 200:
        return f"Submit failed: {r.status_code}"
    db = SessionLocal()
    o = db.query(Order).options(joinedload(Order.items)).filter(
        Order.id == uuid_mod.UUID(order["id"])
    ).first()
    if not o or not o.items:
        db.close()
        return f"No items"
    item_id = str(o.items[0].id)
    qty = o.items[0].qty
    db.close()
    r = client.put(f'/api/v1/orders/{order["id"]}/cancel-items', json={
        'items': [{'item_id': item_id, 'qty': qty, 'reason': 'Stok rusak'}],
    }, headers=ADMIN_HEADERS)
    return r.status_code == 200
check("Admin cancel items (the 422 fix)", t_admin_cancel_items)


def t_admin_cancel_items_short_reason():
    order = _create_test_order_with_items()
    if not order:
        return f"Setup failed"
    r = client.post(f'/api/v1/orders/{order["id"]}/submit', headers=SALES_HEADERS)
    if r.status_code != 200:
        return f"Submit failed: {r.status_code}"
    db = SessionLocal()
    o = db.query(Order).options(joinedload(Order.items)).filter(
        Order.id == uuid_mod.UUID(order["id"])
    ).first()
    if not o or not o.items:
        db.close()
        return f"No items"
    item_id = str(o.items[0].id)
    db.close()
    r = client.put(f'/api/v1/orders/{order["id"]}/cancel-items', json={
        'items': [{'item_id': item_id, 'qty': 1, 'reason': 'x'}],
    }, headers=ADMIN_HEADERS)
    return r.status_code == 422
check("Admin cancel items short reason (422)", t_admin_cancel_items_short_reason)


# ============================================================
print("\n=== Bulletins ===")


def t_admin_list_bulletins():
    r = client.get('/api/v1/bulletins', headers=ADMIN_HEADERS)
    return r.status_code == 200
check("Admin list bulletins", t_admin_list_bulletins)


def t_admin_create_bulletin():
    payload = {
        'title': 'TEST_Bulletin_1',
        'description': 'Test konten',
    }
    r = client.post('/api/v1/bulletins', json=payload, headers=ADMIN_HEADERS)
    return r.status_code in (200, 201)
check("Admin create bulletin", t_admin_create_bulletin)


def t_admin_get_bulletin_detail():
    db = SessionLocal()
    b = db.query(Bulletin).filter(Bulletin.title.like('TEST_Bulletin%')).first()
    db.close()
    if not b:
        return f"No bulletin"
    r = client.get(f'/api/v1/bulletins/{b.id}', headers=ADMIN_HEADERS)
    return r.status_code == 200
check("Admin get bulletin detail", t_admin_get_bulletin_detail)


def t_admin_update_bulletin():
    db = SessionLocal()
    b = db.query(Bulletin).filter(Bulletin.title.like('TEST_Bulletin%')).first()
    db.close()
    if not b:
        return f"No bulletin"
    r = client.put(f'/api/v1/bulletins/{b.id}',
                   json={'title': 'TEST_Bulletin_Updated', 'description': 'Updated'},
                   headers=ADMIN_HEADERS)
    return r.status_code == 200
check("Admin update bulletin", t_admin_update_bulletin)


def t_admin_delete_bulletin():
    db = SessionLocal()
    b = db.query(Bulletin).filter(Bulletin.title.like('TEST_Bulletin%')).first()
    db.close()
    if not b:
        return f"No bulletin"
    r = client.delete(f'/api/v1/bulletins/{b.id}', headers=ADMIN_HEADERS)
    return r.status_code == 200
check("Admin delete bulletin", t_admin_delete_bulletin)


def t_sales_cannot_create_bulletin():
    payload = {
        'title': 'TEST_Bulletin_Sales',
        'description': 'Test',
    }
    r = client.post('/api/v1/bulletins', json=payload, headers=SALES_HEADERS)
    return r.status_code == 403
check("Sales cannot create bulletin (403)", t_sales_cannot_create_bulletin)


def t_sales_dismiss_bulletin():
    """Sales can dismiss a bulletin (mobile feature)."""
    db = SessionLocal()
    b = db.query(Bulletin).filter(Bulletin.title.like('TEST_%') == False).first()
    if not b:
        r = client.post('/api/v1/bulletins', json={
            'title': 'TEST_for_dismiss', 'description': 'Test',
        }, headers=ADMIN_HEADERS)
        db = SessionLocal()
        b = db.query(Bulletin).filter(Bulletin.title == 'TEST_for_dismiss').first()
    b_id = str(b.id)
    db.close()
    r = client.post(f'/api/v1/bulletins/{b_id}/dismiss', headers=SALES_HEADERS)
    return r.status_code == 200
check("Sales dismiss bulletin", t_sales_dismiss_bulletin)


# ============================================================
print("\n=== Sales Targets ===")


def t_admin_set_sales_target():
    db = SessionLocal()
    sales = db.query(UserModel).filter(UserModel.username == 'sales.default').first()
    db.close()
    if not sales:
        return f"No sales"
    payload = {
        'period': '2026-10',
        'target_type': 'REVENUE',
        'target_value': 50000000,
        'incentive_amount': 500000,
    }
    r = client.put(f'/api/v1/sales-targets/{sales.id}', json=payload, headers=ADMIN_HEADERS)
    return r.status_code in (200, 201)
check("Admin set sales target", t_admin_set_sales_target)


def t_admin_get_sales_targets():
    db = SessionLocal()
    sales = db.query(UserModel).filter(UserModel.username == 'sales.default').first()
    db.close()
    if not sales:
        return f"No sales"
    r = client.get(f'/api/v1/sales-targets/{sales.id}', headers=ADMIN_HEADERS)
    return r.status_code == 200
check("Admin get sales targets", t_admin_get_sales_targets)


def t_sales_cannot_set_target():
    db = SessionLocal()
    sales = db.query(UserModel).filter(UserModel.username == 'sales.default').first()
    db.close()
    if not sales:
        return f"No sales"
    payload = {'period': '2026-11', 'target_type': 'REVENUE', 'target_value': 1000}
    r = client.put(f'/api/v1/sales-targets/{sales.id}', json=payload, headers=SALES_HEADERS)
    return r.status_code == 403
check("Sales cannot set target (403)", t_sales_cannot_set_target)


def t_sales_get_own_target():
    r = client.get('/api/v1/sales-targets/my', headers=SALES_HEADERS)
    return r.status_code == 200
check("Sales get own target", t_sales_get_own_target)


def t_admin_list_all_sales_targets():
    r = client.get('/api/v1/sales-targets', headers=ADMIN_HEADERS)
    return r.status_code == 200
check("Admin list all sales targets", t_admin_list_all_sales_targets)


# ============================================================
print("\n=== Performance & Reports ===")


def t_admin_sales_performance():
    r = client.get('/api/v1/reports/sales-performance?from_date=2026-01-01&to_date=2026-12-31',
                   headers=ADMIN_HEADERS)
    return r.status_code == 200
check("Admin sales performance report", t_admin_sales_performance)


def t_admin_daily_report():
    today = datetime.now().strftime('%Y-%m-%d')
    r = client.get(f'/api/v1/reports/daily?date={today}', headers=ADMIN_HEADERS)
    return r.status_code == 200
check("Admin daily report", t_admin_daily_report)


def t_admin_period_report():
    r = client.get('/api/v1/reports/period?start_date=2026-01-01&end_date=2026-12-31',
                   headers=ADMIN_HEADERS)
    return r.status_code == 200
check("Admin period report", t_admin_period_report)


def t_admin_dashboard():
    r = client.get('/api/v1/reports/sales-performance/dashboard', headers=ADMIN_HEADERS)
    return r.status_code == 200
check("Admin dashboard", t_admin_dashboard)


# ============================================================
print("\n=== Users (admin) ===")


def t_admin_list_users():
    r = client.get('/api/v1/users', headers=ADMIN_HEADERS)
    return r.status_code == 200
check("Admin list users", t_admin_list_users)


def t_admin_create_user():
    payload = {
        'username': 'test_user_new',
        'password': 'testpass123',
        'role': 'SALES',
        'nama': 'Test User',
    }
    r = client.post('/api/v1/users', json=payload, headers=ADMIN_HEADERS)
    return r.status_code in (200, 201)
check("Admin create user", t_admin_create_user)


def t_admin_create_user_duplicate():
    payload = {
        'username': 'test_user_new',
        'password': 'testpass123',
        'role': 'SALES',
        'nama': 'Test User',
    }
    r = client.post('/api/v1/users', json=payload, headers=ADMIN_HEADERS)
    return r.status_code in (400, 409)
check("Reject duplicate user", t_admin_create_user_duplicate)


def t_admin_get_user_detail():
    db = SessionLocal()
    u = db.query(UserModel).filter(UserModel.username.like('test_%')).first()
    db.close()
    if not u:
        return f"No user"
    r = client.get(f'/api/v1/users/{u.id}', headers=ADMIN_HEADERS)
    return r.status_code == 200
check("Admin get user detail", t_admin_get_user_detail)


def t_admin_update_user():
    db = SessionLocal()
    u = db.query(UserModel).filter(UserModel.username.like('test_%')).first()
    db.close()
    if not u:
        return f"No user"
    r = client.put(f'/api/v1/users/{u.id}', json={'nama': 'Test User Updated'}, headers=ADMIN_HEADERS)
    return r.status_code == 200
check("Admin update user", t_admin_update_user)


def t_sales_cannot_delete_user():
    db = SessionLocal()
    u = db.query(UserModel).filter(UserModel.username.like('test_%')).first()
    db.close()
    if not u:
        return f"No user"
    r = client.delete(f'/api/v1/users/{u.id}', headers=SALES_HEADERS)
    return r.status_code == 403
check("Sales cannot delete user (403)", t_sales_cannot_delete_user)


def t_admin_delete_user():
    db = SessionLocal()
    u = db.query(UserModel).filter(UserModel.username.like('test_%')).first()
    db.close()
    if not u:
        return f"No user"
    r = client.delete(f'/api/v1/users/{u.id}', headers=ADMIN_HEADERS)
    return r.status_code == 200
check("Admin delete user", t_admin_delete_user)


def t_sales_cannot_list_users():
    r = client.get('/api/v1/users', headers=SALES_HEADERS)
    return r.status_code == 403
check("Sales cannot list users (403)", t_sales_cannot_list_users)


def t_sales_cannot_create_user():
    payload = {
        'username': 'test_user_sales_attempt',
        'password': 'test123',
        'role': 'SALES',
        'nama': 'Test',
    }
    r = client.post('/api/v1/users', json=payload, headers=SALES_HEADERS)
    return r.status_code == 403
check("Sales cannot create user (403)", t_sales_cannot_create_user)


def t_admin_get_sales_users_for_dropdown():
    r = client.get('/api/v1/users/sales', headers=ADMIN_HEADERS)
    return r.status_code == 200
check("Admin get SALES users (for dropdown)", t_admin_get_sales_users_for_dropdown)


# ============================================================
print("\n=== Area Assignments ===")


def t_admin_get_area_assignments():
    r = client.get('/api/v1/sales/area-assignments', headers=ADMIN_HEADERS)
    return r.status_code == 200
check("Admin list all area assignments", t_admin_get_area_assignments)


def t_admin_get_area_assignment_by_kode():
    r = client.get('/api/v1/sales/area-assignments/KPS', headers=ADMIN_HEADERS)
    return r.status_code == 200
check("Admin get area assignment by kode", t_admin_get_area_assignment_by_kode)


def t_admin_put_area_assignment():
    db = SessionLocal()
    sales = db.query(UserModel).filter(UserModel.username == 'sales.default').first()
    db.close()
    if not sales:
        return f"No sales"
    payload = {'sales_ids': [str(sales.id)]}
    r = client.put('/api/v1/sales/area-assignments/KPS', json=payload, headers=ADMIN_HEADERS)
    return r.status_code == 200
check("Admin assign sales to area", t_admin_put_area_assignment)


def t_admin_get_sales_customers():
    """Mobile: sales view their customers."""
    db = SessionLocal()
    sales = db.query(UserModel).filter(UserModel.username == 'sales.default').first()
    db.close()
    if not sales:
        return f"No sales"
    r = client.get(f'/api/v1/sales/{sales.id}/customers', headers=ADMIN_HEADERS)
    return r.status_code == 200
check("Admin get customers assigned to sales", t_admin_get_sales_customers)


# ============================================================
print("\n=== Sync (admin only) ===")


def t_admin_get_sync_errors():
    r = client.get('/api/v1/products/sync/errors', headers=ADMIN_HEADERS)
    return r.status_code == 200
check("Admin get sync errors", t_admin_get_sync_errors)


def t_admin_get_import_logs():
    r = client.get('/api/v1/products/import-logs', headers=ADMIN_HEADERS)
    return r.status_code == 200
check("Admin get import logs", t_admin_get_import_logs)


# ============================================================
print("\n=== Sales: my endpoints ===")


def t_sales_list_my_customers():
    r = client.get('/api/v1/customers/my', headers=SALES_HEADERS)
    return r.status_code == 200
check("Sales list my customers", t_sales_list_my_customers)


def t_sales_list_my_orders():
    r = client.get('/api/v1/orders/my', headers=SALES_HEADERS)
    return r.status_code == 200
check("Sales list my orders", t_sales_list_my_orders)


def t_sales_get_my_stats():
    r = client.get('/api/v1/orders/my/stats', headers=SALES_HEADERS)
    return r.status_code == 200
check("Sales get my order stats", t_sales_get_my_stats)


# ============================================================
print("\n=== Change password ===")


def t_admin_change_own_password():
    r = client.post('/api/v1/auth/change-password',
                    json={'old_password': 'admin123', 'new_password': 'admin1234'},
                    headers=ADMIN_HEADERS)
    if r.status_code == 200:
        # Reset back
        new_token = login('admin.default', 'admin1234')
        client.post('/api/v1/auth/change-password',
                    json={'old_password': 'admin1234', 'new_password': 'admin123'},
                    headers={'Authorization': f'Bearer {new_token}'})
    return r.status_code == 200
check("Admin change own password", t_admin_change_own_password)


# ============================================================
print("\n=== Validation: input safety ===")


def t_sql_injection_create_user():
    """SQL injection attempt in create user."""
    # Re-login to make sure token is fresh (after change_password test)
    fresh_token = login('admin.default', 'admin123')
    fresh_admin = {'Authorization': f'Bearer {fresh_token}'}
    payload = {
        'username': "test_inj'; DROP TABLE users;--",
        'password': 'test',
        'role': 'SALES',
        'nama': 'Test',
    }
    r = client.post('/api/v1/users', json=payload, headers=fresh_admin)
    if r.status_code not in (200, 201, 400, 422):
        return f"Unexpected: {r.status_code}: {r.text[:200]}"
    db = SessionLocal()
    count = db.query(UserModel).count()
    db.close()
    if count < 1:
        return f"Users table gone: {count}"
    return True
check("SQL injection in create user safely stored", t_sql_injection_create_user)


def t_overlong_nama_actually():
    payload = {
        'nama_langganan': 'TEST_overlong_' + 'X' * 300,
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
check("Reject overlong nama_langganan (422)", t_overlong_nama_actually)


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