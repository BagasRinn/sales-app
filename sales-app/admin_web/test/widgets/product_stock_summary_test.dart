import 'package:flutter_test/flutter_test.dart';
import 'package:admin_web/presentation/widgets/analytics/sales_analytics_models.dart';

ProductStockSummary _summary() {
  return ProductStockSummary.fromMap({
    'month': '2026-11',
    'scope': 'GLOBAL',
    'total_good_amount': 1500,
    'sku_count': 3,
    'by_product': [
      {'key': 'SKU-PALM15', 'label': 'Palmvita SHT DFF 1x15Kg CTN', 'good_amount': 1000},
      {'key': 'SKU-MENARA', 'label': 'Menara MGRN 1x15kg Ctn', 'good_amount': 500},
    ],
    'by_supplier': [
      {'key': 'PT MINYAK NUSANTARA', 'label': 'PT Minyak Nusantara', 'good_amount': 1500},
    ],
    'by_divisi': [
      {'key': 'SNACK', 'label': 'SNACK', 'good_amount': 1500},
    ],
  });
}

void main() {
  group('ProductStockSummary.fromMap', () {
    test('mem-parse total, bucket, dan jumlah SKU', () {
      final s = _summary();
      expect(s.month, '2026-11');
      expect(s.totalGoodAmount, 1500);
      expect(s.skuCount, 3);
      expect(s.products, hasLength(2));
      expect(s.products.first.label, 'Palmvita SHT DFF 1x15Kg CTN');
      expect(s.products.first.goodAmount, 1000);
      expect(s.isEmpty, isFalse);
    });

    test('kunci lookup ternormalisasi untuk pencocokan kartu ranking', () {
      final s = _summary();
      expect(s.productByKey['SKU-PALM15'], 1000);
      expect(s.supplierByKey['PT MINYAK NUSANTARA'], 1500);
      // Lookup memakai kunci ternormalisasi (upper + spasi rapat).
      expect(normalizeRankMatchKey('snack'), 'SNACK');
      expect(s.divisiByKey['SNACK'], 1500);
      expect(
        s.divisiByKey[normalizeRankMatchKey('snack')],
        1500,
        reason: 'lookup kunci hasil normalisasi harus ketemu',
      );
    });

    test('payload kosong tetap valid dan isEmpty', () {
      final s = ProductStockSummary.fromMap(const {});
      expect(s.totalGoodAmount, 0);
      expect(s.products, isEmpty);
      expect(s.isEmpty, isTrue);
    });

    test('StockRankItem displayLabel fallback ke key', () {
      const item = StockRankItem(key: 'K1', label: '', goodAmount: 5);
      expect(item.displayLabel, 'K1');
    });
  });
}
