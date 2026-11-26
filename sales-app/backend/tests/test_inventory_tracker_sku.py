"""Penggabungan Stok By SKU memakai Mother SKU, bukan nama produk."""

import ast
from pathlib import Path

from sqlalchemy import Column, Integer, String, create_engine, func
from sqlalchemy.orm import declarative_base, sessionmaker

from app.api.endpoints.reports import (
    _sku_group_expr,
    choose_sku_label,
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


def test_sku_key_ignores_punctuation_and_spacing():
    # Satu produk yang sama ditulis berbeda format di tiap file laporan.
    assert inventory_sku_key("MOMOGI BINTANG COKLAT ( 4 X 10 )") == inventory_sku_key(
        "MOMOGI BINTANG COKLAT 4 X 10"
    )
    assert inventory_sku_key("P BALING2 CANDY 30/24") == inventory_sku_key(
        "P. BALING2 CANDY 30/24"
    )
    # Urutan angka tetap dibedakan karena bisa jadi produk berbeda.
    assert inventory_sku_key("KRESEK HD DUO 40 HITAM I 50 LEMBAR") != inventory_sku_key(
        "KRESEK HD DUO 50 HITAM I 40 LEMBAR"
    )


def test_label_uses_most_common_mother_sku_spelling():
    # Label baris memakai ejaan Mother SKU mentah yang paling sering muncul,
    # bukan nama produk — konsisten dengan kunci penggabungannya.
    assert (
        choose_sku_label("MOMOGI4X10", {"MOMOGI ( 4 X 10 )": 7, "MOMOGI 4 X 10": 2})
        == "MOMOGI ( 4 X 10 )"
    )


def test_label_breaks_vote_ties_alphabetically():
    # Seri suara dipecah alfabetis supaya label stabil antar-request.
    assert (
        choose_sku_label("SKUPALM15", {"SKU-PALM15 A": 1, "SKU-PALM15 B": 1})
        == "SKU-PALM15 A"
    )


def test_label_falls_back_to_canonical_key_without_spellings():
    assert choose_sku_label("FILMAPROF18LJRC", {}) == "FILMAPROF18LJRC"


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
            # Ejaan Mother SKU berbeda format untuk produk yang sama.
            _SkuRow(mother_sku="MOMOGI ( 4 X 10 )", product_kode="D", product_nama="Momogi", amount=70),
            _SkuRow(mother_sku="MOMOGI 4 X 10", product_kode="E", product_nama="Momogi", amount=30),
        ]
    )
    session.commit()

    merged = {}
    expr = _sku_group_expr(_SkuRow)
    for raw_key, amount in session.query(expr, func.sum(_SkuRow.amount)).group_by(expr):
        key = inventory_sku_key(raw_key)
        merged[key] = merged.get(key, 0) + int(amount or 0)

    assert merged == {"SKUPALM15": 400, "C1": 30, "MOMOGI4X10": 100}
    session.close()


def test_month_variable_not_shadowed_in_inventory_tracker():
    """Header bulan Stok By SKU pernah menampilkan nama produk.

    Loop pelabelan dulu menimpa variabel bulan `normalized` dengan kunci SKU,
    sehingga respons `month` berisi misalnya "YUMMYGUMMYSATE1X12" dan kolom
    bulan berjalan di tabel ikut menampilkan nama produk. Guard ini memastikan
    variabel bulan `report_month` hanya diisi sekali (dari parse_month) dan
    tidak pernah ditimpa di loop mana pun. Kalau butuh variabel serupa di
    loop, pakai nama lain (mis. label_key).
    """
    source = (
        Path(__file__).resolve().parents[1]
        / "app"
        / "api"
        / "endpoints"
        / "reports.py"
    )
    tree = ast.parse(source.read_text(encoding="utf-8"))
    fn = next(
        node
        for node in ast.walk(tree)
        if isinstance(node, ast.FunctionDef) and node.name == "get_inventory_tracker"
    )
    stores = [
        node.id
        for node in ast.walk(fn)
        if isinstance(node, ast.Name) and isinstance(node.ctx, ast.Store)
    ]
    assert stores.count("report_month") == 1, (
        "Variabel bulan report_month tidak boleh ditimpa di tengah "
        "get_inventory_tracker; pakai nama variabel lain di loop."
    )
