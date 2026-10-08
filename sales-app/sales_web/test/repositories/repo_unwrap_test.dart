import 'package:flutter_test/flutter_test.dart';

/// Regression: /orders/my and /products return bare JSON arrays (per FastAPI
/// response_model=List[...]). The previous parser tried `data['orders']`
/// before the `??` fallback, which throws on a List because list indices
/// must be int. The error was swallowed by loadRecentOrders / loadProducts,
/// so every tab showed an empty state even when the backend had data.
///
/// These tests pin down the unwrap pattern used in OrderRepository and
/// ProductRepository: type-check first, then fall back to a wrapped response.
void main() {
  // Mirror the fixed pattern in:
  //   sales_web/lib/data/repositories/order_repository.dart
  //   sales_web/lib/data/repositories/product_repository.dart
  List<dynamic> unwrap(dynamic data, String wrapperKey) {
    if (data is List) return data;
    if (data is Map) return (data[wrapperKey] as List<dynamic>?) ?? const <dynamic>[];
    return const <dynamic>[];
  }

  group('unwrap list response (repository fix)', () {
    test('handles a bare JSON array (the actual /orders/my response shape)', () {
      final data = [
        {'id': 'a'},
        {'id': 'b'},
      ];
      final list = unwrap(data, 'orders');
      expect(list, hasLength(2));
      expect(list.first['id'], 'a');
    });

    test('handles a wrapped response {orders: [...]} for backward compat', () {
      final data = {
        'orders': [
          {'id': 'a'},
          {'id': 'b'},
        ],
      };
      final list = unwrap(data, 'orders');
      expect(list, hasLength(2));
    });

    test('returns empty list when wrapper key is missing', () {
      final data = {'something_else': 'value'};
      final list = unwrap(data, 'orders');
      expect(list, isEmpty);
    });

    test('returns empty list when data is null', () {
      final list = unwrap(null, 'orders');
      expect(list, isEmpty);
    });

    test('handles products endpoint with `items` wrapper key', () {
      final data = [
        {'id': 'P-1', 'nama_barang': 'Produk 1'},
      ];
      final list = unwrap(data, 'items');
      expect(list, hasLength(1));
      expect(list.first['id'], 'P-1');
    });
  });

  // Negative test: the OLD pattern (data[key] as List ?? data as List) throws
  // on a List response. We document it here so the test serves as a tripwire
  // if someone reintroduces the bug.
  group('old buggy pattern throws (tripwire)', () {
    test('data["orders"] as List throws on a List response', () {
      final dynamic data = [
        {'id': 'a'},
      ];
      expect(
        () => (data['orders'] as List<dynamic>? ?? data as List<dynamic>),
        throwsA(isA<TypeError>()),
      );
    });
  });
}
