import 'package:admin_web/presentation/widgets/analytics/sales_analytics_models.dart';
import 'package:admin_web/presentation/widgets/analytics/sales_charts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows every sales name and only its participation percentage', (
    tester,
  ) async {
    final sales = List.generate(
      7,
      (index) => SalesRankItem(
        code: 'S$index',
        label: 'Sales $index',
        qty: 1,
        revenue: (7 - index) * 10,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 560,
            child: SalesParticipationChart(items: sales),
          ),
        ),
      ),
    );

    for (var index = 0; index < sales.length; index++) {
      expect(find.text('Sales $index'), findsOneWidget);
    }
    expect(find.text('Lainnya'), findsNothing);
    expect(find.text('25,00%'), findsOneWidget);
    expect(find.text('3,57%'), findsOneWidget);
    expect(find.textContaining('Rp '), findsNothing);
    expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
  });

  testWidgets('shows all names with zero participation when revenue is zero', (
    tester,
  ) async {
    const sales = [
      SalesRankItem(code: 'S1', label: 'Sales 1', qty: 0, revenue: 0),
      SalesRankItem(code: 'S2', label: 'Sales 2', qty: 0, revenue: 0),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SalesParticipationChart(items: sales)),
      ),
    );

    expect(find.text('Sales 1'), findsOneWidget);
    expect(find.text('Sales 2'), findsOneWidget);
    expect(find.text('0,00%'), findsNWidgets(2));
    expect(find.byType(CustomPaint), findsAtLeastNWidgets(1));
  });
}
