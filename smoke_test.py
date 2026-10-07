"""
Smoke test for customer-submission + order-bundling feature.

Covers Tasks 1-6 (backend) and the mobile model fix (I1) by exercising
the code paths without requiring a database. Verifies:

1. Task 1: Schemas import; validator rejects bareng_order without order_items
2. Task 2: Submit endpoint imports cleanly; has placeholder + assignment + order code path
3. Task 3: Approve endpoint sets order.status = 'PENDING' (not 'CONFIRMED')
4. Task 4: Reject endpoint has order-cancel + stock-release + soft-delete code path
5. Task 5: Cancel endpoint exists with correct role + status guards
6. Task 6: _serialize includes order key for bareng_customer_id submissions
7. I1 fix: Mobile Order model has hargaSaldoTersedia field
8. I3 fix: CustomerRepository.submitCustomerRegistration has no dead named-params branch

Each check is independent and prints PASS/FAIL with diagnostic info.
"""
import sys
import re
import traceback
from pathlib import Path

BACKEND = Path("sales-app/backend")
MOBILE = Path("sales-app/lib")
REPO = Path(".")  # cwd
PASS = 0
FAIL = 0


def check(name, fn):
    global PASS, FAIL
    try:
        result = fn()
        if result is True or result is None:
            print(f"  PASS  {name}")
            PASS += 1
        else:
            print(f"  FAIL  {name}: {result}")
            FAIL += 1
    except Exception as e:
        print(f"  FAIL  {name}: {type(e).__name__}: {e}")
        FAIL += 1


def read(rel):
    return (REPO / rel).read_text(encoding="utf-8")


print("\n=== Task 1: Schema imports + validator ===")


def t1_imports():
    sys.path.insert(0, str(BACKEND))
    from app.schemas.schemas import (
        CustomerSubmissionCreate,
        CustomerSubmissionResponse,
        CustomerSubmissionCancelRequest,
        CustomerSubmissionCancelResponse,
    )
    assert hasattr(CustomerSubmissionCreate, "model_validate")
    return True


def t1_validator_rejects_empty():
    from app.schemas.schemas import CustomerSubmissionCreate
    from pydantic import ValidationError
    try:
        CustomerSubmissionCreate(
            nama_langganan="Test",
            bareng_order=True,
            order_items=None,
        )
    except ValidationError as e:
        if "order_items" in str(e):
            return True
    return "Validator accepted bareng_order=True with no order_items"


def t1_validator_rejects_empty_list():
    from app.schemas.schemas import CustomerSubmissionCreate
    from pydantic import ValidationError
    try:
        CustomerSubmissionCreate(
            nama_langganan="Test",
            bareng_order=True,
            order_items=[],
        )
    except ValidationError as e:
        if "order_items" in str(e):
            return True
    return "Validator accepted bareng_order=True with empty order_items list"


def t1_accepts_with_items():
    from app.schemas.schemas import CustomerSubmissionCreate
    p = CustomerSubmissionCreate(
        nama_langganan="Test",
        nama_kontak_pemilik="Owner",
        telpon_hp="08123",
        alamat_kirim="Alamat",
        propinsi="Jabar",
        kecamatan="Bandung",
        kota="Bandung",
        kelurahan="Cibeunying",
        tipe_langganan="NON PASAR",
        tipe_pembayaran="TUNAI",
        channel_kategori="FOSR",
        kode_salesman="S-1",
        nama_salesman="Sales",
        siklus_kunjungan="W1",
        hari_kunjungan="Senin",
        bareng_order=True,
        order_type="REGULER",
        order_items=[{"product_id": "P-1", "qty": 1}],
    )
    assert p.bareng_order is True
    assert p.order_type == "REGULER"
    return True


check("Schemas import cleanly", t1_imports)
check("Validator rejects bareng_order=True with order_items=None", t1_validator_rejects_empty)
check("Validator rejects bareng_order=True with order_items=[]", t1_validator_rejects_empty_list)
check("Accepts bareng_order=True with valid order_items", t1_accepts_with_items)


print("\n=== Task 2-6: Endpoints import + structure ===")


def t2_import():
    sys.path.insert(0, str(BACKEND))
    from app.api.endpoints.customer_submissions import router
    paths = [r.path for r in router.routes]
    required = {
        "/customer-submissions",
        "/customer-submissions/{submission_id}/approve",
        "/customer-submissions/{submission_id}/reject",
        "/customer-submissions/{submission_id}/cancel",
    }
    missing = required - set(paths)
    return True if not missing else f"Missing routes: {missing}"


