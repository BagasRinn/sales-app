"""Unit test murni untuk mesin diskon & up price.

File ini TIDAK menyentuh database: hanya memanggil fungsi kalkulasi murni di
`app.api.endpoints.orders`. Aman dijalankan kapan saja, termasuk saat jam
operasional.

Fokus: memastikan pembulatan half-up konsisten dan urutan 3 layer diskon
berjalan sequential (layer berikutnya memotong sisa subtotal, bukan subtotal
awal).
"""
import pytest

from app.api.endpoints.orders import (
    _apply_3_layers,
    _layer_cut,
    _normalize_layer,
    _up_price_per_piece,
)


class TestLayerCut:
    def test_nominal_dipotong_penuh_jika_muat(self):
        assert _layer_cut("NOMINAL", 0, 150, 1000) == 150

    def test_nominal_di_cap_ke_sisa_subtotal(self):
        assert _layer_cut("NOMINAL", 0, 150, 100) == 100

    def test_nominal_tidak_negatif(self):
        assert _layer_cut("NOMINAL", 0, -50, 100) == 0

    def test_percent_dihitung_dari_sisa(self):
        assert _layer_cut("PERCENT", 10, 0, 1000) == 100

    def test_percent_pakai_half_up_bukan_bankers_rounding(self):
        # Python round(2.5) == 2 (banker's). Sistem harus menghasilkan 3.
        assert _layer_cut("PERCENT", 2.5, 0, 100) == 3
        assert _layer_cut("PERCENT", 0.5, 0, 100) == 1

    def test_percent_negatif_di_clamp_ke_nol(self):
        assert _layer_cut("PERCENT", -10, 0, 1000) == 0

    def test_percent_nol(self):
        assert _layer_cut("PERCENT", 0, 0, 1000) == 0


class TestApply3Layers:
    def test_chain_sequential(self):
        # 1000 -> -10% (100) = 900 -> -10% (90) = 810 -> -50 = 760
        final, d1, d2, d3, total = _apply_3_layers(
            1000,
            "PERCENT", 10, 0,
            "PERCENT", 10, 0,
            "NOMINAL", 0, 50,
        )
        assert (d1, d2, d3) == (100, 90, 50)
        assert total == 240
        assert final == 760

    def test_layer2_memotong_sisa_bukan_subtotal_awal(self):
        # Kalau layer 2 memotong 10% dari 1000, hasilnya 800 (bukan 810).
        final, _, d2, _, _ = _apply_3_layers(
            1000,
            "PERCENT", 10, 0,
            "PERCENT", 10, 0,
            "PERCENT", 0, 0,
        )
        assert d2 == 90
        assert final == 810

    def test_nominal_tidak_bisa_membuat_subtotal_negatif(self):
        final, d1, d2, d3, total = _apply_3_layers(
            100,
            "NOMINAL", 0, 500,
            "PERCENT", 50, 0,
            "NOMINAL", 0, 100,
        )
        assert final == 0
        assert total == 100
        assert (d1, d2, d3) == (100, 0, 0)

    def test_subtotal_negatif_di_clamp_ke_nol(self):
        final, d1, d2, d3, total = _apply_3_layers(
            -500,
            "PERCENT", 10, 0,
            "PERCENT", 10, 0,
            "PERCENT", 10, 0,
        )
        assert (final, d1, d2, d3, total) == (0, 0, 0, 0, 0)


class TestUpPrice:
    def test_nominal_langsung(self):
        assert _up_price_per_piece(1000, "NOMINAL", 0, 250) == 250

    def test_percent_dari_harga_satuan(self):
        assert _up_price_per_piece(1000, "PERCENT", 10, 0) == 100

    def test_percent_half_up(self):
        assert _up_price_per_piece(1000, "PERCENT", 2.5, 0) == 25
        assert _up_price_per_piece(10, "PERCENT", 5, 0) == 1

    def test_nominal_negatif_di_clamp_ke_nol(self):
        assert _up_price_per_piece(1000, "NOMINAL", 0, -100) == 0


class TestNormalizeLayer:
    def test_none_jadi_default_percent_nol(self):
        assert _normalize_layer(None, None, None) == ("PERCENT", 0.0, 0)

    def test_type_dinormalisasi_ke_uppercase(self):
        assert _normalize_layer("nominal", 0, 500) == ("NOMINAL", 0.0, 500)

    @pytest.mark.parametrize("percent", [12.5, 0, 100])
    def test_percent_dikonversi_ke_float(self, percent):
        _, p, _ = _normalize_layer("PERCENT", percent, 0)
        assert isinstance(p, float)
        assert p == float(percent)
