import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_web/core/design_system.dart';
import 'package:admin_web/data/models/supplier.dart';
import 'package:admin_web/data/repositories/api_service.dart';
import 'package:admin_web/data/repositories/admin_repository.dart';
import 'package:admin_web/presentation/providers/admin_provider.dart';
import 'package:admin_web/presentation/screens/suppliers_tab.dart';
import 'package:provider/provider.dart';

class _FakeRepo extends AdminRepository {
  _FakeRepo() : super(ApiService());
  List<Supplier> data = [];
  @override
  Future<({List<Supplier> suppliers, int total})> getSuppliers({
    bool? active,
    String? search,
    int skip = 0,
    int limit = 20,
  }) async {
    var filtered = data;
    if (active != null) {
      filtered = filtered.where((s) => s.isActive == active).toList();
    }
    if (search != null && search.trim().isNotEmpty) {
      filtered = filtered
          .where((s) => s.name.toLowerCase().contains(search.toLowerCase()))
          .toList();
    }
    final total = filtered.length;
    return (suppliers: filtered.skip(skip).take(limit).toList(), total: total);
  }

  @override
  Future<Supplier> createSupplier(
    String name, {
    String orderType = 'REGULER',
  }) async {
    final s = Supplier(name: name, isActive: true, orderType: orderType);
    data.add(s);
    return s;
  }

  @override
  Future<Supplier> updateSupplierActive(String name, bool isActive) async {
    final i = data.indexWhere((s) => s.name == name);
    data[i] = Supplier(
      name: name,
      isActive: isActive,
      productCount: data[i].productCount,
    );
    return data[i];
  }
}

Widget _harness(AdminProvider p) => MaterialApp(
  home: ChangeNotifierProvider<AdminProvider>.value(
    value: p,
    child: const Scaffold(body: SuppliersTab()),
  ),
);

