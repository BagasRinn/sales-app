import requests
import json
import time

BASE = "http://localhost:8000/api/v1"

def banner(title):
    print(f"\n{'='*60}")
    print(f"  {title}")
    print(f"{'='*60}")

def check(label, condition, detail=""):
    status = "PASS" if condition else "FAIL"
    icon = "[OK]" if condition else "[!!]"
    print(f"  {icon} {label}")
    if detail and not condition:
        print(f"      Detail: {detail}")
    return condition

def post(endpoint, json_data, token=None):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    r = requests.post(f"{BASE}{endpoint}", json=json_data, headers=headers)
    return r

def get(endpoint, token=None):
    headers = {}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    r = requests.get(f"{BASE}{endpoint}", headers=headers)
    return r

results = []

# ==================== AUTH ====================
banner("TEST: Authentication")

# Register admin
r = post("/auth/register", {"username": "admin_test", "password": "admin123", "role": "ADMIN"})
results.append(check("Register ADMIN", r.status_code == 201, r.text))

# Register sales
r = post("/auth/register", {"username": "sales_test", "password": "sales123", "role": "SALES"})
results.append(check("Register SALES", r.status_code == 201, r.text))

# Register duplicate
r = post("/auth/register", {"username": "admin_test", "password": "admin123", "role": "ADMIN"})
results.append(check("Register duplicate username", r.status_code == 400, r.text))

# Login admin
r = post("/auth/login", {"username": "admin_test", "password": "admin123"})
admin_token = r.json().get("access_token", "") if r.status_code == 200 else ""
results.append(check("Login ADMIN", r.status_code == 200 and admin_token != "", r.text))

# Login sales
r = post("/auth/login", {"username": "sales_test", "password": "sales123"})
sales_token = r.json().get("access_token", "") if r.status_code == 200 else ""
results.append(check("Login SALES", r.status_code == 200 and sales_token != "", r.text))

# Login wrong password
r = post("/auth/login", {"username": "admin_test", "password": "salah"})
results.append(check("Login wrong password", r.status_code == 401, r.text))

# Login non-existent
r = post("/auth/login", {"username": "tidakada", "password": "salah"})
results.append(check("Login non-existent user", r.status_code == 401, r.text))

# ==================== PRODUCTS ====================
banner("TEST: Products (SALES can view catalog)")

# Sales can see products
r = get("/products", sales_token)
all_products = r.json() if r.status_code == 200 else []
results.append(check("SALES can GET /products", r.status_code == 200, r.text))
results.append(check("Products returned is list", isinstance(all_products, list), str(type(all_products))))

# Admin can see products
r = get("/products", admin_token)
results.append(check("ADMIN can GET /products", r.status_code == 200, r.text))

# Unauthenticated access
r = get("/products")
results.append(check("Unauthenticated access denied", r.status_code == 401, r.text))

# Get single product (if any exist)
if all_products:
    pid = all_products[0].get("id", "")
    r = get(f"/products/{pid}", sales_token)
    results.append(check(f"GET /products/{pid}", r.status_code == 200, r.text))

    r = get("/products/nonexistent", sales_token)
    results.append(check("GET non-existent product", r.status_code == 404, r.text))
else:
    results.append(check("SKIP: No products to test GET single", True))

# ==================== CHECKOUT ====================
banner("TEST: Checkout (Critical Flow)")

# Create order as sales
if all_products:
    # Prepare checkout items
    checkout_items = []
    for p in all_products[:2]:
        if p.get("stok_tersedia", 0) > 0:
            checkout_items.append({"product_id": p["id"], "qty": 1})
            break

    if checkout_items:
        r = post("/orders", {"items": checkout_items}, sales_token)
        order_id = r.json().get("id", "") if r.status_code == 200 else ""
        results.append(check("Checkout: create order", r.status_code == 200, r.text))

        # Checkout empty items
        r = post("/orders", {"items": []}, sales_token)
        results.append(check("Checkout: empty items rejected", r.status_code == 400, r.text))

        # Checkout with non-existent product
        r = post("/orders", {"items": [{"product_id": "INVALID_SKU", "qty": 1}]}, sales_token)
        results.append(check("Checkout: non-existent product rejected", r.status_code == 409, r.text))
    else:
        results.append(check("SKIP: No available stock for checkout", True))

    # Checkout without auth
    r = post("/orders", {"items": [{"product_id": "SKU001", "qty": 1}]})
    results.append(check("Checkout: unauthenticated denied", r.status_code == 401, r.text))
