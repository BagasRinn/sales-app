import 'package:flutter_test/flutter_test.dart';
import 'package:admin_web/data/models/customer.dart';

void main() {
  // Payload asli GET /api/v1/customers: deleted_at selalu null karena list
  // endpoint exclude soft-deleted rows.
  test('Customer.fromJson tolerates null deleted_at', () {
    final c = Customer.fromJson({
      'id': '11111111-1111-1111-1111-111111111111',
      'kode': null,
      'nama_toko': 'UD Sumber Rejeki',
      'alamat': null,
      'kode_area': null,
      'created_at': '2026-10-20T22:45:55+08:00',
      'updated_at': '2026-10-20T22:45:55+08:00',
      'deleted_at': null,
      'branch': null,
      'branch_nama': null,
    });
    expect(c.namaToko, 'UD Sumber Rejeki');
    expect(c.deletedAt, isNull);
    expect(c.createdAt, DateTime.utc(2026, 10, 20, 14, 45, 55));
  });
}
