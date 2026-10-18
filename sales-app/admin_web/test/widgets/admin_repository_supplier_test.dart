// Minimal: only tests the JSON-parsing path; full HTTP testing deferred
// until ApiService supports test injection (no fromDio factory in the
// codebase). When ApiService is refactored to allow mock injection,
// replace this with a dio httpClientAdapter-based test.
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_web/data/models/supplier.dart';

void main() {
  test('Supplier JSON parsing produces correct model', () {
    final list = [
      {'name': 'Mulia', 'is_active': true, 'product_count': 5},
      {'name': 'Mulia2', 'is_active': false, 'product_count': 0},
    ].map(Supplier.fromJson).toList();
    expect(list.length, 2);
    expect(list[0].name, 'Mulia');
    expect(list[0].isActive, isTrue);
    expect(list[0].productCount, 5);
    expect(list[1].productCount, 0);
  });
}
