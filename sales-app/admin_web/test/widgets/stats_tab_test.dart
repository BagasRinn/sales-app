import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:admin_web/core/design_system.dart';
import 'package:admin_web/data/models/sales_performance.dart';
import 'package:admin_web/data/repositories/api_service.dart';
import 'package:admin_web/data/repositories/admin_repository.dart';
import 'package:admin_web/presentation/providers/admin_provider.dart';
import 'package:admin_web/presentation/screens/stats_tab.dart';
import 'package:provider/provider.dart';

class _FakeRepo extends AdminRepository {
  /// Repo kosong: StatsTab(role: ADMIN) tidak menyentuh network di test.
  /// MANAGER butuh data performa — di-override di bawah.
  _FakeRepo() : super(ApiService());

  @override
  Future<List<SalesPerformanceDashboardItem>> getSalesPerformanceDashboard() async =>
      [
        const SalesPerformanceDashboardItem(
          userId: 'u1',
          username: 'andi',
          nama: 'Andi',
          branch: 'BTL',
          approvedMtdCount: 12,
          approvedMtdRevenue: 1500000,
          pendingMtdCount: 3,
          pendingMtdRevenue: 400000,
          rejectedMtdCount: 1,
          rejectedMtdRevenue: 90000,
        ),
        const SalesPerformanceDashboardItem(
          userId: 'u2',
          username: 'budi',
          nama: 'Budi',
          branch: 'BJM',
          approvedMtdCount: 20,
          approvedMtdRevenue: 3500000,
        ),
      ];
}

Widget _harness(AdminProvider p, {String role = 'ADMIN'}) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: ChangeNotifierProvider<AdminProvider>.value(
        value: p,
        child: Scaffold(body: StatsTab(role: role)),
      ),
    );

void main() {
  setUpAll(() => initializeDateFormatting('id_ID'));

  // Layout grid kartu statistik + anti-overflow 3 breakpoint.
  for (final (label, size) in <(String, Size)>[
    ('mobile 360', const Size(360, 800)),
    ('tablet 768', const Size(768, 1024)),
    ('desktop 1440', const Size(1440, 900)),
  ]) {
    testWidgets('StatsTab $label: render tanpa overflow', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness(AdminProvider(_FakeRepo())));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Ringkasan Sistem'), findsOneWidget);
      expect(find.text('Pesanan Hari Ini'), findsOneWidget);
      expect(find.text('Data Master'), findsOneWidget);
      // 5 kartu order hari ini + 3 kartu data master.
      expect(find.byType(AppStatCard), findsNWidgets(8));
    });

    testWidgets('StatsTab MANAGER $label: kartu performa tanpa overflow',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final p = AdminProvider(_FakeRepo());
      await tester.pumpWidget(_harness(p, role: 'MANAGER'));
      await p.loadSalesPerformanceDashboard();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Total semua cabang + per cabang + per sales.
      expect(find.text('Total Semua Sales'), findsOneWidget);
      expect(find.text('Cabang BTL'), findsOneWidget);
      expect(find.text('Andi'), findsOneWidget);
      // Blok status (Disetujui/Menunggu/Ditolak) ada di tiap kartu performa.
      expect(find.text('Disetujui'), findsWidgets);
      expect(find.text('Ditolak'), findsWidgets);
    });
  }
}