void _setDesktop(WidgetTester tester) {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void _setMobile(WidgetTester tester, {double w = 360, double h = 800}) {
  tester.view.physicalSize = Size(w, h);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void _setTablet(WidgetTester tester) => _setMobile(tester, w: 768, h: 1024);

void main() {
  testWidgets('empty state shows when no suppliers loaded', (tester) async {
    final p = AdminProvider(_FakeRepo());
    await tester.pumpWidget(_harness(p));
    await tester.pumpAndSettle();
    expect(find.textContaining('Belum ada supplier'), findsOneWidget);
  });

  testWidgets('empty state shows different message when search has no result', (
    tester,
  ) async {
    final repo = _FakeRepo();
    final p = AdminProvider(repo);
    await tester.pumpWidget(_harness(p));
    await tester.pumpAndSettle();
    // Type a query that matches nothing.
    await tester.enterText(find.byType(TextField).first, 'zzzzz');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Tidak ada supplier yang cocok'),
      findsOneWidget,
    );
    expect(find.textContaining('Belum ada supplier'), findsNothing);
  });

  testWidgets('search bar has hint "Cari supplier..."', (tester) async {
    final p = AdminProvider(_FakeRepo());
    await tester.pumpWidget(_harness(p));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Cari supplier...'), findsOneWidget);
  });

  testWidgets('counter pill shows total count', (tester) async {
    final repo = _FakeRepo();
    repo.data = List.generate(
      122,
      (i) => Supplier(name: 'S$i', isActive: true, productCount: 0),
    );
    final p = AdminProvider(repo);
    await tester.pumpWidget(_harness(p));
    await tester.pumpAndSettle();
    expect(find.text('122 supplier'), findsOneWidget);
  });

  testWidgets('clear button appears when search has text', (tester) async {
    final p = AdminProvider(_FakeRepo());
    await tester.pumpWidget(_harness(p));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.clear), findsNothing);
    await tester.enterText(find.byType(TextField).first, 'mulia');
    await tester.pumpAndSettle();
    // AppSearchField uses IconButton with Icon(Icons.clear) inside suffixIcon.
    // The clear icon becomes visible when text is non-empty.
    expect(find.byIcon(Icons.clear), findsOneWidget);
  });

  testWidgets('filter chips (Semua / Aktif / Non-Aktif) are present', (
    tester,
  ) async {
    final p = AdminProvider(_FakeRepo());
    await tester.pumpWidget(_harness(p));
    await tester.pumpAndSettle();
    expect(find.text('Semua'), findsOneWidget);
    expect(find.text('Aktif'), findsOneWidget);
    expect(find.text('Non-Aktif'), findsOneWidget);
  });

  testWidgets('renders supplier rows when loaded', (tester) async {
    final repo = _FakeRepo();
    repo.data = const [
      Supplier(name: 'Mulia', isActive: true, productCount: 3),
      Supplier(name: 'Mulia2', isActive: false, productCount: 0),
    ];
    final p = AdminProvider(repo);
    await tester.pumpWidget(_harness(p));
    await tester.pumpAndSettle();
    expect(find.text('Mulia'), findsOneWidget);
    expect(find.text('Mulia2'), findsOneWidget);
    // "Aktif" appears in both the filter chip and the status badge for Mulia.
    expect(find.text('Aktif'), findsNWidgets(2));
    expect(find.text('Non-Aktif'), findsNWidgets(2));
  });

  testWidgets('layout does not throw on desktop viewport', (tester) async {
    _setDesktop(tester);
    final repo = _FakeRepo();
    repo.data = const [
      Supplier(name: 'Mulia', isActive: true, productCount: 3),
    ];
    final p = AdminProvider(repo);
    await tester.pumpWidget(_harness(p));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Mulia'), findsOneWidget);
  });

  testWidgets('desktop table header uses labelLarge + textSecondary', (
    tester,
  ) async {
    _setDesktop(tester);
    final repo = _FakeRepo();
    repo.data = const [
      Supplier(name: 'Mulia', isActive: true, productCount: 3),
    ];
    final p = AdminProvider(repo);
    p.setUserRole('SUPERVISOR');
    await tester.pumpWidget(_harness(p));
    await tester.pumpAndSettle();
    final headerText = tester.widget<Text>(find.text('NAMA SUPPLIER'));
    expect(headerText.style!.fontSize, AppTextStyles.labelLarge.fontSize);
    expect(headerText.style!.color, AppColors.textSecondary);
    expect(headerText.style!.fontWeight, FontWeight.w600);
  });

  testWidgets('desktop table shows column headers', (tester) async {
    _setDesktop(tester);
    final repo = _FakeRepo();
    repo.data = const [
      Supplier(name: 'Mulia', isActive: true, productCount: 3),
    ];
    final p = AdminProvider(repo);
    p.setUserRole('SUPERVISOR');
    await tester.pumpWidget(_harness(p));
    await tester.pumpAndSettle();
    expect(find.text('NAMA SUPPLIER'), findsOneWidget);
    expect(find.text('STATUS'), findsOneWidget);
    expect(find.text('JUMLAH PRODUK'), findsOneWidget);
    expect(find.text('AKSI'), findsNothing);
  });

  testWidgets('desktop table shows AKSI IconButton for MANAGER (not kebab)', (
    tester,
  ) async {
    _setDesktop(tester);
    final repo = _FakeRepo();
    repo.data = const [
      Supplier(name: 'Mulia', isActive: true, productCount: 3),
    ];
    final p = AdminProvider(repo);
    p.setUserRole('MANAGER');
    await tester.pumpWidget(_harness(p));
    await tester.pumpAndSettle();
    expect(find.text('AKSI'), findsOneWidget);
    // Per row: an IconButton with toggle_on / toggle_off
    expect(find.byType(IconButton), findsWidgets);
  });

  testWidgets('desktop table row height is 60', (tester) async {
    _setDesktop(tester);
    final repo = _FakeRepo();
    repo.data = const [
      Supplier(name: 'Mulia', isActive: true, productCount: 3),
    ];
    final p = AdminProvider(repo);
    await tester.pumpWidget(_harness(p));
    await tester.pumpAndSettle();
    final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
    final hasRow60 = sizedBoxes.any((s) => s.height == 60);
    expect(hasRow60, isTrue);
  });

  testWidgets('desktop table row text uses maxLines: 2 and ellipsis', (
    tester,
  ) async {
    _setDesktop(tester);
    final repo = _FakeRepo();
    repo.data = const [
      Supplier(
        name: 'ANUGRAH ARGON MEDICA PT. (BAYER)',
        isActive: true,
        productCount: 0,
      ),
    ];
    final p = AdminProvider(repo);
    await tester.pumpWidget(_harness(p));
    await tester.pumpAndSettle();
    final rowText = tester.widget<Text>(
      find.text('ANUGRAH ARGON MEDICA PT. (BAYER)'),
    );
    expect(rowText.maxLines, 2);
    expect(rowText.overflow, TextOverflow.ellipsis);
  });

  testWidgets('card list shows 1 column on mobile (≤600)', (tester) async {
    _setMobile(tester);
    final repo = _FakeRepo();
    repo.data = const [
      Supplier(name: 'A', isActive: true, productCount: 1),
      Supplier(name: 'B', isActive: true, productCount: 2),
    ];
    final p = AdminProvider(repo);
    await tester.pumpWidget(_harness(p));
    await tester.pumpAndSettle();
    final r1 = tester.getRect(find.text('A'));
    final r2 = tester.getRect(find.text('B'));
    // Stack vertically: same x, different y.
    expect((r1.top - r2.top).abs(), greaterThan(20));
  });

  testWidgets('card list shows 2 columns on tablet (600–1024)', (tester) async {
    _setTablet(tester);
    final repo = _FakeRepo();
    repo.data = const [
      Supplier(name: 'A', isActive: true, productCount: 1),
      Supplier(name: 'B', isActive: true, productCount: 2),
    ];
    final p = AdminProvider(repo);
    await tester.pumpWidget(_harness(p));
    await tester.pumpAndSettle();
    final r1 = tester.getRect(find.text('A'));
    final r2 = tester.getRect(find.text('B'));
    // Side by side: same y, B to right of A.
    expect((r1.top - r2.top).abs(), lessThan(20));
    expect(r2.left, greaterThan(r1.right));
  });
}
