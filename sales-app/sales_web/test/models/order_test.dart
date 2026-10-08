import 'package:flutter_test/flutter_test.dart';
import 'package:sales_web/data/models/order.dart';

void main() {
  // Mirrors the response shape from backend /orders/my endpoint.
  // Some fields are nullable per OrderItemResponse schema.
  final baseItemJson = {
    'id': '915b35d2-b6c8-4788-8b71-e0434ab7f591',
    'product_id': 'IT01503',
    'nama_barang': 'FILMA MGRN',
    'qty': 1,
    'harga_satuan': 6000,
    'discount_type': 'PERCENT',
    'discount_percent': 2.0,
    'discount_nominal': 0,
    'discount2_type': 'PERCENT',
    'discount2_percent': 0.0,
    'discount2_nominal': 0,
    'discount3_type': 'PERCENT',
    'discount3_percent': 0.0,
    'discount3_nominal': 0,
    'harga_setelah_diskon': 5880,
    'subtotal': 5880,
  };

  group('Order.fromJson', () {
    final baseJson = {
      'id': 'bab54675-85f6-485e-a8c3-6d6bd2ec715a',
      'sales_id': '247c0748-2a91-47cf-9d48-25d014cacf76',
      'customer_id': '4c110451-fdf3-46ca-9323-6a3e87a67b2b',
      'customer_name': 'IBU WAYANX',
      'status': 'PENDING',
      'notes': null,
      'created_at': '2026-10-08T01:36:09.184466Z',
      'store_name': 'Testing9',
      'store_contact': null,
      'store_address': 'JL PASAR',
      'items': [baseItemJson],
      'order_type': 'REGULER',
    };

    test('parses a complete order', () {
      final order = Order.fromJson(baseJson);
      expect(order.id, baseJson['id']);
      expect(order.customerId, baseJson['customer_id']);
      expect(order.customerName, 'IBU WAYANX');
    });

    test('parses when customer_id is null (nullable in backend schema)', () {
      final json = Map<String, dynamic>.from(baseJson)..['customer_id'] = null;
      final order = Order.fromJson(json);
      expect(order.customerId, isNotNull);
    });

    test('parses when customer_name is null (nullable in backend schema)', () {
      final json = Map<String, dynamic>.from(baseJson)..['customer_name'] = null;
      final order = Order.fromJson(json);
      expect(order.customerName, isNotNull);
    });

    test('parses when both customer_id and customer_name are null', () {
      final json = Map<String, dynamic>.from(baseJson)
        ..['customer_id'] = null
        ..['customer_name'] = null;
      final order = Order.fromJson(json);
      expect(order.customerId, isNotNull);
      expect(order.customerName, isNotNull);
    });
  });

  // The mobile app's OrderItem.fromJson (lib/data/models/order.dart) is fully
  // defensive — every numeric field has a default, every string is nullable.
  // sales_web must match so the recent-orders list doesn't fail silently on
  // any item with missing or null fields.
  group('OrderItem.fromJson (mobile-app parity)', () {
    test('parses a complete item', () {
      final item = OrderItem.fromJson(baseItemJson);
      expect(item.namaBarang, 'FILMA MGRN');
      expect(item.hargaSatuan, 6000);
      expect(item.qty, 1);
      expect(item.hargaSetelahDiskon, 5880);
      expect(item.subtotal, 5880);
    });

    test('parses when nama_barang is null', () {
      final json = Map<String, dynamic>.from(baseItemJson)
        ..['nama_barang'] = null;
      final item = OrderItem.fromJson(json);
      expect(item.namaBarang, isNull);
    });

    test('parses when harga_satuan is null', () {
      final json = Map<String, dynamic>.from(baseItemJson)
        ..['harga_satuan'] = null;
      final item = OrderItem.fromJson(json);
      expect(item.hargaSatuan, 0);
    });

    test('parses when qty is null (defaults to 1 like mobile)', () {
      final json = Map<String, dynamic>.from(baseItemJson)..['qty'] = null;
      final item = OrderItem.fromJson(json);
      expect(item.qty, 1);
    });

    test('parses when harga_setelah_diskon is null', () {
      final json = Map<String, dynamic>.from(baseItemJson)
        ..['harga_setelah_diskon'] = null;
      final item = OrderItem.fromJson(json);
      // Falls back to harga_satuan (mobile behaviour).
      expect(item.hargaSetelahDiskon, 6000);
    });

    test('parses when subtotal is null', () {
      final json = Map<String, dynamic>.from(baseItemJson)
        ..['subtotal'] = null;
      final item = OrderItem.fromJson(json);
      // Falls back to harga_setelah_diskon * qty (mobile behaviour).
      expect(item.subtotal, 5880);
    });

    test('parses when several item fields are null simultaneously', () {
      final json = Map<String, dynamic>.from(baseItemJson)
        ..['nama_barang'] = null
        ..['harga_satuan'] = null
        ..['qty'] = null
        ..['harga_setelah_diskon'] = null
        ..['subtotal'] = null;
      final item = OrderItem.fromJson(json);
      expect(item.namaBarang, isNull);
      expect(item.hargaSatuan, 0);
      expect(item.qty, 1);
      // harga_setelah_diskon falls back to harga_satuan (0) → 0
      expect(item.hargaSetelahDiskon, 0);
      // subtotal falls back to harga_setelah_diskon * qty (0 * 1) → 0
      expect(item.subtotal, 0);
    });
  });

  // Regression: home_stats_provider calls loadRecentOrders which builds the
  // list via list.map(Order.fromJson). If one item throws, the whole list
  // fails and the user sees "Belum ada order" instead of the actual orders.
  group('Order.fromJson with sparse items (regression for "Belum ada order")', () {
    test('parses an order whose single item has null fields', () {
      final orderJson = {
        'id': 'order-1',
        'sales_id': 'sales-1',
        'customer_id': 'cust-1',
        'customer_name': 'Toko A',
        'status': 'PENDING',
        'notes': null,
        'created_at': '2026-10-08T01:36:09.184466Z',
        'store_name': 'Toko A',
        'store_contact': null,
        'store_address': null,
        'order_type': 'REGULER',
        'items': [
          {
            'id': 'item-1',
            'product_id': 'P-1',
            'nama_barang': null, // missing product name
            'qty': 1,
            'harga_satuan': null, // missing price
            'discount_type': 'PERCENT',
            'discount_percent': 0.0,
            'discount_nominal': 0,
            'discount2_type': 'PERCENT',
            'discount2_percent': 0.0,
            'discount2_nominal': 0,
            'discount3_type': 'PERCENT',
            'discount3_percent': 0.0,
            'discount3_nominal': 0,
            'harga_setelah_diskon': null,
            'subtotal': null,
          },
        ],
      };
      // Must not throw — the whole list parsing depends on every item succeeding.
      final order = Order.fromJson(orderJson);
      expect(order.items, hasLength(1));
      expect(order.items.first.namaBarang, isNull);
      expect(order.items.first.subtotal, 0);
    });
  });

  // Regression: the backend sends FLAT discount fields (discount_type, discount_percent,
  // discount2_percent, ...) — NOT a nested `discount: {layer1: {...}}` object.
  // OrderItem.fromJson must read the flat fields directly.
  group('OrderItem.fromJson discount layers (backend flat-field regression)', () {
    test('hasDiscount is true when layer1 is PERCENT > 0', () {
      final json = Map<String, dynamic>.from(baseItemJson);
      final item = OrderItem.fromJson(json);
      expect(item.hasDiscount, isTrue);
      expect(item.discount.layer1, isNotNull);
      expect(item.discount.layer1!.type, DiscountType.percent);
      expect(item.discount.layer1!.value, 2);
    });

    test('hasDiscount is true when layer1 is NOMINAL > 0', () {
      final json = Map<String, dynamic>.from(baseItemJson)
        ..['discount_type'] = 'NOMINAL'
        ..['discount_percent'] = 0
        ..['discount_nominal'] = 500;
      final item = OrderItem.fromJson(json);
      expect(item.hasDiscount, isTrue);
      expect(item.discount.layer1!.type, DiscountType.nominal);
      expect(item.discount.layer1!.value, 500);
    });

    test('hasDiscount is false when all layers are zero/empty', () {
      final json = Map<String, dynamic>.from(baseItemJson)
        ..['discount_type'] = 'PERCENT'
        ..['discount_percent'] = 0.0
        ..['discount_nominal'] = 0
        ..['discount2_type'] = 'PERCENT'
        ..['discount2_percent'] = 0.0
        ..['discount2_nominal'] = 0
        ..['discount3_type'] = 'PERCENT'
        ..['discount3_percent'] = 0.0
        ..['discount3_nominal'] = 0;
      final item = OrderItem.fromJson(json);
      expect(item.hasDiscount, isFalse);
    });

    test('reads all three discount layers', () {
      final json = {
        'id': 'i1',
        'product_id': 'p1',
        'qty': 2,
        'harga_satuan': 10000,
        'discount_type': 'PERCENT',
        'discount_percent': 5.0,
        'discount_nominal': 0,
        'discount2_type': 'NOMINAL',
        'discount2_percent': 0,
        'discount2_nominal': 200,
        'discount3_type': 'PERCENT',
        'discount3_percent': 0.0,
        'discount3_nominal': 0,
        'harga_setelah_diskon': 9500,
        'subtotal': 19000,
      };
      final item = OrderItem.fromJson(json);
      expect(item.discount.layer1!.type, DiscountType.percent);
      expect(item.discount.layer1!.value, 5);
      expect(item.discount.layer2!.type, DiscountType.nominal);
      expect(item.discount.layer2!.value, 200);
      expect(item.discount.layer3, isNull);
      expect(item.hasDiscount, isTrue);
    });
  });
}