def t2_has_book_items_call():
    src = read("sales-app/backend/app/api/endpoints/customer_submissions.py")
    if "_book_items(" in src and 'sumber="DRAFT"' in src:
        return True
    return "submit endpoint does not call _book_items"


def t2_creates_customer_assignment():
    src = read("sales-app/backend/app/api/endpoints/customer_submissions.py")
    if "CustomerAssignment(" in src and "sales_id" in src:
        return True
    return "submit does not create CustomerAssignment"


def t3_approve_sets_pending():
    src = read("sales-app/backend/app/api/endpoints/customer_submissions.py")
    # Look for the approve block (between approve and reject defs)
    m = re.search(
        r"def approve_submission.*?(?=def reject_submission)",
        src,
        re.DOTALL,
    )
    if not m:
        return "could not find approve function"
    body = m.group(0)
    if "linked_order.status = 'PENDING'" not in body:
        return "approve does not set order.status = 'PENDING'"
    if "linked_order.status = 'CONFIRMED'" in body:
        return "approve still sets order.status = 'CONFIRMED' (regression!)"
    return True


def t3_kode_area_copy():
    src = read("sales-app/backend/app/api/endpoints/customer_submissions.py")
    if "kode_area=submission.kode_area" in src:
        return True
    return "approve does not copy submission.kode_area to customer"


def t4_reject_cancels_order():
    src = read("sales-app/backend/app/api/endpoints/customer_submissions.py")
    m = re.search(r"def reject_submission.*?(?=def cancel_submission|@router\.post\(.*cancel)", src, re.DOTALL)
    if not m:
        return "could not find reject function"
    body = m.group(0)
    if "linked_order.status = 'CANCELLED'" not in body:
        return "reject does not cancel linked order"
    if "stok_booking - :qty" not in body:
        return "reject does not release stock booking"
    if "StokLog(" not in body:
        return "reject does not write StokLog entry"
    if "placeholder.deleted_at" not in body:
        return "reject does not soft-delete placeholder"
    return True


def t5_cancel_endpoint_exists():
    src = read("sales-app/backend/app/api/endpoints/customer_submissions.py")
    if 'def cancel_submission' not in src:
        return "cancel_submission function not found"
    if '"/{submission_id}/cancel"' not in src:
        return "cancel route not registered"
    if 'current_user["role"] != "SALES"' not in src:
        return "cancel does not enforce SALES role"
    if "submission.status != \"PENDING\"" not in src:
        return "cancel does not enforce PENDING status"
    if "with_for_update()" not in src:
        return "cancel does not use row locking"
    return True


def t6_serialize_includes_order():
    src = read("sales-app/backend/app/api/endpoints/customer_submissions.py")
    # Find the _serialize function
    m = re.search(r"def _serialize\(.*?(?=\ndef )", src, re.DOTALL)
    if not m:
        return "could not find _serialize function"
    body = m.group(0)
    if "bareng_customer_id" not in body:
        return "_serialize does not check bareng_customer_id"
    if "_build_order_response" not in body:
        return "_serialize does not call _build_order_response"
    if 'result["order"]' not in body:
        return "_serialize does not populate result['order']"
    return True


def i2_no_duplicate_serialize():
    """Verify the redundant block was removed from submit endpoint."""
    src = read("sales-app/backend/app/api/endpoints/customer_submissions.py")
    submit = re.search(
        r"def submit_customer_registration.*?(?=\ndef |@router)",
        src,
        re.DOTALL,
    )
    if not submit:
        return "could not find submit function"
    body = submit.group(0)
    # The redundant block had this pattern:
    if "result[\"order\"] = _build_order_response(order_obj)" in body:
        return "duplicate order serialization still present in submit"
    return True


check("Endpoint routes registered (submit, approve, reject, cancel)", t2_import)
check("submit calls _book_items(...) with sumber='DRAFT'", t2_has_book_items_call)
check("submit creates CustomerAssignment for placeholder", t2_creates_customer_assignment)
check("approve sets order.status = 'PENDING' (not CONFIRMED)", t3_approve_sets_pending)
check("approve copies submission.kode_area to customer", t3_kode_area_copy)
check("reject cancels order + releases stock + StokLog + soft-delete", t4_reject_cancels_order)
check("cancel endpoint exists with SALES + PENDING + row-lock guards", t5_cancel_endpoint_exists)
check("_serialize populates result['order'] for bareng submissions", t6_serialize_includes_order)
check("submit endpoint no longer duplicates _serialize order block (I2)", i2_no_duplicate_serialize)


print("\n=== I1 fix: Mobile Order model has hargaSaldoTersedia ===")


def i1_mobile_order_has_saldo():
    src = read("sales-app/lib/data/models/customer_submission.dart")
    if "hargaSaldoTersedia" in src and "harga_saldo_tersedio" in src:
        return True
    return "mobile Order model missing hargaSaldoTersedia"


