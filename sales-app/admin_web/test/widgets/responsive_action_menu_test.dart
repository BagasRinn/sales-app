import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_web/core/design_system.dart';
import 'package:admin_web/presentation/widgets/responsive_action_menu.dart';

Widget _harness(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Center(child: child),
    ),
  );
}

void main() {
  group('ResponsiveActionMenu', () {
    testWidgets('empty actions list renders SizedBox.shrink (no trigger)',
        (tester) async {
      await tester.pumpWidget(_harness(
        const ResponsiveActionMenu(actions: []),
      ));

      // No PopupMenuButton trigger should be present.
      expect(find.byType(PopupMenuButton<MenuAction>), findsNothing);
      expect(find.byIcon(Icons.more_vert), findsNothing);
    });

    testWidgets('single action renders 44x44 PopupMenuButton trigger',
        (tester) async {
      await tester.pumpWidget(_harness(
        ResponsiveActionMenu(
          actions: [
            MenuAction(
              label: 'Edit',
              icon: Icons.edit,
              onTap: () {},
            ),
          ],
        ),
      ));

      final btnFinder = find.byType(PopupMenuButton<MenuAction>);
      expect(btnFinder, findsOneWidget);

      // The 44x44 wrapper is the *outer* ConstrainedBox ancestor of the
      // PopupMenuButton — there is a PopupMenuButton-internal ConstrainedBox
      // too, so we have to walk up to the first ancestor ConstrainedBox.
      final wrapper = tester.widget<ConstrainedBox>(
        find.ancestor(of: btnFinder, matching: find.byType(ConstrainedBox)).first,
      );
      expect(wrapper.constraints.minWidth, 44);
      expect(wrapper.constraints.minHeight, 44);
    });

    testWidgets('tap on trigger opens menu with correct MenuAction items',
        (tester) async {
      var editTaps = 0;
      var shareTaps = 0;
      await tester.pumpWidget(_harness(
        ResponsiveActionMenu(
          actions: [
            MenuAction(
              label: 'Edit',
              icon: Icons.edit,
              onTap: () => editTaps++,
            ),
            MenuAction(
              label: 'Share',
              icon: Icons.share,
              onTap: () => shareTaps++,
            ),
          ],
        ),
      ));

      // Open the menu
      await tester.tap(find.byType(PopupMenuButton<MenuAction>));
      await tester.pumpAndSettle();

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);

      // Tap Edit — menu should close and callback should fire
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(editTaps, 1);
      expect(shareTaps, 0);
    });

    testWidgets('destructive action shows red icon + text color',
        (tester) async {
      await tester.pumpWidget(_harness(
        ResponsiveActionMenu(
          actions: [
            MenuAction(
              label: 'Hapus',
              icon: Icons.delete,
              onTap: () {},
              destructive: true,
            ),
          ],
        ),
      ));

      await tester.tap(find.byType(PopupMenuButton<MenuAction>));
      await tester.pumpAndSettle();

      // The row inside the menu item shows an Icon + Text styled with
      // AppColors.error. Find the icon (delete) and verify its color.
      final deleteIcon = tester.widget<Icon>(find.byIcon(Icons.delete));
      expect(deleteIcon.color, AppColors.error);

      // Label text should also carry the error color.
      final labelText = tester.widget<Text>(find.text('Hapus'));
      expect(labelText.style?.color, AppColors.error);
    });
  });
}
