import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_web/core/design_system/widgets/app_components.dart';

void main() {
  const destinations = [
    AppNavigationItem(
      label: 'Beranda',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
    ),
    AppNavigationItem(
      label: 'Pesanan',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
    ),
    AppNavigationItem(
      label: 'Katalog',
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2,
    ),
    AppNavigationItem(
      label: 'Lainnya',
      icon: Icons.more_horiz,
      selectedIcon: Icons.more_horiz,
    ),
  ];

  Future<void> pumpShell(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: AppAdaptiveShell(
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          destinations: destinations,
          child: const Center(child: Text('Konten')),
        ),
      ),
    );
  }

  testWidgets('uses bottom navigation on mobile', (tester) async {
    await pumpShell(tester, 390);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Beranda'), findsOneWidget);
    expect(find.text('Pesanan'), findsOneWidget);
    expect(find.text('Katalog'), findsOneWidget);
    expect(find.text('Lainnya'), findsOneWidget);
    expect(find.byType(Drawer), findsNothing);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('uses navigation rail on tablet', (tester) async {
    await pumpShell(tester, 800);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('uses branded sidebar on desktop', (tester) async {
    await pumpShell(tester, 1280);

    expect(find.text('SALES'), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('choice chip meets touch target and calls selection', (
    tester,
  ) async {
    var selected = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppChoiceChip(
            label: 'Menunggu',
            selected: true,
            onSelected: () => selected = true,
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(AppChoiceChip)).height,
      greaterThanOrEqualTo(44),
    );
    await tester.tap(find.text('Menunggu'));
    expect(selected, isTrue);
  });
}
