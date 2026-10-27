import 'package:admin_web/core/design_system/app_colors.dart';
import 'package:admin_web/core/design_system/app_theme.dart';
import 'package:admin_web/core/design_system/widgets/app_adaptive_table.dart';
import 'package:admin_web/core/design_system/widgets/app_button.dart';
import 'package:admin_web/core/design_system/widgets/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('palet utama memakai Deep Navy #183558', () {
    expect(AppColors.primary, const Color(0xFF183558));
    expect(AppTheme.lightTheme.scaffoldBackgroundColor, AppColors.scaffoldBg);
  });

  testWidgets('AppButton memanggil callback, diam saat loading', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppButton(label: 'Simpan', onPressed: () => taps++),
        ),
      ),
    );
    await tester.tap(find.text('Simpan'));
    expect(taps, 1);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppButton(
            label: 'Simpan',
            isLoading: true,
            onPressed: () => taps++,
          ),
        ),
      ),
    );
    await tester.tap(find.byType(AppButton));
    expect(taps, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('AppAdaptiveDataView: card di mobile, DataTable di desktop',
      (tester) async {
    final columns = [
      AppTableColumn<String>(label: 'Nama', cell: (item) => Text(item)),
    ];

    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppAdaptiveDataView<String>(columns: columns, rows: const ['Budi']),
        ),
      ),
    );
    expect(find.byType(DataTable), findsNothing);
    expect(find.text('Budi'), findsOneWidget);
    expect(tester.takeException(), isNull);

    tester.view.physicalSize = const Size(1280, 800);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppAdaptiveDataView<String>(columns: columns, rows: const ['Budi']),
        ),
      ),
    );
    expect(find.byType(DataTable), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppShell: sidebar desktop, rail tablet, drawer mobile',
      (tester) async {
    const items = [
      AppShellNavItem(
        icon: Icons.dashboard_outlined,
        selectedIcon: Icons.dashboard,
        label: 'Dashboard',
      ),
      AppShellNavItem(
        icon: Icons.store_outlined,
        selectedIcon: Icons.store,
        label: 'Toko',
        showBadge: true,
      ),
    ];
    var tapped = -1;

    Future<void> pumpShell(double width) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: AppShell(
            title: 'Toko',
            brandTitle: 'Sales Order',
            items: items,
            selectedIndex: 0,
            onIndexSelected: (i) => tapped = i,
            userName: 'Budi',
            roleLabel: 'Administrator',
            body: const Text('konten'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    addTearDown(tester.view.reset);

    // Desktop: sidebar penuh dengan label, tanpa rail.
    await pumpShell(1280);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Sales Order'), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);

    // Tablet: rail sempit, label nav tidak dirender.
    await pumpShell(800);
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('Sales Order'), findsNothing);

    // Mobile: AppBar + drawer navy.
    await pumpShell(360);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(AppBar), findsOneWidget);
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    expect(find.text('Sales Order'), findsOneWidget);
    await tester.tap(
      find.descendant(of: find.byType(Drawer), matching: find.text('Toko')),
    );
    await tester.pumpAndSettle();
    expect(tapped, 1);
    expect(tester.takeException(), isNull);
  });
}
