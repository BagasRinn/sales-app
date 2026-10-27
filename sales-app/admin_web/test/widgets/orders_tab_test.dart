import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:admin_web/core/design_system.dart';
import 'package:admin_web/data/models/order.dart';
import 'package:admin_web/data/repositories/admin_repository.dart';
import 'package:admin_web/data/repositories/api_service.dart';
import 'package:admin_web/presentation/providers/admin_provider.dart';
import 'package:admin_web/presentation/screens/orders_tab.dart';
import 'package:dio/dio.dart';
import 'package:provider/provider.dart';
import 'package:datetime_utils/datetime_utils.dart';

class _FakeRepo extends AdminRepository {
  _FakeRepo() : super(ApiService());

  static Order _order(String status) => Order(
    id: '11111111-2222-3333-4444-555555555555',
    salesId: 's1',
    status: status,
    createdAt: DateTime(2026, 10, 20, 10, 30),
    storeName: 'Toko Melati',
    salesNama: 'Andi',
    items: [
      OrderItem(
        id: 'i1',
        orderId: 'o1',
        productId: 'p1',
        namaBarang: 'Beras 5kg',
        qty: 2,
        hargaSatuan: 70000,
        hargaSetelahDiskon: 70000,
        subtotal: 140000,
      ),
    ],
  );

  @override
  Future<List<Order>> getPendingOrders({
    String? search,
    CancelToken? cancelToken,
  }) async => [_order('PENDING')];

  @override
  Future<({List<Order> orders, int total})> getAllOrdersPaginated({
    String? status,
    String? search,
    DateTime? dateFrom,
    DateTime? dateTo,
    int skip = 0,
    int limit = 20,
  }) async => (orders: [_order('PENDING'), _order('APPROVED')], total: 2);

  @override
  Future<List<Order>> getDraftOrders({CancelToken? cancelToken}) async => [
    _order('DRAFT'),
  ];
}

Widget _harness(AdminProvider p) => MaterialApp(
  theme: AppTheme.lightTheme,
  home: ChangeNotifierProvider<AdminProvider>.value(
    value: p,
    child: const Scaffold(body: OrdersTab()),
  ),
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
    initTimezone();
  });

  // Layout tab + kartu pesanan anti-overflow di 3 breakpoint.
  for (final (label, size) in <(String, Size)>[
    ('mobile 360', const Size(360, 800)),
    ('tablet 768', const Size(768, 1024)),
    ('desktop 1440', const Size(1440, 900)),
  ]) {
    testWidgets('OrdersTab $label: render tanpa overflow', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness(AdminProvider(_FakeRepo())));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Draft'));
      await tester.pumpAndSettle();

      expect(find.text('Draft'), findsWidgets);
      expect(find.text('Semua'), findsWidgets);
      // Kartu pesanan pakai AppCard (bukan Card bawaan theme lagi).
      expect(find.byType(AppCard), findsWidgets);
      expect(find.text('Toko Melati'), findsWidgets);
      expect(find.text('Draft'), findsWidgets);
      expect(find.byType(OrderStatusChip), findsWidgets);
    });
  }
}
