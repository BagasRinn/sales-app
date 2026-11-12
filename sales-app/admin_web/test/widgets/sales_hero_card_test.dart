import 'package:admin_web/presentation/widgets/analytics/sales_analytics_models.dart';
import 'package:admin_web/presentation/widgets/analytics/sales_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'hero shows combined supplier target and moves transactions to metrics',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final analytics = SalesAnalytics.fromSummary({
        'month': '2026-11',
        'total_revenue': 250000,
        'imported_rows': 12,
        'supplier_targets': [
          {'name': 'Supplier A', 'value': 200000},
          {'name': 'Supplier B', 'value': 300000},
        ],
        'by_day': [
          {'date': '2026-11-01', 'revenue': 100000},
          {'date': '2026-11-02', 'revenue': 150000},
        ],
      }, DateTime(2026, 11));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: SalesHeroCard(analytics: analytics),
            ),
          ),
        ),
      );

      expect(find.text('Target global · Rp 500.000'), findsOneWidget);
      expect(find.text('Pencapaian target · 50,00%'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('transaksi'), findsNothing);

      final transactions = tester.getTopLeft(find.text('Transaksi'));
      final activeDays = tester.getTopLeft(find.text('Hari aktif'));
      expect(transactions.dx, lessThan(activeDays.dx));
      expect(transactions.dy, closeTo(activeDays.dy, 1));
    },
  );

  testWidgets('hero explains when no supplier target is configured', (
    tester,
  ) async {
    final analytics = SalesAnalytics.fromSummary({
      'total_revenue': 250000,
      'imported_rows': 12,
      'supplier_targets': <dynamic>[],
    }, DateTime(2026, 11));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SalesHeroCard(analytics: analytics)),
      ),
    );

    expect(find.text('Target global · Rp 0'), findsOneWidget);
    expect(find.text('Target supplier belum diatur'), findsOneWidget);
  });
}
