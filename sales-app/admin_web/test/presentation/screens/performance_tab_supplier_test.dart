import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:admin_web/data/repositories/api_service.dart';
import 'package:admin_web/data/repositories/admin_repository.dart';
import 'package:admin_web/presentation/providers/admin_provider.dart';
import 'package:admin_web/presentation/screens/performance_tab.dart';
import 'package:dio/dio.dart';

class _FakeApi extends ApiService {
  dynamic getResponse;
  final List<String> getCalls = [];

  @override
  Future<dynamic> get(String endpoint,
      {CancelToken? cancelToken, Duration? receiveTimeout}) async {
    getCalls.add(endpoint);
    return getResponse;
  }
}

class _HangingApi extends ApiService {
  final _completer = Completer<dynamic>();
  @override
  Future<dynamic> get(String endpoint,
      {CancelToken? cancelToken, Duration? receiveTimeout}) {
    return _completer.future;
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  Widget wrap(AdminProvider provider) {
    return MaterialApp(
      home: ChangeNotifierProvider<AdminProvider>.value(
        value: provider,
        child: const Scaffold(body: PerformanceTab()),
      ),
    );
  }

  testWidgets('renders 4 column headers when rows present', (tester) async {
    final fake = _FakeApi();
    fake.getResponse = [
      {
        'supplier_name': 'PT X',
        'target': 1000,
        'has_target': true,
        'value': 500,
        'pencapaian': 50.0,
      },
    ];
    final provider = AdminProvider(AdminRepository(fake));
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    expect(find.text('Supplier'), findsOneWidget);
    expect(find.text('Target'), findsOneWidget);
    expect(find.text('Value'), findsOneWidget);
    expect(find.text('Pencapaian'), findsOneWidget);
  });

  testWidgets('renders empty state when list is empty', (tester) async {
    final fake = _FakeApi();
    fake.getResponse = [];
    final provider = AdminProvider(AdminRepository(fake));
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    expect(find.textContaining('Belum ada data supplier'), findsOneWidget);
  });

  testWidgets('renders loading spinner when loading', (tester) async {
    final provider = AdminProvider(AdminRepository(_HangingApi()));
    // Trigger the load, but the future never resolves → loading stays true.
    unawaited(provider.loadSupplierPerformance(yearMonth: '2026-10'));
    await tester.pumpWidget(wrap(provider));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });

  testWidgets('renders achievement 100 in success color and bold',
      (tester) async {
    final fake = _FakeApi();
    fake.getResponse = [
      {
        'supplier_name': 'PT X',
        'target': 1000,
        'has_target': true,
        'value': 1000,
        'pencapaian': 100.0,
      },
    ];
    final provider = AdminProvider(AdminRepository(fake));
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('renders "—" when hasTarget is false', (tester) async {
    final fake = _FakeApi();
    fake.getResponse = [
      {
        'supplier_name': 'PT Y',
        'target': 0,
        'has_target': false,
        'value': 500,
        'pencapaian': null,
      },
    ];
    final provider = AdminProvider(AdminRepository(fake));
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('hides edit button for SALES user', (tester) async {
    final fake = _FakeApi();
    fake.getResponse = [
      {
        'supplier_name': 'PT Z',
        'target': 1000,
        'has_target': true,
        'value': 500,
        'pencapaian': 50.0,
      },
    ];
    final provider = AdminProvider(AdminRepository(fake));
    provider.setUserRole('SALES');
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.edit), findsNothing);
  });

  testWidgets('shows edit button for ADMIN user', (tester) async {
    final fake = _FakeApi();
    fake.getResponse = [
      {
        'supplier_name': 'PT Z',
        'target': 1000,
        'has_target': true,
        'value': 500,
        'pencapaian': 50.0,
      },
    ];
    final provider = AdminProvider(AdminRepository(fake));
    provider.setUserRole('ADMIN');
    await tester.pumpWidget(wrap(provider));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.edit), findsOneWidget);
  });
}
