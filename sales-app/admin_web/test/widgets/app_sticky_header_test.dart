import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_web/core/design_system/widgets/app_sticky_header.dart';

void main() {
  // Tata letak acuan: spacer 100px, kartu A (header 40px + badan 800px),
  // jarak 24px, kartu B (header 40px + badan 800px).
  Widget buildPage(ScrollController controller) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          controller: controller,
          child: Column(
            children: [
              const SizedBox(height: 100),
              AppStickyHeader(
                header: SizedBox(
                  height: 40,
                  child: Text('Header A'),
                ),
                child: const SizedBox(height: 800),
              ),
              const SizedBox(height: 24),
              AppStickyHeader(
                header: SizedBox(
                  height: 40,
                  child: Text('Header B'),
                ),
                child: const SizedBox(height: 800),
              ),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('header menempel di tepi atas viewport lalu lepas saat kartu lewat', (
    tester,
  ) async {
    final controller = ScrollController();
    await tester.pumpWidget(buildPage(controller));
    await tester.pump(); // flush ukuran header hasil post-frame

    final headerA = find.text('Header A');
    expect(tester.getTopLeft(headerA).dy, 100);

    // Kartu A memotong tepi atas: header menempel di 0.
    controller.jumpTo(300);
    await tester.pump();
    expect(tester.getTopLeft(headerA).dy, 0);

    // Saat pin, header diberi border bawah sebagai pemisah dari baris.
    final decoration = tester
        .widget<DecoratedBox>(
          find.descendant(
            of: find.byType(AppStickyHeader).first,
            matching: find.byType(DecoratedBox),
          ),
        )
        .decoration as BoxDecoration;
    expect(decoration.border, isNotNull);

    // Sisa kartu A tinggal 40px (= tinggi header): masih menempel penuh.
    controller.jumpTo(900);
    await tester.pump();
    expect(tester.getTopLeft(headerA).dy, 0);

    // Bawah kartu melewati header: header terangkat keluar bersama kartunya.
    controller.jumpTo(920);
    await tester.pump();
    expect(tester.getTopLeft(headerA).dy, -20);
  });

  testWidgets('kartu kedua pin independen setelah kartu pertama lewat', (
    tester,
  ) async {
    final controller = ScrollController();
    await tester.pumpWidget(buildPage(controller));
    await tester.pump();

    final headerA = find.text('Header A');
    final headerB = find.text('Header B');

    // Keduanya masih di posisi natural.
    expect(tester.getTopLeft(headerA).dy, 100);
    expect(tester.getTopLeft(headerB).dy, 100 + 840 + 24);

    // Scroll di tengah kartu A: hanya header A yang pin.
    controller.jumpTo(300);
    await tester.pump();
    expect(tester.getTopLeft(headerA).dy, 0);
    expect(tester.getTopLeft(headerB).dy, 100 + 840 + 24 - 300);

    // Kartu A sudah lewat seluruhnya, kartu B memotong tepi atas: B pin.
    controller.jumpTo(1000);
    await tester.pump();
    expect(tester.getTopLeft(headerA).dy, -100);
    expect(tester.getTopLeft(headerB).dy, 0);
  });

  testWidgets('tanpa leluhur Scrollable, header tampil statis', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const SizedBox(height: 100),
              AppStickyHeader(
                header: SizedBox(
                  height: 40,
                  child: Text('Header A'),
                ),
                child: const SizedBox(height: 200),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.getTopLeft(find.text('Header A')).dy, 100);
  });
}
