"""Penggabungan Stok By SKU memakai Mother SKU, bukan nama produk."""

from sqlalchemy import Column, Integer, String, create_engine, func
from sqlalchemy.orm import declarative_base, sessionmaker

from app.api.endpoints.reports import (
    _sku_group_expr,
    choose_sku_display_name,
    inventory_sku_key,
)

Base = declarative_base()


class _SkuRow(Base):
    __tablename__ = "sku_rows"
    id = Column(Integer, primary_key=True)
    mother_sku = Column(String)
    product_kode = Column(String)
    product_nama = Column(String)
    amount = Column(Integer)


def test_sku_key_ignores_case_and_extra_spaces():
    assert inventory_sku_key(" sku-palm15 ") == inventory_sku_key("SKU-PALM15")
    assert inventory_sku_key(None) == ""


def test_display_name_prefers_common_sales_name_over_return_spelling():
    name = choose_sku_display_name(
        "SKU-PALM15",
        {
            "sales": {"Palm 15 Liter": 2, "SKU-PALM15": 1},
            "stock": {"PALM 15": 4},
            "return": {"Palm 15 Liter (retur)": 3},
        },
    )
    assert name == "Palm 15 Liter"


def test_display_name_falls_back_to_stock_then_key():
    assert (
        choose_sku_display_name(
            "SKU-A",
            {"sales": {}, "stock": {"Produk A": 1}, "return": {"Retur A": 5}},
        )
        == "Produk A"
    )
    assert choose_sku_display_name("SKU-A", {}) == "SKU-A"


def test_sale_and_return_collapse_to_one_mother_sku():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    session = sessionmaker(bind=engine)()
    session.add_all(
        [
            _SkuRow(mother_sku=" sku-palm15 ", product_kode="A", product_nama="Palm Merah", amount=500),
            _SkuRow(mother_sku="SKU-PALM15", product_kode="B", product_nama="Palm Retur", amount=-100),
            _SkuRow(mother_sku=None, product_kode="C1", product_nama="Tanpa Induk", amount=40),
            _SkuRow(mother_sku="", product_kode="C1", product_nama="Tanpa Induk Retur", amount=-10),
        ]
    )
    session.commit()

    merged = {}
    expr = _sku_group_expr(_SkuRow)
    for raw_key, amount in session.query(expr, func.sum(_SkuRow.amount)).group_by(expr):
        key = inventory_sku_key(raw_key)
        merged[key] = merged.get(key, 0) + int(amount or 0)

    assert merged == {"SKU-PALM15": 400, "C1": 30}
    session.close()
