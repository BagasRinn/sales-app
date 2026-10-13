import 'package:flutter_test/flutter_test.dart';
import 'package:admin_web/data/repositories/api_service.dart';
import 'package:admin_web/data/repositories/admin_repository.dart';
import 'package:admin_web/presentation/providers/admin_provider.dart';
import 'package:dio/dio.dart';

class _FakeApi extends ApiService {
  dynamic getResponse;
  Object? getError;
  final List<String> getCalls = [];

  @override
  Future<dynamic> get(String endpoint,
      {CancelToken? cancelToken, Duration? receiveTimeout}) async {
    getCalls.add(endpoint);
    if (getError != null) throw getError!;
    return getResponse;
  }
}

void main() {
  group('AdminProvider.loadSupplierPerformance', () {
    late _FakeApi fake;
    late AdminRepository repo;
    late AdminProvider provider;

    setUp(() {
      fake = _FakeApi();
      repo = AdminRepository(fake);
      provider = AdminProvider(repo);
    });

    test('sets loading true, then false; stores rows; notifies listeners',
        () async {
      fake.getResponse = [
        {
          'supplier_name': 'PT X',
          'target': 5000,
          'has_target': true,
          'value': 2500,
          'pencapaian': 50.0,
        },
      ];

      var notifications = 0;
      provider.addListener(() => notifications++);

      expect(provider.supplierPerformanceLoading, false);
      expect(provider.supplierPerformance, isEmpty);

      final future = provider.loadSupplierPerformance(yearMonth: '2026-10');
      // Loading flag flips true synchronously after the first notify.
      expect(provider.supplierPerformanceLoading, true);
      expect(provider.supplierPerformanceYearMonth, '2026-10');

      await future;

      expect(provider.supplierPerformanceLoading, false);
      expect(provider.supplierPerformance, hasLength(1));
      expect(provider.supplierPerformance.first.supplierName, 'PT X');
      expect(provider.supplierPerformance.first.value, 2500);
      // 2 notifications: loading=true, loading=false.
      expect(notifications, greaterThanOrEqualTo(2));
      expect(fake.getCalls.single,
          '/reports/supplier-performance?year_month=2026-10');
    });

    test('on error, captures message and stops loading', () async {
      fake.getError = Exception('network down');

      await provider.loadSupplierPerformance(yearMonth: '2026-10');

      expect(provider.supplierPerformanceLoading, false);
      expect(provider.supplierPerformance, isEmpty);
      expect(provider.errorMessage, contains('network down'));
    });
  });
}
