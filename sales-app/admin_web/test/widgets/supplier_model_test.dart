import 'package:flutter_test/flutter_test.dart';
import 'package:admin_web/data/models/supplier.dart';

void main() {
  test('Supplier.fromJson parses all fields', () {
    final s = Supplier.fromJson({
      'name': 'Mulia',
      'is_active': true,
      'product_count': 12,
      'created_at': '2026-10-15T00:00:00+08:00',
      'updated_at': '2026-10-15T00:00:00+08:00',
    });
    expect(s.name, 'Mulia');
    expect(s.isActive, isTrue);
    expect(s.productCount, 12);
    expect(s.createdAt, isNotNull);
    expect(s.updatedAt, isNotNull);
  });

  test('Supplier.fromJson handles missing product_count defaulting to 0', () {
    final s = Supplier.fromJson({
      'name': 'X',
      'is_active': false,
    });
    expect(s.productCount, 0);
    expect(s.isActive, isFalse);
  });
}
