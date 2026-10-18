import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_web/presentation/widgets/supplier_create_dialog.dart';

void main() {
  testWidgets('shows dialog with name field and Simpan/Batal buttons',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showSupplierCreateDialog(ctx),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Buat Supplier Baru'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('Simpan'), findsOneWidget);
    expect(find.text('Batal'), findsOneWidget);
  });

  testWidgets('submitting an empty name shows validation error',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showSupplierCreateDialog(ctx),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Nama wajib diisi'), findsOneWidget);
  });
}
