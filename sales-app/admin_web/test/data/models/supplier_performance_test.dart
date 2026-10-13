import 'package:flutter_test/flutter_test.dart';
import 'package:admin_web/data/models/supplier_performance.dart';

void main() {
  test('fromJson with has_target=true parses pencapaian', () {
    final r = SupplierPerformanceRow.fromJson({
      'supplier_name': 'PT X',
      'target': 5000,
      'has_target': true,
      'value': 2500,
      'pencapaian': 50.0,
    });
    expect(r.supplierName, 'PT X');
    expect(r.target, 5000);
    expect(r.hasTarget, true);
    expect(r.value, 2500);
    expect(r.pencapaian, 50.0);
  });

  test('fromJson with has_target=false keeps pencapaian null', () {
    final r = SupplierPerformanceRow.fromJson({
      'supplier_name': 'PT Y',
      'target': 0,
      'has_target': false,
      'value': 1000,
      'pencapaian': null,
    });
    expect(r.hasTarget, false);
    expect(r.pencapaian, null);
  });

  test('fromJson accepts int 100 as 100.0 pencapaian', () {
    final r = SupplierPerformanceRow.fromJson({
      'supplier_name': 'PT Z',
      'target': 1000,
      'has_target': true,
      'value': 1000,
      'pencapaian': 100, // int, not double
    });
    expect(r.pencapaian, 100.0);
  });
}
