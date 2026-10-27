import uuid

from fastapi.testclient import TestClient
import pytest
from sqlalchemy import text

from app.core.security import create_access_token
from app.main import app
from app.models.database import engine

BRANCH = "BANJARMASIN"


@pytest.mark.parametrize("simulate_missing_booking", [False, True])
def test_delete_draft_with_missing_booking_releases_safely(
    simulate_missing_booking: bool,
):
    user_id = str(uuid.uuid4())
    customer_id = str(uuid.uuid4())
    product_id = f"TEST-DELETE-DRAFT-{uuid.uuid4().hex[:8]}"
    order_id = None

    with engine.begin() as conn:
        conn.execute(
            text(
                "INSERT INTO users "
                "(id, username, password_hash, role, branch, is_active, token_version) "
                "VALUES (:id, :username, 'test-hash', 'SALES', :branch, true, 0)"
            ),
            {
                "id": user_id,
                "username": f"TEST-DELETE-DRAFT-{user_id[:8]}",
                "branch": BRANCH,
            },
        )
        conn.execute(
            text(
                "INSERT INTO customers (id, kode, nama_toko, branch) "
                "VALUES (:id, :kode, 'Test Delete Draft', :branch)"
            ),
            {
                "id": customer_id,
                "kode": f"TEST-DELETE-DRAFT-{customer_id[:8]}",
                "branch": BRANCH,
            },
        )
        conn.execute(
            text(
                "INSERT INTO customer_assignments (customer_id, sales_id) "
                "VALUES (:customer_id, :sales_id)"
            ),
            {"customer_id": customer_id, "sales_id": user_id},
        )
        conn.execute(
            text(
                "INSERT INTO products "
                "(id, branch, nama_barang, harga, stok_sistem, stok_booking, "
                "stok_diterima, order_type) "
                "VALUES (:id, :branch, 'Test Delete Draft', 1000, 20, 0, 0, 'REGULER')"
            ),
            {"id": product_id, "branch": BRANCH},
        )

    headers = {
        "Authorization": "Bearer "
        + create_access_token(
            {
                "sub": user_id,
                "username": "test-delete-draft",
                "role": "SALES",
                "branch": BRANCH,
                "token_version": 0,
            }
        )
    }

    try:
        client = TestClient(app)
        create_response = client.post(
            "/api/v1/orders",
            headers=headers,
            json={
                "customer_id": customer_id,
                "items": [{"product_id": product_id, "qty": 2}],
                "order_type": "REGULER",
            },
        )
        assert create_response.status_code == 200, create_response.text
        order_id = create_response.json()["id"]

        if simulate_missing_booking:
            with engine.begin() as conn:
                conn.execute(
                    text(
                        "UPDATE products SET stok_booking = 0 "
                        "WHERE id = :id AND branch = :branch"
                    ),
                    {"id": product_id, "branch": BRANCH},
                )

        delete_response = client.delete(
            f"/api/v1/orders/{order_id}",
            headers=headers,
        )
        assert delete_response.status_code == 204, delete_response.text

        with engine.connect() as conn:
            product = conn.execute(
                text(
                    "SELECT stok_booking FROM products "
                    "WHERE id = :id AND branch = :branch"
                ),
                {"id": product_id, "branch": BRANCH},
            ).first()
            item_count = conn.execute(
                text("SELECT count(*) FROM order_items WHERE order_id = :order_id"),
                {"order_id": order_id},
            ).scalar_one()
            order_count = conn.execute(
                text("SELECT count(*) FROM orders WHERE id = :order_id"),
                {"order_id": order_id},
            ).scalar_one()
            linked_log_count = conn.execute(
                text("SELECT count(*) FROM stok_log WHERE order_id = :order_id"),
                {"order_id": order_id},
            ).scalar_one()

        assert product is not None
        assert product.stok_booking == 0
        assert item_count == 0
        assert order_count == 0
        assert linked_log_count == 0
    finally:
        with engine.begin() as conn:
            if order_id is not None:
                conn.execute(
                    text("DELETE FROM stok_log WHERE order_id = :order_id"),
                    {"order_id": order_id},
                )
                conn.execute(
                    text("DELETE FROM order_items WHERE order_id = :order_id"),
                    {"order_id": order_id},
                )
                conn.execute(
                    text("DELETE FROM orders WHERE id = :order_id"),
                    {"order_id": order_id},
                )
            conn.execute(
                text("DELETE FROM stok_log WHERE product_id = :product_id"),
                {"product_id": product_id},
            )
            conn.execute(
                text("DELETE FROM products WHERE id = :product_id AND branch = :branch"),
                {"product_id": product_id, "branch": BRANCH},
            )
            conn.execute(
                text("DELETE FROM customer_assignments WHERE customer_id = :customer_id"),
                {"customer_id": customer_id},
            )
            conn.execute(
                text("DELETE FROM customers WHERE id = :customer_id"),
                {"customer_id": customer_id},
            )
            conn.execute(text("DELETE FROM users WHERE id = :user_id"), {"user_id": user_id})