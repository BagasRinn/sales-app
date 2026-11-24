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

  group('outletMatchKeys', () {
    SalesRankItem outlet({
      required String branch,
      required String code,
      required String label,
      int revenue = 0,
    }) {
      return SalesRankItem(
        code: code,
        label: label,
        qty: 1,
        revenue: revenue,
        branch: branch,
      );
    }

    test('kode sama di cabang berbeda tidak saling tertukar', () {
      // Kode pelanggan hanya unik per cabang. Pareto Outlet pernah menempelkan
      // omzet Bobby FC ke TK. Tribus Lestari karena keduanya berkode C001.
      final index = buildOutletMatchIndex([
        outlet(
          branch: 'BANJARMASIN',
          code: 'C001',
          label: 'Bobby FC',
          revenue: 88250000,
        ),
        outlet(
          branch: 'BARABAI',
          code: 'C001',
          label: 'TK. Tribus Lestari',
          revenue: 123550000,
        ),
      ]);

      final bobby = matchOutletItem(
        index,
        outlet(branch: 'Banjarmasin', code: 'c001', label: 'BOBBY FC'),
      );
      final tribus = matchOutletItem(
        index,
        outlet(branch: 'BARABAI', code: 'C001', label: 'Toko Lain'),
      );

      expect(bobby?.label, 'Bobby FC');
      expect(bobby?.revenue, 88250000);
      expect(tribus?.label, 'TK. Tribus Lestari');
      expect(tribus?.revenue, 123550000);
    });

    test('outlet tanpa kode tetap cocok lewat nama di cabang yang sama', () {
      final index = buildOutletMatchIndex([
        outlet(branch: 'BANJARMASIN', code: '', label: 'Mentari', revenue: 10),
      ]);

      expect(
        matchOutletItem(
          index,
          outlet(branch: 'BANJARMASIN', code: '', label: 'MENTARI'),
        )?.revenue,
        10,
      );
      expect(
        matchOutletItem(
          index,
          outlet(branch: 'BARABAI', code: '', label: 'Mentari'),
        ),
        isNull,
      );
    });
  });
}
