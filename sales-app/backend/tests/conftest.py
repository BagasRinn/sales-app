"""Pytest configuration for backend tests.

Defines a marker and a session-level cleanup that removes any leaked
test data after the test session ends. The per-test `db` fixture
already manages per-test transaction rollback, but this is a safety
net in case something slips through (e.g. a connection leak in
TestClient that bypasses the shared transaction).
"""
import pytest


def pytest_configure(config):
    config.addinivalue_line(
        "markers",
        "isolation: marks tests that verify per-branch data isolation",
    )


@pytest.fixture(scope="session", autouse=True)
def _cleanup_test_data_after_session():
    """Delete any rows matching the test-data patterns after the test
    session finishes. The DB is live for sales operations, so we must
    not leave test data behind even if a fixture bug causes leakage."""
    yield
    # Late import: avoid loading the SQLAlchemy engine at conftest import
    # time, which would slow down simple `pytest --collect-only`.
    from sqlalchemy import text
    from app.models.database import engine

    with engine.begin() as conn:
        # Order matters: children before parents.
        conn.execute(text("""
            DELETE FROM order_items WHERE order_id IN (
                SELECT id FROM orders WHERE customer_id IN (
                    SELECT id FROM customers WHERE nama_toko='Test Customer'
                )
            )
        """))
        conn.execute(text("""
            DELETE FROM orders WHERE customer_id IN (
                SELECT id FROM customers WHERE nama_toko='Test Customer'
            )
        """))
        conn.execute(text(
            "DELETE FROM customers WHERE nama_toko='Test Customer'"
        ))
        conn.execute(text(
            "DELETE FROM products WHERE id LIKE 'PROD-%'"
        ))
        conn.execute(text("""
            DELETE FROM supplier_targets
            WHERE supplier_name LIKE 'TEST-%'
               OR supplier_name IN ('S1', 'X', 'PT Y', '')
        """))
