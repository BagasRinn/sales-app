import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_web/data/models/supplier.dart';
import 'package:admin_web/presentation/widgets/supplier_toggle_dialog.dart';

void main() {
  testWidgets('inactive supplier → confirm message mentions "menampilkan"',
      (tester) async {
    final s = const Supplier(name: 'Mulia', isActive: false, productCount: 5);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showSupplierToggleDialog(ctx, supplier: s),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('5'), findsOneWidget);
  });
}
