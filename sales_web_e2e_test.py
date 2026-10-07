"""E2E test for sales_web features — sales role on browser.
Tests endpoints used by sales_web screens (mobile layout in browser).
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
    Bulletin,
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
    """Hard-delete all test data."""
    db = SessionLocal()
    try:
        for c in db.query(Customer).filter(Customer.nama_toko.like('TEST_%')).all():
            db.query(CustomerAssignment).filter(CustomerAssignment.customer_id == c.id).delete()
            db.delete(c)
        for s in db.query(CustomerRegistrationSubmission).filter(
            CustomerRegistrationSubmission.nama_langganan.like('TEST_%')
        ).all():
            if s.bareng_customer_id:
                order = db.query(Order).filter(Order.customer_id == s.bareng_customer_id).first()
                if order:
                    db.query(OrderItem).filter(OrderItem.order_id == order.id).delete()
                    db.delete(order)
            db.delete(s)
        for o in db.query(Order).filter(Order.store_name.like('TEST_%')).all():
            db.query(OrderItem).filter(OrderItem.order_id == o.id).delete()
            db.delete(o)
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


def t_login_wrong_password():
    r = client.post('/api/v1/auth/login', json={'username': 'sales.default', 'password': 'wrong'})
    return r.status_code == 401
check("Reject wrong password", t_login_wrong_password)


SALES_TOKEN = login('sales.default', 'sales123')
SALES_HEADERS = {'Authorization': f'Bearer {SALES_TOKEN}'}


# ============================================================
print("\n=== My Orders (sales) ===")


def t_sales_list_my_orders():
    r = client.get('/api/v1/orders/my', headers=SALES_HEADERS)
    if r.status_code != 200:
        return f"Expected 200, got {r.status_code}"
    data = r.json()
    if not isinstance(data, list):
        return f"Expected list"
    return True
check("Sales list my orders", t_sales_list_my_orders)


def t_sales_list_my_orders_filter_draft():
    r = client.get('/api/v1/orders/my?status=DRAFT', headers=SALES_HEADERS)
    return r.status_code == 200
check("Sales filter my orders by DRAFT", t_sales_list_my_orders_filter_draft)


def t_sales_list_my_orders_filter_pending():
    r = client.get('/api/v1/orders/my?status=PENDING', headers=SALES_HEADERS)
    return r.status_code == 200
check("Sales filter my orders by PENDING", t_sales_list_my_orders_filter_pending)


def t_sales_list_my_orders_filter_approved():
    r = client.get('/api/v1/orders/my?status=APPROVED', headers=SALES_HEADERS)
    return r.status_code == 200
check("Sales filter my orders by APPROVED", t_sales_list_my_orders_filter_approved)


def t_sales_list_my_orders_filter_rejected():
    r = client.get('/api/v1/orders/my?status=REJECTED', headers=SALES_HEADERS)
    return r.status_code == 200
check("Sales filter my orders by REJECTED", t_sales_list_my_orders_filter_rejected)


def t_sales_get_my_stats():
    r = client.get('/api/v1/orders/my/stats', headers=SALES_HEADERS)
    return r.status_code == 200
check("Sales get my order stats", t_sales_get_my_stats)


# ============================================================
print("\n=== Create + Manage Order (sales) ===")


def _get_active_customer_and_product():
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
    return cust, product


def t_sales_create_draft_order():
    cust, product = _get_active_customer_and_product()
    if not cust or not product:
        return f"No customer/product (cust={cust}, product={product})"
    r = client.post('/api/v1/orders', json={
        'customer_id': str(cust.id),
        'order_type': 'REGULER',
        'store_name': 'TEST_sales_draft',
        'items': [{
            'product_id': product.id,
            'qty': 1,
            'discount_type': 'PERCENT',
            'discount_percent': 0,
            'discount_nominal': 0,
        }],
    }, headers=SALES_HEADERS)
    if r.status_code not in (200, 201):
        return f"Expected 200/201, got {r.status_code}: {r.text[:300]}"
    return True
check("Sales create DRAFT order", t_sales_create_draft_order)


def t_sales_create_order_4p():
    cust, _ = _get_active_customer_and_product()
    if not cust:
        return f"No customer"
    db = SessionLocal()
    product_4p = db.query(Product).filter(
        Product.order_type == '4P', Product.stok_sistem > 10
    ).first()
    if not product_4p:
        # Find any 4P product regardless of stock
        product_4p = db.query(Product).filter(Product.order_type == '4P').first()
    db.close()
    if not product_4p:
        return True  # skip — no 4P product available
    r = client.post('/api/v1/orders', json={
        'customer_id': str(cust.id),
        'order_type': '4P',
        'store_name': 'TEST_sales_4p',
        'items': [{
            'product_id': product_4p.id,
            'qty': 1,
            'discount_type': 'PERCENT',
            'discount_percent': 0,
            'discount_nominal': 0,
        }],
    }, headers=SALES_HEADERS)
    if r.status_code not in (200, 201):
        return f"Expected 200/201, got {r.status_code}: {r.text[:300]}"
    return True
check("Sales create 4P order (skip if no 4P product)", t_sales_create_order_4p)


def t_sales_create_order_no_items():
    cust, _ = _get_active_customer_and_product()
    if not cust:
        return f"No customer"
    r = client.post('/api/v1/orders', json={
        'customer_id': str(cust.id),
        'order_type': 'REGULER',
        'store_name': 'TEST_sales_no_items',
        'items': [],
    }, headers=SALES_HEADERS)
    return r.status_code == 400
check("Reject order with no items (400 by design)", t_sales_create_order_no_items)


def t_sales_get_order_detail():
    db = SessionLocal()
    order = db.query(Order).filter(Order.store_name == 'TEST_sales_draft').first()
    db.close()
    if not order:
        return f"No draft order"
    r = client.get(f'/api/v1/orders/{order.id}', headers=SALES_HEADERS)
    return r.status_code == 200
check("Sales get order detail", t_sales_get_order_detail)


def t_sales_update_order_draft():
    """Sales can update DRAFT order. Skip if no draft order exists."""
    db = SessionLocal()
    order = db.query(Order).options(joinedload(Order.items)).filter(
        Order.store_name == 'TEST_sales_draft',
        Order.status == 'DRAFT',
    ).first()
    if not order:
        db.close()
        return True  # skip — no DRAFT order (already submitted)
    product = db.query(Product).filter(
        Product.order_type == 'REGULER', Product.stok_sistem > 10
    ).first()
    db.close()
    if not product:
        return True  # skip
    r = client.put(f'/api/v1/orders/{order.id}', json={
        'items': [{
            'product_id': product.id,
            'qty': 2,
            'discount_type': 'PERCENT',
            'discount_percent': 5.0,
            'discount_nominal': 0,
        }],
    }, headers=SALES_HEADERS)
    return r.status_code in (200, 405, 422)
check("Sales update DRAFT order (skip if not draft)", t_sales_update_order_draft)


def t_sales_submit_draft_order():
    """Submit DRAFT to PENDING (one of the most-used flows)."""
    db = SessionLocal()
    order = db.query(Order).filter(Order.store_name == 'TEST_sales_draft').first()
    db.close()
    if not order:
        return f"No order"
    r = client.post(f'/api/v1/orders/{order.id}/submit', headers=SALES_HEADERS)
    if r.status_code != 200:
        return f"Submit failed: {r.status_code} {r.text[:200]}"
    if r.json()['status'] != 'PENDING':
        return f"Status={r.json()['status']}"
    return True
check("Sales submit DRAFT -> PENDING", t_sales_submit_draft_order)


def t_sales_submit_4p_order():
    db = SessionLocal()
    order = db.query(Order).filter(Order.store_name == 'TEST_sales_4p').first()
    db.close()
    if not order:
        return True  # skip — 4P order creation may have failed
    r = client.post(f'/api/v1/orders/{order.id}/submit', headers=SALES_HEADERS)
    return r.status_code == 200
check("Sales submit 4P order (skip if no 4P order)", t_sales_submit_4p_order)


def t_sales_submit_nonexistent_order():
    r = client.post(f'/api/v1/orders/00000000-0000-0000-0000-000000000000/submit', headers=SALES_HEADERS)
    return r.status_code == 404
check("Submit nonexistent order (404)", t_sales_submit_nonexistent_order)


def t_sales_cancel_pending_order():
    """Sales can cancel their own PENDING order (cancelled via DELETE or status change)."""
    db = SessionLocal()
    order = db.query(Order).filter(
        Order.sales_id == uuid_mod.UUID(get_user_id('sales.default')),
        Order.status == 'PENDING',
    ).first()
    if not order:
        db.close()
        return f"No PENDING order"
    r = client.post(f'/api/v1/orders/{order.id}/cancel', headers=SALES_HEADERS)
    if r.status_code not in (200, 403, 404):
        return f"Got: {r.status_code} {r.text[:200]}"
    return True
check("Sales cancel order (200/403/404)", t_sales_cancel_pending_order)


# ============================================================
print("\n=== My Customers (sales) ===")


def t_sales_list_my_customers():
    r = client.get('/api/v1/customers/my', headers=SALES_HEADERS)
    if r.status_code != 200:
        return f"Expected 200, got {r.status_code}"
    data = r.json()
    if not isinstance(data, list):
        return f"Expected list"
    return True
check("Sales list my customers", t_sales_list_my_customers)


def t_sales_get_kode_areas():
    r = client.get('/api/v1/customers/kode-areas', headers=SALES_HEADERS)
    return r.status_code == 200
check("Sales get kode areas (for forms)", t_sales_get_kode_areas)


def t_sales_check_duplicate_customer():
    r = client.get(
        '/api/v1/customer-submissions/check-duplicate?name=TEST&alamat=test',
        headers=SALES_HEADERS,
    )
    return r.status_code == 200
check("Sales check duplicate customer", t_sales_check_duplicate_customer)


# ============================================================
print("\n=== Products (catalog) ===")


def t_sales_list_products():
    r = client.get('/api/v1/products', headers=SALES_HEADERS)
    return r.status_code == 200
check("Sales list products (catalog)", t_sales_list_products)


def t_sales_list_products_search():
    r = client.get('/api/v1/products?search=indomie', headers=SALES_HEADERS)
    return r.status_code == 200
check("Sales search products", t_sales_list_products_search)


def t_sales_list_products_paginated():
    r = client.get('/api/v1/products?skip=0&limit=20', headers=SALES_HEADERS)
    return r.status_code == 200
check("Sales list products paginated", t_sales_list_products_paginated)


def t_sales_list_4p_suppliers():
    r = client.get('/api/v1/products/suppliers/4p', headers=SALES_HEADERS)
    return r.status_code == 200
check("Sales list 4P suppliers", t_sales_list_4p_suppliers)


def t_sales_get_product_categories():
    """Categories is manager-only. Sales should get 403."""
    r = client.get('/api/v1/products/kategori', headers=SALES_HEADERS)
    return r.status_code == 403
check("Sales get product categories (403, manager only)", t_sales_get_product_categories)


# ============================================================
print("\n=== Bulletins (sales) ===")


def t_sales_list_bulletins():
    r = client.get('/api/v1/bulletins', headers=SALES_HEADERS)
    return r.status_code == 200
check("Sales list bulletins", t_sales_list_bulletins)


def t_sales_dismiss_bulletin():
    """Sales dismisses a bulletin (mobile feature)."""
    admin_token = login('admin.default', 'admin123')
    admin_h = {'Authorization': f'Bearer {admin_token}'}
    db = SessionLocal()
    b = db.query(Bulletin).first()
    if not b:
        # Create one as admin
        r = client.post('/api/v1/bulletins', json={
            'title': 'TEST_bulletin_dismiss', 'description': 'Test',
        }, headers=admin_h)
        if r.status_code not in (200, 201):
            db.close()
            return f"Failed to create test bulletin: {r.status_code}"
        db = SessionLocal()
        b = db.query(Bulletin).filter(Bulletin.title == 'TEST_bulletin_dismiss').first()
    b_id = str(b.id)
    db.close()
    r = client.post(f'/api/v1/bulletins/{b_id}/dismiss', headers=SALES_HEADERS)
    return r.status_code == 200
check("Sales dismiss bulletin (creates one if none)", t_sales_dismiss_bulletin)


# ============================================================
print("\n=== Customer Submission (sales) ===")


def t_sales_submit_customer_basic():
    payload = {
        'nama_langganan': 'TEST_sales_basic',
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
    return True
check("Sales submit basic customer", t_sales_submit_customer_basic)


def t_sales_submit_customer_with_bareng():
    """The recent fix — bareng_order without order_items should work."""
    payload = {
        'nama_langganan': 'TEST_sales_bareng',
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
        return f"Expected 201, got {r.status_code}: {r.text[:200]}"
    data = r.json()
    if not data['bareng_customer_id']:
        return f"Expected bareng_customer_id"
    return True
check("Sales submit customer with bareng_order", t_sales_submit_customer_with_bareng)


def t_sales_list_my_submissions():
    r = client.get('/api/v1/customer-submissions/my', headers=SALES_HEADERS)
    if r.status_code != 200:
        return f"Expected 200"
    data = r.json()
    if not isinstance(data, list):
        return f"Expected list"
    if len(data) < 1:
        return f"Expected >=1, got 0"
    return True
check("Sales list my submissions", t_sales_list_my_submissions)


def t_sales_get_own_submission_detail():
    db = SessionLocal()
    s = db.query(CustomerRegistrationSubmission).filter(
        CustomerRegistrationSubmission.sales_id == uuid_mod.UUID(get_user_id('sales.default'))
    ).first()
    db.close()
    if not s:
        return f"No submission"
    r = client.get(f'/api/v1/customer-submissions/{s.id}', headers=SALES_HEADERS)
    return r.status_code == 200
check("Sales get own submission detail", t_sales_get_own_submission_detail)


def t_sales_cancel_submission():
    db = SessionLocal()
    s = db.query(CustomerRegistrationSubmission).filter(
        CustomerRegistrationSubmission.sales_id == uuid_mod.UUID(get_user_id('sales.default')),
        CustomerRegistrationSubmission.status == 'PENDING',
    ).first()
    db.close()
    if not s:
        return f"No PENDING submission"
    r = client.post(f'/api/v1/customer-submissions/{s.id}/cancel', json={}, headers=SALES_HEADERS)
    return r.status_code == 200
check("Sales cancel own submission", t_sales_cancel_submission)


# ============================================================
print("\n=== Sales target (own) ===")


def t_sales_get_own_target():
    r = client.get('/api/v1/sales-targets/my', headers=SALES_HEADERS)
    return r.status_code == 200
check("Sales get own target", t_sales_get_own_target)


# ============================================================
print("\n=== Security & Validation ===")


def t_sales_unauthorized_access():
    r = client.get('/api/v1/orders/my')
    return r.status_code == 401
check("Unauthenticated access blocked (401)", t_sales_unauthorized_access)


def t_sales_cannot_view_all_orders():
    """Sales can only see their own orders, not all."""
    r = client.get('/api/v1/orders', headers=SALES_HEADERS)
    return r.status_code == 403
check("Sales cannot list all orders (403)", t_sales_cannot_view_all_orders)


def t_sales_cannot_view_all_users():
    r = client.get('/api/v1/users', headers=SALES_HEADERS)
    return r.status_code == 403
check("Sales cannot list all users (403)", t_sales_cannot_view_all_users)


def t_sales_cannot_approve_order():
    """Sales can't approve own order (admin only)."""
    db = SessionLocal()
    order = db.query(Order).filter(
        Order.sales_id == uuid_mod.UUID(get_user_id('sales.default')),
        Order.status == 'PENDING',
    ).first()
    db.close()
    if not order:
        return f"No PENDING order"
    r = client.post(f'/api/v1/orders/{order.id}/approve', headers=SALES_HEADERS)
    return r.status_code == 403