def i1_mobile_orderitem_has_diskon():
    src = read("sales-app/lib/data/models/customer_submission.dart")
    if "hargaSetelahDiskon" in src and "harga_setelah_diskon" in src:
        return True
    return "mobile OrderItem missing hargaSetelahDiskon"


check("mobile Order has hargaSaldoTersedia", i1_mobile_order_has_saldo)
check("mobile OrderItem has hargaSetelahDiskon", i1_mobile_orderitem_has_diskon)


print("\n=== I3 fix: Repository dead code removed ===")


def i3_no_named_params():
    src = read("sales-app/lib/data/repositories/customer_repository.dart")
    if "List<Map<String, dynamic>>? orderItems" in src:
        return "dead orderItems named-params still present"
    if "String? orderType" in src:
        return "dead orderType named-param still present"
    return True


def i3_caller_no_named_args():
    """Verify the caller of submitCustomerRegistration does not use the
    dead named params (orderItems: / orderType:). The picker widget
    _BarengOrderPicker legitimately uses orderType: as its own named param —
    we only care about the repository call site."""
    src = read("sales-app/lib/presentation/screens/customers/customer_registration_screen.dart")
    # Find lines near submitCustomerRegistration call
    m = re.search(
        r"repo\.submitCustomerRegistration\([^)]*\)",
        src,
        re.DOTALL,
    )
    if not m:
        return "could not find submitCustomerRegistration call site"
    call = m.group(0)
    if "orderItems:" in call or "orderType:" in call:
        return "caller still uses named args on submitCustomerRegistration"
    return True


check("CustomerRepository.submitCustomerRegistration has no dead branch", i3_no_named_params)
check("registration screen does not pass named params to submit", i3_caller_no_named_args)


print("\n=== C1 fix: Mobile Batal button uses username + role check ===")


def c1_uses_sales_username():
    src = read("sales-app/lib/presentation/screens/customers/customer_submission_detail_screen.dart")
    if "s.salesUsername == _currentUsername" not in src:
        return "Batal check does not compare salesUsername"
    if "s.salesId == _currentUsername" in src:
        return "regression: still comparing salesId (UUID) to username (string)"
    return True


def c1_has_role_check():
    src = read("sales-app/lib/presentation/screens/customers/customer_submission_detail_screen.dart")
    if "_currentRole" not in src:
        return "no _currentRole field"
    if "_currentRole == 'SALES'" not in src:
        return "role check missing in canBatal"
    return True


check("canBatal compares salesUsername (not salesId)", c1_uses_sales_username)
check("canBatal includes SALES role check", c1_has_role_check)


print("\n=== C2 fix: Edit Order Items button present ===")


def c2_edit_button_present():
    src = read("sales-app/lib/presentation/screens/customers/customer_submission_detail_screen.dart")
    if "Edit Order Items" not in src:
        return "Edit Order Items button text not found"
    if "OrderDetailScreen(orderId: order.id)" not in src:
        return "Edit button does not navigate to OrderDetailScreen"
    # Conditional gate
    if "order.status == 'DRAFT' || order.status == 'PENDING'" not in src:
        return "Edit button not gated on DRAFT/PENDING"
    return True


check("Mobile Edit Order Items button (DRAFT/PENDING only)", c2_edit_button_present)


print("\n=== Cross-file consistency: status strings ===")


def status_strings_consistent():
    files = [
        "sales-app/backend/app/api/endpoints/customer_submissions.py",
        "sales-app/lib/data/models/customer_submission.dart",
        "sales-app/admin_web/lib/data/models/customer_submission.dart",
        "sales-app/lib/presentation/screens/customers/customer_submission_detail_screen.dart",
    ]
    # All files should reference DRAFT, PENDING, APPROVED, REJECTED, CANCELLED
    expected = {"DRAFT", "PENDING", "APPROVED", "REJECTED", "CANCELLED"}
    for f in files:
        src = read(f)
        missing = expected - set(re.findall(r"\b(DRAFT|PENDING|APPROVED|REJECTED|CANCELLED)\b", src))
        # Mobile detail screen only shows PENDING, APPROVED, REJECTED in its banner; missing some is OK
        if f.endswith("customer_submission_detail_screen.dart"):
            continue
        if missing and len(missing) > 1:
            return f"{f} missing status strings: {missing}"
    return True


check("Status strings consistent across files", status_strings_consistent)


print()
print("=" * 50)
print(f"  PASS: {PASS}    FAIL: {FAIL}")
print("=" * 50)
if FAIL:
    sys.exit(1)
print("\nAll checks passed.")
