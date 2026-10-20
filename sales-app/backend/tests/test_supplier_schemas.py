from app.schemas.schemas import (
    SupplierResponse,
    SupplierCreate,
    SupplierActiveUpdate,
)


def test_supplier_response_round_trip():
    r = SupplierResponse(
        name="Mulia", is_active=True, product_count=12,
        created_at="2026-10-15T00:00:00+08:00",
        updated_at="2026-10-15T00:00:00+08:00",
    )
    j = r.model_dump()
    assert j["name"] == "Mulia"
    assert j["is_active"] is True
    assert j["product_count"] == 12


def test_supplier_create_rejects_empty_name():
    import pytest
    from pydantic import ValidationError
    with pytest.raises(ValidationError):
        SupplierCreate(name="")


def test_supplier_active_update_requires_bool():
    s = SupplierActiveUpdate(is_active=False)
    assert s.is_active is False
