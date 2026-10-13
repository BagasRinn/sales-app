import 'package:flutter_test/flutter_test.dart';
import 'package:admin_web/data/models/supplier_target.dart';

void main() {
  test('SupplierTarget.fromJson parses backend response', () {
    final json = {
      'id': 'u-1',
      'branch': 'A',
      'supplier_name': 'PT X',
      'period': '2026-10',
      'target_value': 5000000,
    };
    final t = SupplierTarget.fromJson(json);
    expect(t.id, 'u-1');
    expect(t.branch, 'A');
    expect(t.supplierName, 'PT X');
    expect(t.period, '2026-10');
    expect(t.targetValue, 5000000);
  });

  test('SupplierTarget.toJson round-trips', () {
    const t = SupplierTarget(
      id: 'u-1',
      branch: 'A',
      supplierName: 'PT X',
      period: '2026-10',
      targetValue: 1000,
    );
    final round = SupplierTarget.fromJson(t.toJson());
    expect(round.id, 'u-1');
    expect(round.branch, 'A');
    expect(round.supplierName, 'PT X');
    expect(round.period, '2026-10');
    expect(round.targetValue, 1000);
  });

  test('SupplierTarget.fromJson tolerates num as int for target_value', () {
    final json = {
      'id': 'u-1',
      'branch': 'A',
      'supplier_name': 'PT X',
      'period': '2026-10',
      'target_value': 1000, // int
    };
    final t = SupplierTarget.fromJson(json);
    expect(t.targetValue, 1000);
  });
}
