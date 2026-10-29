import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:sales_app_mobile/data/models/product.dart';
import 'package:sales_app_mobile/data/repositories/api_service.dart';
import 'package:sales_app_mobile/data/repositories/product_repository.dart';
import 'package:sales_app_mobile/presentation/providers/draft_order_provider.dart';
import 'package:sales_app_mobile/presentation/providers/product_provider.dart';
import 'package:sales_app_mobile/presentation/screens/order_flow/step_review.dart';

class _FakeProductRepo extends ProductRepository {
  _FakeProductRepo() : super(ApiService());

  final products = [
    Product(
      id: 'P1',
      namaBarang: 'Produk Uji',
      harga: 10000,
      stokSistem: 100,
      stokBooking: 0,
      stokTersedia: 100,
    ),
    Product(
      id: 'P2',
      namaBarang: 'Produk Kedua',
      harga: 5000,
      stokSistem: 100,
      stokBooking: 0,
      stokTersedia: 100,
    ),
  ];

  @override
  Future<List<Product>> getProducts({
    int skip = 0,
    int limit = 50,
    String? search,
    String? orderType,
  }) async => products;

  @override
  Future<Product> getProduct(String productId) async =>
      products.firstWhere((p) => p.id == productId);
}

Future<void> _pump(WidgetTester tester, DraftOrderProvider draft) async {
  final repo = _FakeProductRepo();
  final products = ProductProvider(repo);
  await products.loadProducts(orderType: 'REGULER');

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: draft),
        ChangeNotifierProvider.value(value: products),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: StepReview(onBack: () {}, onSaveDraft: () {}, onSubmit: () {}),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('diskon, up price, gratis, dan hapus bekerja', (tester) async {
    tester.view.physicalSize = const Size(2400, 3600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final draft = DraftOrderProvider();
    draft.setCustomerDirect(id: 'C1', namaToko: 'Toko Uji');
    draft.setPricingCache({'P1': 10000});
    draft.addLine('P1', qty: 2);
    await _pump(tester, draft);

    // ── Diskon ──
    await tester.tap(find.byIcon(Icons.discount_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Edit Diskon'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(1), '10');
    await tester.pump();
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(draft.items.single.discount?.layer1?.value, 10);
    expect(draft.items.single.discount?.layer1?.type, 'PERCENT');
    expect(find.textContaining('Diskon 1:'), findsOneWidget);

    // ── Up price ──
    await tester.tap(find.byIcon(Icons.trending_up));
    await tester.pumpAndSettle();
    expect(find.text('Edit Up Price'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(1), '500');
    await tester.pump();
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(draft.items.single.upPrice?.nominal, 500);
    expect(find.textContaining('Up Price: +'), findsOneWidget);

    // ── Barang gratis ──
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Barang Gratis'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '1');
    await tester.pump();
    await tester.tap(find.text('Tambah'));
    await tester.pumpAndSettle();
    expect(draft.items.length, 2);
    expect(draft.items.last.discount?.layer1?.value, 100);
    expect(draft.items.last.isFree, isTrue);
    expect(find.text('GRATIS'), findsOneWidget);
    expect(find.text('Item gratis: 1'), findsOneWidget);

    // ── Hapus line (barang gratis punya menu Hapus) ──
    await tester.tap(find.byIcon(Icons.more_vert).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(draft.items.length, 1);
    expect(find.text('GRATIS'), findsNothing);
    expect(find.text('Item gratis: 1'), findsNothing);
  });

  testWidgets('baris kedua ikut ter-update saat qty/diskon/kuantitas diubah', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(2400, 3600);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final draft = DraftOrderProvider();
    draft.setCustomerDirect(id: 'C1', namaToko: 'Toko Uji');
    draft.setPricingCache({'P1': 10000, 'P2': 5000});
    draft.addLine('P1', qty: 1);
    draft.addLine('P2', qty: 1);
    await _pump(tester, draft);
    expect(draft.items[0].id, isNot(draft.items[1].id));

    // Plus di baris pertama → qty 2 dan total item 3.
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();
    expect(draft.items.first.qty, 2);
    expect(draft.items.last.qty, 1);
    expect(find.text('× 2 · Rp 10.000'), findsOneWidget);
    expect(draft.totalItems, 3);
    expect(find.text('× 1 · Rp 5.000'), findsOneWidget);

    // Diskon di baris pertama.
    await tester.tap(find.byIcon(Icons.discount_outlined).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), '10');
    await tester.pump();
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Diskon 1:'), findsOneWidget);
    expect(draft.items.first.discount?.layer1?.value, 10);
    expect(draft.items.last.discount, isNull);

    // Hapus baris pertama → baris kedua tetap tampil dengan data yang benar.
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(draft.items.length, 1);
    expect(draft.items.single.productId, 'P2');
    expect(find.text('Produk Kedua'), findsOneWidget);
    expect(find.text('× 1 · Rp 5.000'), findsOneWidget);
    expect(find.textContaining('Diskon 1:'), findsNothing);
  });
}