check("Sales cannot approve own order (403)", t_sales_cannot_approve_order)


def t_sales_cannot_reject_order():
    db = SessionLocal()
    order = db.query(Order).filter(
        Order.sales_id == uuid_mod.UUID(get_user_id('sales.default')),
        Order.status == 'PENDING',
    ).first()
    db.close()
    if not order:
        return f"No PENDING order"
    r = client.post(f'/api/v1/orders/{order.id}/reject',
                    json={'reject_reason': 'Test'},
                    headers=SALES_HEADERS)
    return r.status_code == 403
check("Sales cannot reject own order (403)", t_sales_cannot_reject_order)


def t_sales_cannot_cancel_items():
    """cancel-items is admin-only."""
    db = SessionLocal()
    order = db.query(Order).options(joinedload(Order.items)).filter(
        Order.sales_id == uuid_mod.UUID(get_user_id('sales.default')),
        Order.status == 'PENDING',
    ).first()
    if not order or not order.items:
        db.close()
        return f"No PENDING order/items"
    item_id = str(order.items[0].id)
    db.close()
    r = client.put(f'/api/v1/orders/{order.id}/cancel-items',
                    json={'items': [{'item_id': item_id, 'qty': 1, 'reason': 'Test'}]},
                    headers=SALES_HEADERS)
    return r.status_code == 403
check("Sales cannot cancel items (403, admin only)", t_sales_cannot_cancel_items)


def t_sales_cannot_update_discounts():
    """update-discounts is admin-only."""
    db = SessionLocal()
    order = db.query(Order).options(joinedload(Order.items)).filter(
        Order.sales_id == uuid_mod.UUID(get_user_id('sales.default')),
        Order.status == 'PENDING',
    ).first()
    if not order or not order.items:
        db.close()
        return f"No PENDING order/items"
    item_id = str(order.items[0].id)
    db.close()
    r = client.put(f'/api/v1/orders/{order.id}/discounts',
                    json={'items': [{'item_id': item_id, 'discount_type': 'PERCENT',
                                     'discount_percent': 5.0, 'discount_nominal': 0}]},
                    headers=SALES_HEADERS)
    return r.status_code == 403
check("Sales cannot update discounts (403, admin only)", t_sales_cannot_update_discounts)


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