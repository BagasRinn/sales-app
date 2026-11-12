import 'package:flutter_test/flutter_test.dart';
import 'package:admin_web/presentation/widgets/analytics/sales_analytics_models.dart';

void main() {
  test(
    'range summary builds all calendar days and reads margin dimensions',
    () {
      final analytics = SalesAnalytics.fromSummary({
        'range_months': 3,
        'total_revenue': 100000,
        'total_margin': -5000,
        'total_retur_revenue': 15000,
        'total_retur_margin': -500,
        'total_retur_rows': 2,
        'imported_rows': 4,
        'by_product': [
          {
            'product_kode': 'P001',
            'product_nama': 'Produk',
            'mother_sku': 'M001',
            'revenue': 100000,
            'margin': -5000,
          },
        ],
        'by_divisi': [
          {'divisi': 'Bangunan', 'revenue': 100000, 'margin': -5000},
        ],
        'by_supplier': [
          {'supplier': 'Supplier Utama', 'revenue': 100000, 'margin': -5000},
        ],
        'by_supplier_retur': [
          {
            'supplier': 'Supplier Utama',
            'revenue': 15000,
            'margin': -500,
            'row_count': 2,
            'supplier_net_revenue': 85000,
          },
        ],
        'sales_targets': [
          {
            'name': 'Yusuf Hidayat',
            'name_key': 'YUSUF HIDAYAT',
            'value': 200000,
          },
        ],
        'supplier_targets': [
          {
            'name': 'CANDRA FOOD, CV',
            'name_key': 'CANDRA FOOD CV',
            'value': 300000,
          },
        ],
        'by_day': [
          {'date': '2026-09-01', 'revenue': 50000, 'qty': 2},
          {'date': '2026-11-30', 'revenue': 50000, 'qty': 2},
        ],
      }, DateTime(2026, 11));

      expect(analytics.rangeMonths, 3);
      expect(analytics.days.length, 91);
      expect(analytics.days.first.date, DateTime(2026, 9));
      expect(analytics.days.last.date, DateTime(2026, 11, 30));
      expect(analytics.totalMargin, -5000);
      expect(analytics.totalReturRevenue, 15000);
      expect(analytics.totalReturMargin, -500);
      expect(analytics.returRows, 2);
      expect(analytics.marginPercent, -0.05);
      expect(analytics.products.single.motherSku, 'M001');
      expect(analytics.topDivisi?.displayLabel, 'Bangunan');
      expect(analytics.suppliers.single.displayLabel, 'Supplier Utama');
      expect(analytics.supplierRetur.single.revenue, 15000);
      expect(analytics.supplierRetur.single.supplierNetRevenue, 85000);
      expect(analytics.salesTargets['YUSUF HIDAYAT'], 200000);
      expect(analytics.supplierTargets['CANDRA FOOD CV'], 300000);
    },
  );

  test('sales and supplier names normalize to the target key', () {
    final analytics = SalesAnalytics.fromSummary({
      'by_sales': [
        {'sales_kode': 'S1', 'sales_nama': 'Yusuf Hidayat'},
      ],
      'by_supplier': [
        {'supplier': 'CANDRA FOOD, CV'},
      ],
    }, DateTime(2026, 9));

    expect(analytics.sales.single.targetKey, 'YUSUF HIDAYAT');
    expect(analytics.suppliers.single.targetKey, 'CANDRA FOOD CV');
  });

  test('formatPercent preserves negative margin rates', () {
    expect(formatPercent(-0.125), '-12,5%');
  });

  test('formatPercentPrecise always displays two decimal places', () {
    expect(formatPercentPrecise(0.8), '80,00%');
    expect(formatPercentPrecise(0.9999), '99,99%');
    expect(formatPercentPrecise(1), '100,00%');
  });
}
