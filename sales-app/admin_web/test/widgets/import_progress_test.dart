import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:admin_web/presentation/widgets/import_progress.dart';

void main() {
  testWidgets('menampilkan info file, tahap, dan elapsed time', (tester) async {
    final completer = Completer<bool>();
    late BuildContext context;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) {
              context = ctx;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    final future = ImportProgressOverlay.run<bool>(
      context,
      title: 'Mengimport Data Produk',
      fileName: 'produk.xlsx',
      fileSize: 5 * 1024 * 1024,
      task: (session) => completer.future,
    );

    await tester.pump();

    expect(find.text('Mengimport Data Produk'), findsOneWidget);
    expect(find.text('produk.xlsx'), findsOneWidget);
    expect(find.text('5.0 MB'), findsOneWidget);
    expect(find.text('Menyiapkan import...'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      isNull,
    );
    expect(find.text('00:00'), findsOneWidget);
    expect(find.textContaining('Jangan tutup'), findsOneWidget);

    await tester.pump(const Duration(seconds: 6));

    expect(find.text('00:06'), findsOneWidget);

    completer.complete(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Mengimport Data Produk'), findsNothing);
    expect(await future, isTrue);
  });

  testWidgets('persen upload dan progres backend tampil real', (tester) async {
    final completer = Completer<bool>();
    late BuildContext context;
    String? polledJobId;
    String? taskJobId;
    var snapshotCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) {
              context = ctx;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    final future = ImportProgressOverlay.run<bool>(
      context,
      title: 'Mengimport Laporan Penjualan',
      fileName: 'penjualan.xlsx',
      fileSize: 52 * 1024 * 1024,
      progressFetcher: (jobId) async {
        polledJobId = jobId;
        snapshotCalls++;
        // Poll pertama terjadi saat upload masih berjalan dan job belum
        // terdaftar di backend.
        if (snapshotCalls == 1) return null;
        return {
          'percent': 50,
          'stage': 'Memproses baris penjualan (1.000 / 2.000 baris)',
          'done': false,
          'success': null,
          'error': null,
        };
      },
      task: (session) {
        taskJobId = session.jobId;
        session.onSendProgress(80, 100);
        return completer.future;
      },
    );

    await tester.pump();

    // Upload 80% dipetakan ke 8% dari total progres.
    expect(find.text('8%'), findsOneWidget);
    expect(find.text('Mengunggah file ke server (80%)...'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();

    // Backend 50% dipetakan ke 10% + 90% * 50% = 55%.
    expect(polledJobId, taskJobId);
    expect(find.text('55%'), findsOneWidget);
    expect(
      find.text('Memproses baris penjualan (1.000 / 2.000 baris)'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      closeTo(0.55, 0.0001),
    );

    completer.complete(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(await future, isTrue);
    expect(find.text('Mengimport Laporan Penjualan'), findsNothing);
  });

  testWidgets('overlay dibersihkan ketika import gagal', (tester) async {
    late BuildContext context;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) {
              context = ctx;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );

    final completer = Completer<bool>();
    final future = ImportProgressOverlay.run<bool>(
      context,
      title: 'Mengimport Data Toko',
      task: (session) => completer.future,
    );
    final expectation = expectLater(future, throwsStateError);

    await tester.pump();
    expect(find.text('Mengimport Data Toko'), findsOneWidget);

    completer.completeError(StateError('import gagal'));
    await expectation;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Mengimport Data Toko'), findsNothing);
  });
}
