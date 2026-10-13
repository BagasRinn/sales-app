import 'package:flutter_test/flutter_test.dart';
import 'package:admin_web/data/repositories/admin_repository.dart';
import 'package:admin_web/data/repositories/api_service.dart';
import 'package:admin_web/data/models/supplier_performance.dart';
import 'package:admin_web/data/models/supplier_target.dart';
import 'package:dio/dio.dart';

/// Fake ApiService that records calls and returns canned responses. Avoids
/// real HTTP I/O. Subclassing ApiService inherits the real Dio setup
/// (base URL, interceptors) but we never make a request, so it doesn't
/// matter if those are unconfigured in the test env.
class _FakeApi extends ApiService {
  final List<String> getCalls = [];
  final List<({String path, Map<String, dynamic>? body})> putCalls = [];
  dynamic getResponse;
  dynamic putResponse;

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
    return putResponse;
  }
}

void main() {
  group('AdminRepository supplier methods', () {
    late _FakeApi fake;
    late AdminRepository repo;

    setUp(() {
      fake = _FakeApi();
      repo = AdminRepository(fake);
    });

    test('getSupplierPerformance hits the read endpoint with year_month', () async {
      fake.getResponse = [
        {
          'supplier_name': 'PT X',
          'target': 5000,
          'has_target': true,
          'value': 2500,
          'pencapaian': 50.0,
        },
      ];
      final rows = await repo.getSupplierPerformance(yearMonth: '2026-10');
      expect(fake.getCalls, hasLength(1));
      expect(fake.getCalls.single, '/reports/supplier-performance?year_month=2026-10');
      expect(rows, hasLength(1));
      expect(rows.first, isA<SupplierPerformanceRow>());
      expect(rows.first.supplierName, 'PT X');
      expect(rows.first.value, 2500);
      expect(rows.first.pencapaian, 50.0);
    });

    test('getSupplierPerformance omits query when yearMonth is null', () async {
      fake.getResponse = [];
      await repo.getSupplierPerformance();
      expect(fake.getCalls.single, '/reports/supplier-performance');
    });

    test('getSupplierTargets hits the list endpoint with period', () async {
      fake.getResponse = [
        {
          'id': 'u-1',
          'branch': 'A',
          'supplier_name': 'PT Y',
          'period': '2026-10',
          'target_value': 1000,
        },
      ];
      final targets = await repo.getSupplierTargets(period: '2026-10');
      expect(fake.getCalls.single, '/supplier-targets?period=2026-10');
      expect(targets, hasLength(1));
      expect(targets.first, isA<SupplierTarget>());
      expect(targets.first.supplierName, 'PT Y');
      expect(targets.first.targetValue, 1000);
    });

    test('updateSupplierTarget calls PUT with correct path and body', () async {
      fake.putResponse = {
        'id': 'u-1',
        'branch': 'BATULICIN',
        'supplier_name': 'PT Z',
        'period': '2026-10',
        'target_value': 8000,
      };
      final t = await repo.updateSupplierTarget(
        branch: 'BATULICIN',
        supplierName: 'PT Z',
        period: '2026-10',
        targetValue: 8000,
      );
      expect(fake.putCalls, hasLength(1));
      final call = fake.putCalls.single;
      expect(call.path, '/supplier-targets/BATULICIN/PT%20Z/2026-10');
      expect(call.body, {'target_value': 8000});
      expect(t.targetValue, 8000);
      expect(t.supplierName, 'PT Z');
    });
  });
}
