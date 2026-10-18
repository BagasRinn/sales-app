import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_web/presentation/widgets/data_card.dart';

Widget _harness(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: SizedBox(width: 600, child: child),
      ),
    ),
  );
}

void main() {
  group('DataCard', () {
    testWidgets('renders title and subtitle when provided', (tester) async {
      await tester.pumpWidget(_harness(
        const DataCard(
          title: 'Kartu Title',
          subtitle: 'Subtitle di sini',
        ),
      ));

      expect(find.text('Kartu Title'), findsOneWidget);
      expect(find.text('Subtitle di sini'), findsOneWidget);
    });

    testWidgets('renders badges in a Wrap row', (tester) async {
      await tester.pumpWidget(_harness(
        DataCard(
          title: 'With Badges',
          badges: const [
            Chip(label: Text('A')),
            Chip(label: Text('B')),
            Chip(label: Text('C')),
          ],
        ),
      ));

      expect(find.text('A'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);

      // All three chips live inside the badges Wrap.
      final wrap = find.descendant(
        of: find.byType(DataCard),
        matching: find.byType(Wrap),
      );
      expect(wrap, findsWidgets);

      // The chip widget count is at least 3.
      expect(find.byType(Chip), findsNWidgets(3));
    });

    testWidgets('renders fields with label + value', (tester) async {
      await tester.pumpWidget(_harness(
        const DataCard(
          fields: [
            DataField(label: 'Nama', value: 'Budi'),
            DataField(label: 'Email', value: 'budi@x.id'),
          ],
        ),
      ));

      expect(find.text('Nama'), findsOneWidget);
      expect(find.text('Budi'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('budi@x.id'), findsOneWidget);
    });

    testWidgets('valueWidget takes precedence over value', (tester) async {
      await tester.pumpWidget(_harness(
        const DataCard(
          fields: [
            DataField(
              label: 'Status',
              value: 'pending-as-text',
              valueWidget: Chip(label: Text('Disetujui')),
            ),
          ],
        ),
      ));

      // valueWidget wins → "Disetujui" rendered, raw "pending-as-text" is not.
      expect(find.text('Disetujui'), findsOneWidget);
      expect(find.text('pending-as-text'), findsNothing);
    });

    testWidgets('actions render at bottom with 36+ min height',
        (tester) async {
      await tester.pumpWidget(_harness(
        DataCard(
          title: 'Has Actions',
          actions: [
            TextButton(onPressed: () {}, child: const Text('Batal')),
            FilledButton(onPressed: () {}, child: const Text('Simpan')),
          ],
        ),
      ));

      // Each action should be wrapped in a ConstrainedBox with minHeight 36.
      final constraints = tester
          .widgetList<ConstrainedBox>(find.descendant(
            of: find.byType(DataCard),
            matching: find.byType(ConstrainedBox),
          ))
          .where((cb) => cb.constraints.minHeight >= 36)
          .toList();
      expect(constraints.length, greaterThanOrEqualTo(2));
    });

    testWidgets('onTap wraps content in InkWell and fires callback',
        (tester) async {
      var tapCount = 0;
      await tester.pumpWidget(_harness(
        DataCard(
          title: 'Tappable',
          onTap: () => tapCount++,
        ),
      ));

      // InkWell should be present when onTap is provided.
      expect(find.byType(InkWell), findsOneWidget);

      await tester.tap(find.byType(InkWell));
      await tester.pump();
      expect(tapCount, 1);
    });

    testWidgets(
        '1-field DataCard uses horizontal Row layout (label left, value right)',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 360,
              child: const DataCard(
                title: 'Product',
                fields: [
                  DataField(label: 'Jumlah', value: '12'),
                ],
              ),
            ),
          ),
        ),
      ));

      final labelRect = tester.getRect(find.text('Jumlah'));
      final valueRect = tester.getRect(find.text('12'));
      // Same vertical center → side by side, not stacked.
      expect(
        (labelRect.center.dy - valueRect.center.dy).abs(),
        lessThan(5),
      );
      expect(valueRect.left, greaterThan(labelRect.right));
    });

    testWidgets('2-field DataCard lays fields side by side on row 1',
        (tester) async {
      await tester.pumpWidget(_harness(
        const DataCard(
          fields: [
            DataField(label: 'Field A', value: 'AA'),
            DataField(label: 'Field B', value: 'BB'),
          ],
        ),
      ));

      final labelARect = tester.getRect(find.text('Field A'));
      final labelBRect = tester.getRect(find.text('Field B'));
      expect(
        (labelARect.center.dy - labelBRect.center.dy).abs(),
        lessThan(5),
      );
      expect(labelBRect.left, greaterThan(labelARect.right));
    });
  });
}
