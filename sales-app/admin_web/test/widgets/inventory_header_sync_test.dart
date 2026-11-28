import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_web/core/design_system.dart';

/// Regresi header sticky tabel Stok By Supplier/SKU: saat layar sempit,
/// header dan body memakai dua [SingleChildScrollView] horizontal yang
/// offsetnya disinkronkan lewat listener (pola yang sama dengan
/// InventoryTrackerTab). Uji ini memastikan:
/// 1. tidak ada exception layout (versi OverflowBox lama crash dengan
///    "infinite size during layout" di dalam scroll vertikal),
/// 2. header mengikuti offset body dan mentok di batas yang sama.
void main() {
  testWidgets('header ikut offset body tanpa exception layout', (tester) async {
    final bodyController = ScrollController();
    final headerController = ScrollController();

    // Salinan pola sinkronisasi InventoryTrackerTab: salin offset sumber ke
    // target, dibatasi rentang target, dengan ambang 0.5 px agar sinkronisasi
    // dua arah tidak saling memicu terus.
    void sync(ScrollController source, ScrollController target) {
      if (!source.hasClients || !target.hasClients) return;
      final targetPosition = target.position;
      final value = source.offset.clamp(
        targetPosition.minScrollExtent,
        targetPosition.maxScrollExtent,
      );
      if ((targetPosition.pixels - value).abs() > 0.5) {
        target.jumpTo(value);
      }
    }

    bodyController.addListener(() => sync(bodyController, headerController));
    headerController.addListener(() => sync(headerController, bodyController));

    const columnWidths = {
      0: FlexColumnWidth(),
      1: FixedColumnWidth(150.0),
      2: FixedColumnWidth(130.0),
    };
    const minTableWidth = 600.0;

    Table headerTable() => Table(
      columnWidths: columnWidths,
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          children: [
            TableCell(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text('Supplier'),
              ),
            ),
            TableCell(
              child: Padding(padding: EdgeInsets.all(14), child: Text('Nov')),
            ),
            TableCell(
              child: Padding(padding: EdgeInsets.all(14), child: Text('AP3M')),
            ),
          ],
        ),
      ],
    );

    Table bodyTable() => Table(
      columnWidths: columnWidths,
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: TableBorder(horizontalInside: BorderSide(color: Colors.black26)),
      children: [
        for (var i = 0; i < 5; i++)
          TableRow(
            children: [
              TableCell(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('Row $i'),
                ),
              ),
              TableCell(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text('1.000'),
                ),
              ),
              TableCell(
                child: Padding(padding: EdgeInsets.all(14), child: Text('500')),
              ),
            ],
          ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: AppCard(
                clipBehavior: Clip.none,
                child: AppStickyHeader(
                  header: LayoutBuilder(
                    builder: (context, constraints) {
                      final tableWidth = constraints.maxWidth < minTableWidth
                          ? minTableWidth
                          : constraints.maxWidth;
                      return ScrollConfiguration(
                        behavior: ScrollConfiguration.of(
                          context,
                        ).copyWith(scrollbars: false),
                        child: SingleChildScrollView(
                          controller: headerController,
                          scrollDirection: Axis.horizontal,
                          physics: const NeverScrollableScrollPhysics(),
                          child: SizedBox(
                            width: tableWidth,
                            child: headerTable(),
                          ),
                        ),
                      );
                    },
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final fits = constraints.maxWidth >= minTableWidth;
                      final table = bodyTable();
                      return fits
                          ? table
                          : SingleChildScrollView(
                              controller: bodyController,
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: minTableWidth,
                                child: table,
                              ),
                            );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    // Scroll body ke kanan: header harus mengikuti offset yang sama.
    final bodyMax = bodyController.position.maxScrollExtent;
    expect(bodyMax, greaterThan(0));
    bodyController.jumpTo(bodyMax / 2);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(headerController.offset, closeTo(bodyController.offset, 0.5));

    // Header dan body harus punya rentang scroll yang sama (lebar tabel
    // sama), dan ikut mentok bersama di ujung.
    expect(headerController.position.maxScrollExtent, closeTo(bodyMax, 0.5));
    bodyController.jumpTo(bodyMax * 2);
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(
      headerController.offset,
      closeTo(headerController.position.maxScrollExtent, 0.5),
    );
  });
}