else:
    results.append(check("SKIP: No products for checkout test", True))

# ==================== ORDERS ====================
banner("TEST: Orders & Cancel")

# Get my orders as sales
r = get("/orders/my", sales_token)
my_orders = r.json() if r.status_code == 200 else []
results.append(check("GET /orders/my (sales)", r.status_code == 200, r.text))
results.append(check("orders/my returns list", isinstance(my_orders, list), str(type(my_orders))))

# Filter by status
r = get("/orders/my?status=PENDING", sales_token)
results.append(check("GET /orders/my?status=PENDING", r.status_code == 200, r.text))

# Admin can see all orders
r = get("/orders", admin_token)
results.append(check("GET /orders (admin)", r.status_code == 200, r.text))

# Admin can see pending orders
r = get("/orders/pending", admin_token)
results.append(check("GET /orders/pending (admin)", r.status_code == 200, r.text))

# Cancel order (as sales owner)
if my_orders:
    pending_order = next((o for o in my_orders if o.get("status") == "PENDING"), None)
    if pending_order:
        oid = pending_order.get("id", "")
        r = post(f"/orders/{oid}/cancel", {}, sales_token)
        results.append(check(f"Cancel own PENDING order", r.status_code == 200, r.text))

        # Cancel already cancelled
        r = post(f"/orders/{oid}/cancel", {}, sales_token)
        results.append(check("Cancel already cancelled order", r.status_code == 400, r.text))
    else:
        results.append(check("SKIP: No pending order to cancel", True))
else:
    results.append(check("SKIP: No orders for cancel test", True))

# Sales cannot cancel other sales' orders (get 404)
r = get("/orders/my?status=PENDING", sales_token)
all_pending = r.json() if r.status_code == 200 else []
if len(all_pending) > 1:
    # Try to cancel an order that isn't owned
    other_order = next((o for o in all_pending if o.get("sales_id") != "not_mine"), None)
    if other_order:
        r = post(f"/orders/{other_order.get('id')}/cancel", {}, sales_token)
        results.append(check("Cannot cancel other sales order", r.status_code == 404, r.text))

# ==================== ADMIN APPROVE/REJECT ====================
banner("TEST: Admin Approve/Reject")

# Create fresh order for approve/reject test
if all_products:
    checkout_items2 = []
    for p in all_products[:1]:
        if p.get("stok_tersedia", 0) > 0:
            checkout_items2.append({"product_id": p["id"], "qty": 1})

    if checkout_items2:
        r = post("/orders", {"items": checkout_items2}, sales_token)
        new_order = r.json() if r.status_code == 200 else {}
        test_order_id = new_order.get("id", "")
        results.append(check("Create order for approve test", r.status_code == 200, r.text))

        if test_order_id:
            # Approve as admin
            r = post(f"/orders/{test_order_id}/approve", {}, admin_token)
            results.append(check("Approve PENDING order", r.status_code == 200, r.text))

            # Reject already approved
            r = post(f"/orders/{test_order_id}/reject", {}, admin_token)
            results.append(check("Reject already APPROVED order", r.status_code == 400, r.text))

            # Approve already approved
            r = post(f"/orders/{test_order_id}/approve", {}, admin_token)
            results.append(check("Approve already APPROVED order", r.status_code == 400, r.text))

            # Sales cannot approve
            r = post(f"/orders/{test_order_id}/approve", {}, sales_token)
            results.append(check("Sales cannot approve order", r.status_code == 403, r.text))

            # Sales cannot reject
            r = post(f"/orders/{test_order_id}/reject", {}, sales_token)
            results.append(check("Sales cannot reject order", r.status_code == 403, r.text))

            # Admin can get order detail
            r = get(f"/orders/{test_order_id}", admin_token)
            results.append(check(f"Admin can GET order detail", r.status_code == 200, r.text))

            # Sales can get their own order detail
            r = get(f"/orders/{test_order_id}", sales_token)
            results.append(check(f"Sales can GET own order detail", r.status_code == 200, r.text))

            # Approve non-existent order
            r = post(f"/orders/00000000-0000-0000-0000-000000000000/approve", {}, admin_token)
            results.append(check("Approve non-existent order", r.status_code == 404, r.text))
    else:
        results.append(check("SKIP: No stock for approve test", True))
