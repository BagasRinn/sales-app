import 'package:admin_web/data/models/sales_attendance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromJson parses backend payload', () {
    final item = SalesAttendance.fromJson({
      'id': 'a1',
      'sales_id': 's1',
      'sales_name': 'Budi Santoso',
      'sender_phone': '6281200001234',
      'sender_push_name': 'Budi WA',
      'is_registered_sales': true,
      'outlet_code': 'OUT-01',
      'outlet_name': 'Toko A',
      'outlet_channel': 'GT',
      'has_photo_proof': true,
      'wa_group_id': '120363000000000000@g.us',
      'wa_message_id': 'MSG-1',
      'visited_at': '2026-01-02T03:04:05Z',
      'created_at': '2026-01-02T03:05:00Z',
    });

    expect(item.id, 'a1');
    expect(item.salesId, 's1');
    expect(item.displayName, 'Budi Santoso');
    expect(item.displayPhone, '081200001234');
    expect(item.isRegisteredSales, isTrue);
    expect(item.outletCode, 'OUT-01');
    expect(item.outletName, 'Toko A');
    expect(item.outletChannel, 'GT');
    expect(item.hasPhotoProof, isTrue);
    expect(item.visitedAt.isUtc, isTrue);
    expect(item.createdAt, isNotNull);
  });

  test('displayName falls back to pushName, then generic label', () {
    final unregistered = SalesAttendance.fromJson({
      'id': 'a2',
      'sender_phone': '6281299998888',
      'sender_push_name': 'Pak Sup',
      'is_registered_sales': false,
      'outlet_code': 'OUT-02',
      'outlet_name': 'Toko B',
      'outlet_channel': 'MT',
      'visited_at': '2026-01-02T03:04:05Z',
    });
    expect(unregistered.displayName, 'Pak Sup');

    final anonymous = SalesAttendance.fromJson({
      'id': 'a3',
      'sender_phone': '6281200000000',
      'is_registered_sales': false,
      'outlet_code': 'OUT-03',
      'outlet_name': 'Toko C',
      'outlet_channel': 'MT',
      'visited_at': '2026-01-02T03:04:05Z',
    });
    expect(anonymous.displayName, 'Tanpa nama');
    expect(anonymous.displayPhone, '081200000000');
  });

  test('missing optional fields use safe defaults', () {
    final item = SalesAttendance.fromJson({
      'id': 'a4',
      'sender_phone': '',
      'visited_at': '2026-01-02T03:04:05Z',
    });

    expect(item.salesId, isNull);
    expect(item.salesName, isNull);
    expect(item.outletCode, '');
    expect(item.outletName, '');
    expect(item.outletChannel, '');
    expect(item.hasPhotoProof, isFalse);
    expect(item.isRegisteredSales, isFalse);
  });
}
