import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_web/core/design_system.dart';
import 'package:admin_web/presentation/widgets/stat_tile.dart';

Widget _harness(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: SizedBox(width: 320, child: child),
      ),
    ),
  );
}

void main() {
  group('StatTile', () {
    testWidgets('renders label and value', (tester) async {
      await tester.pumpWidget(_harness(
        const StatTile(
          label: 'Total Pesanan',
          value: '1.234',
        ),
      ));

      expect(find.text('Total Pesanan'), findsOneWidget);
      expect(find.text('1.234'), findsOneWidget);
    });

    testWidgets('renders icon tile when icon provided', (tester) async {
      await tester.pumpWidget(_harness(
        const StatTile(
          label: 'Pelanggan',
          value: '57',
          icon: Icons.people,
        ),
      ));

      expect(find.byIcon(Icons.people), findsOneWidget);
    });

    testWidgets('trend chip renders with up arrow + success color when trendUp',
        (tester) async {
      await tester.pumpWidget(_harness(
        const StatTile(
          label: 'Omzet',
          value: '10jt',
          trend: '+12%',
          trendUp: true,
        ),
      ));

      // The trend text is rendered as-is (no arrow glyph in source — chip
      // just shows the supplied text). What we CAN verify: the chip's text
      // widget carries AppColors.success (the foreground of the up chip).
      final trendText = tester.widget<Text>(find.text('+12%'));
      expect(trendText.style?.color, AppColors.success);
    });

    testWidgets('trend chip renders with error color when trendUp=false',
        (tester) async {
      await tester.pumpWidget(_harness(
        const StatTile(
          label: 'Omzet',
          value: '7jt',
          trend: '-8%',
          trendUp: false,
        ),
      ));

      final trendText = tester.widget<Text>(find.text('-8%'));
      expect(trendText.style?.color, AppColors.error);
    });

    testWidgets('onTap fires callback', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_harness(
        StatTile(
          label: 'Klik Saya',
          value: '0',
          onTap: () => taps++,
        ),
      ));

      // onTap creates an InkWell inside the tile.
      expect(find.byType(InkWell), findsOneWidget);

      await tester.tap(find.byType(InkWell));
      await tester.pump();
      expect(taps, 1);
    });
  });
}
