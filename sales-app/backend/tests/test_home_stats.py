import uuid

from fastapi.testclient import TestClient
from sqlalchemy import text

from app.core.security import create_access_token
from app.main import app
from app.models.database import engine

BRANCH = "BANJARMASIN"


def test_home_stats_include_approved_count_and_pending_value():
    user_id = str(uuid.uuid4())
    customer_id = str(uuid.uuid4())
    product_id = f"TEST-HOME-STATS-{uuid.uuid4().hex[:8]}"
    order_ids: list[str] = []

    with engine.begin() as conn:
        conn.execute(
            text(
                "INSERT INTO users "
                "(id, username, password_hash, role, branch, is_active, token_version) "
                "VALUES (:id, :username, 'test-hash', 'SALES', :branch, true, 0)"
            ),
            {
                "id": user_id,
                "username": f"TEST-HOME-STATS-{user_id[:8]}",
                "branch": BRANCH,
            },
        )
        conn.execute(
            text(
                "INSERT INTO customers (id, kode, nama_toko, branch) "
                "VALUES (:id, :kode, 'Test Home Stats', :branch)"
            ),
            {
                "id": customer_id,
                "kode": f"TEST-HOME-STATS-{customer_id[:8]}",
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
                "VALUES (:id, :branch, 'Test Home Stats', 1000, 100, 0, 0, 'REGULER')"
            ),
            {"id": product_id, "branch": BRANCH},
        )

    headers = {
        "Authorization": "Bearer "
        + create_access_token(
            {
                "sub": user_id,
                "username": "test-home-stats",
                "role": "SALES",
                "branch": BRANCH,
                "token_version": 0,
            }
        )
    }

    try:
        client = TestClient(app)
        approved = client.post(
            "/api/v1/orders",
            headers=headers,
            json={
                "customer_id": customer_id,
                "items": [{"product_id": product_id, "qty": 2}],
                "order_type": "REGULER",
            },
        )
        assert approved.status_code == 200, approved.text
        approved_id = approved.json()["id"]
        order_ids.append(approved_id)
        with engine.begin() as conn:
            conn.execute(
                text("UPDATE orders SET status = 'APPROVED' WHERE id = :id"),
                {"id": approved_id},
            )

        pending = client.post(
            "/api/v1/orders",
            headers=headers,
            json={
                "customer_id": customer_id,
                "items": [{"product_id": product_id, "qty": 3}],
                "order_type": "REGULER",
            },
        )
        assert pending.status_code == 200, pending.text
        pending_id = pending.json()["id"]
        order_ids.append(pending_id)
        submit = client.post(f"/api/v1/orders/{pending_id}/submit", headers=headers)
        assert submit.status_code == 200, submit.text

        response = client.get("/api/v1/orders/my/stats", headers=headers)
        assert response.status_code == 200, response.text
        stats = response.json()

        assert stats["omset_hari_ini"] == 2000
        assert stats["approved_count_today"] == 1
        assert stats["pending_count"] == 1
        assert stats["pending_value"] == 3000
    finally:
        with engine.begin() as conn:
            if order_ids:
                conn.execute(
                    text(
                        "DELETE FROM stok_log WHERE order_id = ANY(:order_ids)"
                    ),
                    {"order_ids": order_ids},
                )
                conn.execute(
                    text("DELETE FROM order_items WHERE order_id = ANY(:order_ids)"),
                    {"order_ids": order_ids},
                )
                conn.execute(
                    text("DELETE FROM orders WHERE id = ANY(:order_ids)"),
                    {"order_ids": order_ids},
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