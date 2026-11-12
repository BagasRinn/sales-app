import 'package:admin_web/data/repositories/admin_repository.dart';
import 'package:admin_web/data/repositories/api_service.dart';
import 'package:admin_web/core/design_system/app_colors.dart';
import 'package:admin_web/core/design_system/widgets/app_card.dart';
import 'package:admin_web/core/design_system/widgets/app_stat_card.dart';
import 'package:admin_web/data/models/branch_report.dart';
import 'package:admin_web/presentation/providers/admin_provider.dart';
import 'package:admin_web/presentation/screens/imported_sales_tab.dart';
import 'package:admin_web/presentation/widgets/analytics/sales_analytics_models.dart';
import 'package:admin_web/presentation/widgets/analytics/sales_charts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FakeSalesRepository extends AdminRepository {
  _FakeSalesRepository({
    this.divisions = const [],
    this.suppliers = const [],
    this.supplierReturns = const [],
    this.totalRevenue = 0,
  }) : super(ApiService());

  final List<Map<String, dynamic>> divisions;
  final List<Map<String, dynamic>> suppliers;
  final List<Map<String, dynamic>> supplierReturns;
  final int totalRevenue;

  @override
  Future<Map<String, dynamic>> getImportedSalesVersion({
    required String month,
    int rangeMonths = 1,
    String? branch,
  }) async => {
    'month': month,
    'range_months': rangeMonths,
    'scope': branch ?? 'BANJARMASIN',
    'version': 1,
    'target_updated_at': null,
  };

  @override
  Future<Map<String, dynamic>> getImportedSalesSummary({
    String? month,
    int rangeMonths = 1,
    int limit = 10,
    String? include,
    String? branch,
  }) async => {
    'month': month,
    'range_months': rangeMonths,
    'scope': branch ?? 'BANJARMASIN',
    'version': 1,
    'total_revenue': totalRevenue,
    'total_qty': 0,
    'total_margin': 0,
    'imported_rows': 0,
    'by_product': <dynamic>[],
    'by_sales': <dynamic>[],
    'by_customer': <dynamic>[],
    'by_channel': <dynamic>[],
    'by_divisi': divisions,
    'by_supplier': suppliers,
    'by_supplier_retur': supplierReturns,
    'sales_targets': <dynamic>[],
    'supplier_targets': <dynamic>[],
    'by_day': <dynamic>[],
  };
}

class _BranchAnalyticsRepository extends _FakeSalesRepository {
  _BranchAnalyticsRepository() : super();

  @override
  Future<List<BranchOption>> getBranches() async => const [
    BranchOption(code: 'A', nama: 'Cabang A'),
    BranchOption(code: 'B', nama: 'Cabang B'),
  ];

  @override
  Future<Map<String, dynamic>> getImportedSalesVersion({
    required String month,
    int rangeMonths = 1,
    String? branch,
  }) async => {
    'month': month,
    'range_months': rangeMonths,
    'scope': branch ?? 'GLOBAL',
    'version': 1,
    'target_updated_at': null,
  };

  @override
  Future<Map<String, dynamic>> getImportedSalesSummary({
    String? month,
    int rangeMonths = 1,
    int limit = 10,
    String? include,
    String? branch,
  }) async {
    final isBranchA = branch == 'A';
    final revenue = branch == null ? 300 : (isBranchA ? 100 : 200);
    return {
      'month': month,
      'range_months': rangeMonths,
      'scope': branch ?? 'GLOBAL',
      'version': 1,
      'total_revenue': revenue,
      'total_qty': 1,
      'total_margin': 0,
      'imported_rows': 1,
      'by_product': <dynamic>[],
      'by_sales': <dynamic>[],
      'by_customer': <dynamic>[],
      'by_channel': <dynamic>[],
      'by_divisi': <dynamic>[],
      'by_supplier': <dynamic>[],
      'by_supplier_retur': <dynamic>[],
      'by_day': [
        {'date': '${month ?? '2026-11'}-01', 'revenue': revenue, 'qty': 1},
      ],
    };
  }
}

