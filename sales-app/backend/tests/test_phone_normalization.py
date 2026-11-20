"""Unit test normalisasi nomor WhatsApp (tanpa DB)."""
from app.core.phone import normalize_phone_number


def test_local_08_number_becomes_62():
    assert normalize_phone_number("081234567890") == "6281234567890"


def test_plus_62_number():
    assert normalize_phone_number("+62 812-3456-7890") == "6281234567890"


def test_separators_and_parentheses_removed():
    assert normalize_phone_number("(0812) 3456 7890") == "6281234567890"


def test_double_country_prefix_with_trunk_zero():
    assert normalize_phone_number("62081234567890") == "6281234567890"


def test_bare_8_number_gets_country_code():
    assert normalize_phone_number("81234567890") == "6281234567890"


def test_already_standard_is_unchanged():
    assert normalize_phone_number("6281234567890") == "6281234567890"


def test_empty_and_none():
    assert normalize_phone_number(None) == ""
    assert normalize_phone_number("   ") == ""


def test_non_indonesian_digits_are_not_fabricated():
    # LID / nomor asing: digit dipertahankan, tidak dipaksa jadi 62.
    assert normalize_phone_number("123456789012345") == "123456789012345"
