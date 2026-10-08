import 'package:flutter_test/flutter_test.dart';
import 'package:sales_web/data/models/order.dart';

void main() {
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
      'items': [
        {
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
        },
      ],
      'order_type': 'REGULER',
    };

    test('parses a complete order', () {
      final order = Order.fromJson(baseJson);
      expect(order.id, baseJson['id']);
      expect(order.customerId, baseJson['customer_id']);
      expect(order.customerName, 'IBU WAYANX');
    });

    test('parses when customer_id is null (nullable in backend schema)', () {
      // Backend schema OrderListWithItemsResponse declares customer_id as Optional
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
}