void main() {
  const salesEntry = SalesRankingEntry(
    label: 'Yusuf Hidayat',
    value: 1160000,
    trailingDetail: '100,00% omzet',
    showTarget: true,
    target: 2000000,
    targetActual: 1160000,
  );

  testWidgets('ranking row renders the target percentage and missing state', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SalesRankingList(entries: [salesEntry])),
      ),
    );

    expect(find.text('Rp 1.160.000'), findsOneWidget);
    expect(find.text('58,00%'), findsOneWidget);
    expect(
      find.textContaining('dari target · Rp 1.160.000 / Rp 2.000.000'),
      findsOneWidget,
    );
    expect(find.text('100,00% omzet'), findsOneWidget);
    expect(find.byType(FractionallySizedBox), findsNWidgets(2));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SalesRankingList(
            entries: [
              SalesRankingEntry(
                label: 'Yusuf Hidayat',
                value: 1160000,
                showTarget: true,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Target belum di-set'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SalesRankingList(
            entries: [
              SalesRankingEntry(
                label: 'Yusuf Hidayat',
                value: 1160000,
                showTarget: true,
                target: 0,
                targetActual: 1160000,
              ),
            ],
          ),
        ),
      ),
    );

    expect(
      find.text('Target Rp 0 · progres tidak dapat dihitung'),
      findsOneWidget,
    );
  });

  testWidgets(
    'target remains based on revenue in margin mode and uses two bars',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SalesRankingList(
              entries: [
                SalesRankingEntry(
                  label: 'Yusuf Hidayat',
                  value: 250000,
                  showTarget: true,
                  target: 1000000,
                  targetActual: 1160000,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('116,00%'), findsOneWidget);
      expect(find.bySemanticsLabel('Progress target omzet'), findsOneWidget);
      expect(find.byType(FractionallySizedBox), findsNWidgets(2));
    },
  );

  testWidgets('ranking and target bars use the requested colors', (
    tester,
  ) async {
    const targetItem = SalesRankingEntry(
      label: 'Target Test',
      value: 9999,
      showTarget: true,
      target: 9999,
      targetActual: 9999,
    );
    const items = [
      SalesRankingEntry(label: 'Sales 1', value: 160),
      SalesRankingEntry(label: 'Sales 2', value: 80),
      SalesRankingEntry(label: 'Sales 3', value: 60),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SalesRankingList(entries: items)),
      ),
    );

    final rankingBars = tester.widgetList<ColoredBox>(
      find.descendant(
        of: find.byType(SalesRankingList),
        matching: find.byType(ColoredBox),
      ),
    );
    expect(
      rankingBars.where((bar) => bar.color == AppColors.primary),
      hasLength(3),
    );

    Future<Color> targetBarColor(int target) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SalesRankingList(
              entries: [
                SalesRankingEntry(
                  label: targetItem.label,
                  value: targetItem.value,
                  showTarget: true,
                  target: target,
                  targetActual: targetItem.value,
                ),
              ],
            ),
          ),
        ),
      );

      final targetBar = find.descendant(
        of: find.byType(FractionallySizedBox).at(1),
        matching: find.byType(ColoredBox),
      );
      return tester.widget<ColoredBox>(targetBar).color;
    }

    expect(await targetBarColor(12500), AppColors.danger);
    expect(await targetBarColor(12498), AppColors.warning);
    expect(await targetBarColor(10000), AppColors.warning);
    expect(await targetBarColor(9999), AppColors.success);
  });

  testWidgets('ranking row renders supplier-return detail in shared style', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SalesRankingList(
            entries: [
              SalesRankingEntry(
                label: 'Supplier Test',
                value: 6200000,
                detail: '7 baris retur · 0,33% dari omzet supplier',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('1'), findsOneWidget);
    expect(find.text('Supplier Test'), findsOneWidget);
    expect(find.text('Rp 6.200.000'), findsOneWidget);
    expect(
      find.text('7 baris retur · 0,33% dari omzet supplier'),
      findsOneWidget,
    );
    expect(find.byType(FractionallySizedBox), findsOneWidget);
  });

  testWidgets('margin display keeps ranking sorted by revenue', (tester) async {
    const entries = [
      SalesRankingEntry(label: 'Revenue Leader', value: 100, sortValue: 1000),
      SalesRankingEntry(label: 'Margin Leader', value: 500, sortValue: 900),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SalesRankingList(entries: entries)),
      ),
    );

    expect(
      tester.getTopLeft(find.text('Revenue Leader')).dy,
      lessThan(tester.getTopLeft(find.text('Margin Leader')).dy),
    );
    expect(find.text('Rp 100'), findsOneWidget);
    expect(find.text('Rp 500'), findsOneWidget);
  });

  testWidgets('target import action is hidden from supervisor', (tester) async {
    final provider = AdminProvider(_FakeSalesRepository())
      ..setUserRole('SUPERVISOR')
      ..setUserBranch('BANJARMASIN');

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: ImportedSalesTab()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Import Target'), findsNothing);
  });

  testWidgets('shows division stats instead of duplicate summary metrics', (
    tester,
  ) async {
    final provider = AdminProvider(
      _FakeSalesRepository(
        totalRevenue: 1200000,
        divisions: [
          {'divisi': 'Retail', 'revenue': 1200000, 'margin': 240000},
        ],
      ),
    )..setUserBranch('BANJARMASIN');

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: ImportedSalesTab()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Retail'), findsWidgets);
    expect(find.text('Rp 1.200.000'), findsWidgets);
    expect(
      find.text(
        'Margin Rp 240.000 · 20,00% margin\n'
        '100,00% kontribusi omzet',
      ),
      findsOneWidget,
    );
    expect(find.byType(AppStatCard), findsOneWidget);
  });

  testWidgets('supplier return ranking follows supplier sales order', (
    tester,
  ) async {
    final provider = AdminProvider(
      _FakeSalesRepository(
        totalRevenue: 6000,
        suppliers: [
          {'supplier': 'Supplier B', 'revenue': 3000},
          {'supplier': 'Supplier A', 'revenue': 2000},
          {'supplier': 'Supplier C', 'revenue': 1000},
        ],
        supplierReturns: [
          {
            'supplier': 'Supplier A',
            'revenue': 100,
            'row_count': 1,
            'supplier_net_revenue': 1900,
          },
          {
            'supplier': 'Supplier Lain',
            'revenue': 1000,
            'row_count': 2,
            'supplier_net_revenue': 4000,
          },
          {
            'supplier': 'Supplier B',
            'revenue': 50,
            'row_count': 1,
            'supplier_net_revenue': 2950,
          },
        ],
      ),
    )..setUserBranch('BANJARMASIN');

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: ImportedSalesTab()),
      ),
    );
    await tester.pumpAndSettle();

    final supplierCard = find.ancestor(
      of: find.text('Supplier Teratas'),
      matching: find.byType(AppCard),
    );
    final returnCard = find.ancestor(
      of: find.text('Supplier Diretur'),
      matching: find.byType(AppCard),
    );
    final supplierBInSales = find.descendant(
      of: supplierCard,
      matching: find.text('Supplier B'),
    );
    final supplierAInSales = find.descendant(
      of: supplierCard,
      matching: find.text('Supplier A'),
    );
    final supplierBInReturns = find.descendant(
      of: returnCard,
      matching: find.text('Supplier B'),
    );
    final supplierAInReturns = find.descendant(
      of: returnCard,
      matching: find.text('Supplier A'),
    );
    final otherSupplierInReturns = find.descendant(
      of: returnCard,
      matching: find.text('Supplier Lain'),
    );

    expect(supplierBInReturns, findsOneWidget);
    expect(supplierAInReturns, findsOneWidget);
    expect(otherSupplierInReturns, findsOneWidget);
    expect(
      tester.getTopLeft(supplierBInSales).dy,
      lessThan(tester.getTopLeft(supplierAInSales).dy),
    );
    expect(
      tester.getTopLeft(supplierBInReturns).dy,
      lessThan(tester.getTopLeft(supplierAInReturns).dy),
    );
    expect(
      tester.getTopLeft(supplierAInReturns).dy,
      lessThan(tester.getTopLeft(otherSupplierInReturns).dy),
    );
  });

  testWidgets(
    'supplier return list follows the shared top 10 and top 50 filter',
    (tester) async {
      final suppliers = List.generate(
        12,
        (index) => {
          'supplier': 'Supplier ${index + 1}',
          'revenue': 12000 - index * 1000,
        },
      );
      final returns = List.generate(
        12,
        (index) => {
          'supplier': 'Supplier ${index + 1}',
          'revenue': 12000 - index * 1000,
          'row_count': 1,
          'supplier_net_revenue': 100000,
        },
      );
      final provider = AdminProvider(
        _FakeSalesRepository(suppliers: suppliers, supplierReturns: returns),
      )..setUserBranch('BANJARMASIN');

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(home: ImportedSalesTab()),
        ),
      );
      await tester.pumpAndSettle();

      Finder returnRows() {
        final returnCard = find.ancestor(
          of: find.text('Supplier Diretur'),
          matching: find.byType(AppCard),
        );
        return find.descendant(
          of: returnCard,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Text &&
                (widget.data?.contains('baris retur ·') ?? false),
          ),
        );
      }

      expect(returnRows(), findsNWidgets(10));

      await tester.tap(find.text('Top 50'));
      await tester.pumpAndSettle();

      expect(returnRows(), findsNWidgets(12));
    },
  );

  testWidgets(
    'all-branches manager sees branch trend and participation charts',
    (tester) async {
      tester.view.physicalSize = const Size(2000, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final provider = AdminProvider(_BranchAnalyticsRepository())
        ..setUserRole('MANAGER');

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(home: ImportedSalesTab()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tren Omzet Harian per Cabang'), findsOneWidget);
      expect(find.text('Partisipasi Cabang'), findsOneWidget);
      expect(find.text('Partisipasi Sales'), findsNothing);

      final branchPieCard = find.ancestor(
        of: find.text('Partisipasi Cabang'),
        matching: find.byType(AppCard),
      );
      expect(
        find.descendant(of: branchPieCard, matching: find.text('Cabang A')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: branchPieCard, matching: find.text('Cabang B')),
        findsOneWidget,
      );

      final trendCard = find.ancestor(
        of: find.text('Tren Omzet Harian per Cabang'),
        matching: find.byType(AppCard),
      );
      final totalTrend = find.descendant(
        of: trendCard,
        matching: find.byType(SalesTrendChart),
      );
      expect(
        tester.widget<SalesTrendChart>(totalTrend).points.first.revenue,
        300,
      );

      await tester.tap(find.text('Per Cabang'));
      await tester.pumpAndSettle();
      expect(find.byType(SalesSmallMultiplesChart), findsOneWidget);

      await tester.tap(find.text('Garis gabungan'));
      await tester.pumpAndSettle();
      expect(find.byType(SalesMultiTrendChart), findsOneWidget);
      expect(find.text('Tampilkan panel'), findsOneWidget);

      await tester.tap(find.text('Tampilkan panel'));
      await tester.pumpAndSettle();
      expect(find.byType(SalesSmallMultiplesChart), findsOneWidget);

      await tester.tap(find.text('Total'));
      await tester.pumpAndSettle();
      expect(find.byType(SalesTrendChart), findsOneWidget);
    },
  );
}
