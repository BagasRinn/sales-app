import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_web/core/responsive_dialog.dart';

/// Helper: builds a fixed-viewport Material host so ResponsiveDialog can use
/// its inner LayoutBuilder with the requested constraints.
Widget _harness({
  required double width,
  required double height,
  required Widget child,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          height: height,
          child: child,
        ),
      ),
    ),
  );
}

/// Ensures the test surface is wide enough that ResponsiveDialog's
/// desktopWidthFraction (default 0.94) * width > 960. Without this the
/// binding's default 800x600 surface clamps us to 752 and the test cannot
/// see the 960 cap kick in.
void _useWideSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(2400, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  group('ResponsiveDialog', () {
    testWidgets('renders child on compact viewport', (tester) async {
      await tester.pumpWidget(_harness(
        width: 400,
        height: 800,
        child: const ResponsiveDialog(
          child: Text('hello compact'),
        ),
      ));

      expect(find.text('hello compact'), findsOneWidget);
    });

    testWidgets('respects maxWidth clamp on desktop (960)', (tester) async {
      // Need the test surface wider than 960/0.94 ≈ 1022 so the clamp engages.
      _useWideSurface(tester);
      await tester.pumpWidget(_harness(
        width: 2000,
        height: 2000,
        child: const ResponsiveDialog(
          maxWidth: 960,
          maxHeight: 600,
          child: Text('hello desktop'),
        ),
      ));

      // Inner SizedBox.width should be clamped to 960.
      final sizedBoxes = tester
          .widgetList<SizedBox>(find.descendant(
            of: find.byType(ResponsiveDialog),
            matching: find.byType(SizedBox),
          ))
          .toList();
      final inner = sizedBoxes.firstWhere(
        (s) => s.width != null && s.width! >= 100,
        orElse: () => const SizedBox.shrink(),
      );
      expect(inner.width, 960);
      expect(inner.height, 600);
    });
  });

  group('ResponsiveAlertDialog', () {
    testWidgets('stacks actions vertically on compact', (tester) async {
      await tester.pumpWidget(_harness(
        width: 400,
        height: 800,
        child: ResponsiveAlertDialog(
          title: const Text('Judul'),
          content: const Text('Isi'),
          actions: [
            TextButton(onPressed: () {}, child: const Text('Cancel')),
            FilledButton(onPressed: () {}, child: const Text('OK')),
          ],
        ),
      ));

      // On compact, the actions live inside a Column, not a Row.
      final column = find.descendant(
        of: find.byType(ResponsiveAlertDialog),
        matching: find.byType(Column),
      );
      expect(column, findsWidgets);

      // The outer-most Column that holds the actions contains a Row with the
      // title + close icon at the top. Easiest stable check: Column should
      // exist, and there should be NO Row whose children include BOTH action
      // buttons (so the action-area is not a Row).
      final rowsContainingActions = find
          .byType(Row)
          .evaluate()
          .where((element) {
            final row = element.widget as Row;
            final labels = row.children
                .whereType<Text>()
                .map((t) => t.data)
                .whereType<String>()
                .toList();
            return labels.contains('Cancel') && labels.contains('OK');
          })
          .toList();
      expect(rowsContainingActions, isEmpty);
    });

    testWidgets('places actions in a Row on desktop', (tester) async {
      _useWideSurface(tester);
      await tester.pumpWidget(_harness(
        width: 1200,
        height: 900,
        child: ResponsiveAlertDialog(
          title: const Text('Judul'),
          content: const Text('Isi'),
          actions: [
            TextButton(onPressed: () {}, child: const Text('Cancel')),
            FilledButton(onPressed: () {}, child: const Text('OK')),
          ],
        ),
      ));

      // On desktop, a Row should exist that contains both action labels.
      // Row children here are ConstrainedBox wrappers around the action
      // widgets (TextButton/FilledButton), so we have to walk one level.
      bool rowContainsBothLabels(Row row) {
        final labels = <String>[];
        void walk(Widget? w) {
          if (w == null) return;
          if (w is Text && w.data != null) {
            labels.add(w.data!);
            return;
          }
          if (w is ConstrainedBox) {
            walk(w.child);
            return;
          }
          if (w is TextButton) {
            walk(w.child);
            return;
          }
          if (w is FilledButton) {
            walk(w.child);
            return;
          }
        }

        for (final child in row.children) {
          walk(child);
        }
        return labels.contains('Cancel') && labels.contains('OK');
      }

      final rowsWithBothActions = find
          .byType(Row)
          .evaluate()
          .where((element) => rowContainsBothLabels(element.widget as Row))
          .toList();
      expect(rowsWithBothActions, isNotEmpty);
    });

    testWidgets('shows Close IconButton only on compact', (tester) async {
      // Compact: close button visible
      await tester.pumpWidget(_harness(
        width: 400,
        height: 800,
        child: ResponsiveAlertDialog(
          title: const Text('Judul Mobile'),
          content: const Text('Isi'),
          actions: [
            TextButton(onPressed: () {}, child: const Text('OK')),
          ],
        ),
      ));
      expect(find.byIcon(Icons.close), findsOneWidget);

      // Desktop: no close button
      await tester.pumpWidget(_harness(
        width: 1200,
        height: 900,
        child: ResponsiveAlertDialog(
          title: const Text('Judul Desktop'),
          content: const Text('Isi'),
          actions: [
            TextButton(onPressed: () {}, child: const Text('OK')),
          ],
        ),
      ));
      expect(find.byIcon(Icons.close), findsNothing);
    });
  });
}
