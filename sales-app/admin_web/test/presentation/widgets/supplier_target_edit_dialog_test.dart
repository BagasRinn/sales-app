import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:admin_web/data/models/supplier_performance.dart';
import 'package:admin_web/data/repositories/api_service.dart';
import 'package:admin_web/data/repositories/admin_repository.dart';
import 'package:admin_web/presentation/providers/admin_provider.dart';
import 'package:admin_web/presentation/widgets/supplier_target_edit_dialog.dart';
import 'package:dio/dio.dart';

class _FakeApi extends ApiService {
  dynamic getResponse;
  dynamic putResponse;
  Object? putError;
  final List<({String path, Map<String, dynamic>? body})> putCalls = [];
  final List<String> getCalls = [];

  @override
  Future<dynamic> get(String endpoint,
      {CancelToken? cancelToken, Duration? receiveTimeout}) async {
    getCalls.add(endpoint);
    return getResponse;
  }

  @override
  Future<dynamic> put(String endpoint,
      {Map<String, dynamic>? body, CancelToken? cancelToken}) async {
    putCalls.add((path: endpoint, body: body));
    if (putError != null) throw putError!;
    return putResponse;
  }
}

class _TestEnv {
  final _FakeApi api;
  final AdminProvider provider;
  _TestEnv(this.api, this.provider);
}

Future<_TestEnv> openDialog(
  WidgetTester tester, {
  required List<SupplierPerformanceRow> rows,
  required String branch,
}) async {
  final fake = _FakeApi();
  fake.getResponse = rows
      .map((r) => {
            'supplier_name': r.supplierName,
            'target': r.target,
            'has_target': r.hasTarget,
            'value': r.value,
            'pencapaian': r.pencapaian,
          })
      .toList();
  final provider = AdminProvider(AdminRepository(fake));
  provider.setUserBranch(branch);
  await provider.loadSupplierPerformance(yearMonth: '2026-10');

  await tester.pumpWidget(
    MaterialApp(
      home: ChangeNotifierProvider<AdminProvider>.value(
        value: provider,
        child: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () => showSupplierTargetEditDialog(
                  ctx,
                  provider,
                  supplierName: 'PT X',
                  period: '2026-10',
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return _TestEnv(fake, provider);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  testWidgets('dialog prefills with current month target', (tester) async {
    await openDialog(
      tester,
      rows: const [
        SupplierPerformanceRow(
          supplierName: 'PT X',
          target: 5000,
          hasTarget: true,
          value: 0,
          pencapaian: null,
        ),
      ],
      branch: 'BATULICIN',
    );
    expect(find.text('Edit Target'), findsOneWidget);
    expect(find.textContaining('PT X'), findsWidgets);
    final TextField field = tester.widget(find.byType(TextField));
    expect(field.controller!.text, '5000');
  });

  testWidgets('dialog prefills with 0 when no current month target',
      (tester) async {
    await openDialog(
      tester,
      rows: const [
        SupplierPerformanceRow(
          supplierName: 'PT X',
          target: 0,
          hasTarget: false,
          value: 100,
          pencapaian: null,
        ),
      ],
      branch: 'BATULICIN',
    );
    final TextField field = tester.widget(find.byType(TextField));
    expect(field.controller!.text, '0');
  });

  testWidgets('save with valid value calls PUT, dialog dismisses, table refreshes',
      (tester) async {
    final env = await openDialog(
      tester,
      rows: const [
        SupplierPerformanceRow(
          supplierName: 'PT X',
          target: 5000,
          hasTarget: true,
          value: 0,
          pencapaian: null,
        ),
      ],
      branch: 'BATULICIN',
    );
    env.api.putResponse = {
      'id': 'u-1',
      'branch': 'BATULICIN',
      'supplier_name': 'PT X',
      'period': '2026-10',
      'target_value': 8000,
    };
    await tester.enterText(find.byType(TextField), '8000');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Target'), findsNothing);
    // The PUT was called with the new value.
    expect(env.api.putCalls, hasLength(1));
    expect(env.api.putCalls.single.body, {'target_value': 8000});
    expect(env.api.putCalls.single.path,
        '/supplier-targets/BATULICIN/PT%20X/2026-10');
  });

  testWidgets('save with negative value shows validation error, no PUT call',
      (tester) async {
    final env = await openDialog(
      tester,
      rows: const [
        SupplierPerformanceRow(
          supplierName: 'PT X',
          target: 0,
          hasTarget: false,
          value: 0,
          pencapaian: null,
        ),
      ],
      branch: 'BATULICIN',
    );
    // Bypass the digitsOnly formatter by writing to the controller directly.
    final TextField field = tester.widget(find.byType(TextField));
    field.controller!.text = '-1';
    await tester.tap(find.text('Simpan'));
    await tester.pump();
    // Dialog stays open.
    expect(find.text('Edit Target'), findsOneWidget);
    // No PUT was made.
    expect(env.api.putCalls, isEmpty);
  });
}
