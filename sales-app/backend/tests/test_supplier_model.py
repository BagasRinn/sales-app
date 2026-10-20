from app.models.models import Supplier


def test_supplier_model_table_and_columns():
    table = Supplier.__table__
    assert table.name == "suppliers"
    # PK must be `name` (matches Product.nama_supplier), not a surrogate id
    assert [c.name for c in table.primary_key.columns] == ["name"]
    # is_active defaults to True
    is_active_col = table.columns["is_active"]
    assert is_active_col.default.arg is True
    assert is_active_col.nullable is False
    # timestamps
    assert "created_at" in table.columns
    assert "updated_at" in table.columns
