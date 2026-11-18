import 'package:flutter_test/flutter_test.dart';
import 'package:admin_web/presentation/widgets/analytics/sales_analytics_models.dart';

SalesRankItem _item({
  String code = '',
  String label = '',
  String? motherSku,
  int revenue = 0,
}) {
  return SalesRankItem(
    code: code,
    label: label,
    qty: 1,
    revenue: revenue,
    motherSku: motherSku,
    productKode: code.isEmpty ? null : code,
  );
}

void main() {
  group('rankMatchKeys', () {
    test('motherSku diprioritaskan, lalu code, lalu label', () {
      final keys = rankMatchKeys(
        _item(code: '0223', label: 'Palmvita SHT DFF 1x15Kg CTN'),
      );
      expect(keys, ['0223', 'PALMVITA SHT DFF 1X15KG CTN']);
    });

    test('kunci kosong dilewati dan duplikat tidak diulang', () {
      final keys = rankMatchKeys(_item(label: 'Filmma'));
      expect(keys, ['FILMMA']);
    });

    test('normalisasi kapital dan spasi ganda', () {
      expect(
        normalizeRankMatchKey('  palmvita   sht  dff '),
        'PALMVITA SHT DFF',
      );
    });
  });

  group('buildRankMatchIndex + matchRankItem', () {
    test('product_kode berbeda tetap cocok lewat mother_sku', () {
      // Kasus dashboard GLOBAL: agregasi max() lintas cabang menghasilkan
      // product_kode berbeda antara payload pembanding dan bulan ini.
      final index = buildRankMatchIndex([
        _item(code: 'PRD-001', motherSku: 'SKU-PALM', revenue: 802),
      ]);
      final current = _item(code: 'PRD-999', motherSku: 'SKU-PALM');
      final matched = matchRankItem(index, current);

      expect(matched, isNotNull);
      expect(matched!.revenue, 802);
    });

    test('mother_sku kosong di satu sisi, cocok lewat nama ternormalisasi', () {
      final index = buildRankMatchIndex([
        _item(code: 'PRD-001', label: 'Palmvita SHT DFF 1x15Kg CTN'),
      ]);
      final current = _item(
        code: 'PRD-001',
        label: 'PALMVITA SHT DFF 1X15KG CTN',
        motherSku: 'SKU-PALM',
      );
      final matched = matchRankItem(index, current);

      expect(matched, isNotNull);
    });

    test('tanpa kunci yang sama, hasilnya null (tampil Rp 0)', () {
      final index = buildRankMatchIndex([
        _item(code: 'PRD-001', label: 'Produk A'),
      ]);
      expect(matchRankItem(index, _item(code: 'PRD-002', label: 'Produk B')),
          isNull);
    });
  });
}