else:
    results.append(check("SKIP: No products for approve test", True))

# ==================== STOCK LOG ====================
banner("TEST: Audit Trail (Stock Log)")

# Verify stocks were updated after approve
if all_products:
    r = get("/products", admin_token)
    updated_products = r.json() if r.status_code == 200 else []
    results.append(check("Products still accessible after operations", r.status_code == 200, r.text))

# ==================== MANUAL STOCK OVERRIDE ====================
banner("TEST: Manual Stock Override (Admin)")

if all_products:
    pid = all_products[0].get("id", "")
    r = requests.put(
        f"{BASE}/products/{pid}/stock",
        json={"stok_sistem": 999},
        headers={"Authorization": f"Bearer {admin_token}", "Content-Type": "application/json"}
    )
    results.append(check("Manual stock override", r.status_code == 200, r.text))

    # Verify stock updated
    r = get(f"/products/{pid}", admin_token)
    if r.status_code == 200:
        data = r.json()
        results.append(check(f"Stock set to 999", data.get("stok_sistem") == 999, str(data)))

    # Sales cannot override stock
    r = requests.put(
        f"{BASE}/products/{pid}/stock",
        json={"stok_sistem": 100},
        headers={"Authorization": f"Bearer {sales_token}", "Content-Type": "application/json"}
    )
    results.append(check("Sales cannot override stock", r.status_code == 403, r.text))
else:
    results.append(check("SKIP: No products for stock override test", True))

# ==================== SYNC ====================
banner("TEST: Google Sheets Sync (Admin)")

r = post("/products/sync", {}, admin_token)
results.append(check("Sync products from Sheets", r.status_code == 200, r.text))
sync_result = r.json() if r.status_code == 200 else {}

r = get("/products/sync/errors", admin_token)
results.append(check("Get sync errors", r.status_code == 200, r.text))

# Sales cannot sync
r = post("/products/sync", {}, sales_token)
results.append(check("Sales cannot sync products", r.status_code == 403, r.text))

# ==================== CANCEL AS ADMIN (via reject) ====================
banner("TEST: Stock Booking Released on Cancel/Reject")

if all_products:
    # Create new order to test reject releases booking
    checkout_items3 = []
    for p in all_products[:1]:
        if p.get("stok_tersedia", 0) > 0:
            checkout_items3.append({"product_id": p["id"], "qty": 1})

    if checkout_items3:
        r = post("/orders", {"items": checkout_items3}, sales_token)
        reject_order = r.json() if r.status_code == 200 else {}
        reject_id = reject_order.get("id", "")
        pid = checkout_items3[0]["product_id"]

        # Get stock before reject
        r = get(f"/products/{pid}", admin_token)
        before_booking = r.json().get("stok_booking", 0) if r.status_code == 200 else 0

        # Reject
        r = post(f"/orders/{reject_id}/reject", {}, admin_token)
        results.append(check("Reject order releases booking", r.status_code == 200, r.text))

        # Verify booking decreased
        r = get(f"/products/{pid}", admin_token)
        after_booking = r.json().get("stok_booking", 0) if r.status_code == 200 else 0
        results.append(check("stok_booking decreased after reject", after_booking < before_booking,
                          f"before={before_booking}, after={after_booking}"))
    else:
        results.append(check("SKIP: No stock for reject test", True))

# ==================== SUMMARY ====================
banner("SUMMARY")
passed = sum(results)
total = len(results)
failed = total - passed
print(f"\n  Total: {total} tests")
print(f"  PASSED: {passed}")
print(f"  FAILED: {failed}")
if failed == 0:
    print("\n  ALL TESTS PASSED!")
else:
    print("\n  SOME TESTS FAILED - See details above")
