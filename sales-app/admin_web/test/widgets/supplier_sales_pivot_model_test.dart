import 'package:flutter_test/flutter_test.dart';
import 'package:admin_web/data/models/supplier_sales_pivot.dart';

void main() {
  test('parses pivot metrics, rows, columns, and date range', () {
    final pivot = SupplierSalesPivot.fromJson({
      'from': '2026-03-01',
      'to': '2026-03-31',
      'total': {'value': 1500, 'margin': 150, 'qty': 3},
      'columns': [
        {
          'nama': 'Ayu',
          'total': {'value': 1500, 'margin': 150, 'qty': 3},
        },
      ],
      'rows': [
        {
          'supplier': 'Supplier A',
          'channel': 'Mix',
          'cells': {
            'Ayu': {'value': 1500, 'margin': 150, 'qty': 3},
          },
          'total': {'value': 1500, 'margin': 150, 'qty': 3},
        },
      ],
    });

    expect(pivot.total.value, 1500);
    expect(pivot.total.forMetric('margin'), 150);
    expect(pivot.columns.single.name, 'Ayu');
    expect(pivot.rows.single.cells['Ayu']?.qty, 3);
    expect(pivot.from, DateTime(2026, 3, 1));
    expect(pivot.to, DateTime(2026, 3, 31));
  });
}
