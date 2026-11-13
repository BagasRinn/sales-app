import 'package:flutter_test/flutter_test.dart';
import 'package:admin_web/data/repositories/api_service.dart';
import 'package:admin_web/data/repositories/admin_repository.dart';
import 'package:admin_web/presentation/providers/admin_provider.dart';

class _FakeImportedSalesRepository extends AdminRepository {
  _FakeImportedSalesRepository() : super(ApiService());

  int versionCalls = 0;
  int summaryCalls = 0;
  int version = 1;
  String scope = 'BANJARMASIN';
  String? lastBranch;
  int? lastRangeMonths;
  String? lastInclude;
  String? targetUpdatedAt;
  Map<String, dynamic>? importResult;
  Map<String, dynamic>? returnImportResult;
  Map<String, dynamic>? targetImportResult;
  Exception? failImport;

  @override
  Future<Map<String, dynamic>> getImportedSalesVersion({
    required String month,
    int rangeMonths = 1,
    String? branch,
  }) async {
    versionCalls++;
    lastBranch = branch;
    lastRangeMonths = rangeMonths;
    return {
      'month': month,
      'range_months': rangeMonths,
      'scope': branch ?? scope,
      'version': version,
      'updated_at': null,
      'target_updated_at': targetUpdatedAt,
    };
  }

  @override
  Future<Map<String, dynamic>> getImportedSalesSummary({
    String? month,
    int rangeMonths = 1,
    int limit = 10,
    String? include,
    String? branch,
  }) async {
    summaryCalls++;
    lastBranch = branch;
    lastRangeMonths = rangeMonths;
    lastInclude = include;
    return {
      'month': month,
      'range_months': rangeMonths,
      'scope': branch ?? scope,
      'version': version,
      'limit': limit,
      'total_revenue': summaryCalls * 1000,
      'total_qty': summaryCalls,
      'imported_rows': summaryCalls,
      'by_product': <dynamic>[],
      'by_sales': <dynamic>[],
      'by_customer': <dynamic>[],
      'by_channel': <dynamic>[],
      'by_divisi': <dynamic>[],
      'by_supplier': <dynamic>[],
      'by_supplier_retur': <dynamic>[],
      'target_updated_at': targetUpdatedAt,
    };
  }

  @override
  Future<dynamic> importSalesExcel(
    List<int> fileBytes,
    String fileName, {
    String? jobId,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    if (failImport != null) throw failImport!;
    return importResult ??
        {
          'success': true,
          'total_rows': 1,
          'inserted': 1,
          'updated': 0,
          'skipped': 0,
          'errors': <dynamic>[],
          'versions': <dynamic>[],
        };
  }

  @override
  Future<Map<String, dynamic>> importSalesReturnsExcel(
    List<int> fileBytes,
    String fileName, {
    String? jobId,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    return returnImportResult ??
        {
          'success': true,
          'total_rows': 1,
          'inserted': 1,
          'updated': 0,
          'skipped': 0,
          'errors': <dynamic>[],
          'versions': <dynamic>[],
          'unmatched_suppliers': <dynamic>[],
        };
  }

  @override
  Future<Map<String, dynamic>> importSalesTargetsExcel(
    List<int> fileBytes,
    String fileName, {
    String? jobId,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    return targetImportResult ??
        {
          'success': true,
          'total_rows': 1,
          'inserted': 1,
          'updated': 0,
          'skipped': 0,
          'errors': <dynamic>[],
          'sheets': <dynamic>[],
        };
  }
}

AdminProvider _provider(_FakeImportedSalesRepository repo) {
  return AdminProvider(repo)
    ..setUserRole('SUPERVISOR')
    ..setUserBranch('BANJARMASIN');
}

void main() {
  test('summary is only fetched when the version changes', () async {
    final repo = _FakeImportedSalesRepository();
    final p = _provider(repo);

    await p.loadImportedSalesSummary(month: '2026-01');
    expect(repo.versionCalls, 1);
    expect(repo.summaryCalls, 1);
    expect(p.importedSalesVersion, 1);

    // Same version -> only the tiny probe runs.
    await p.loadImportedSalesSummary(month: '2026-01');
    expect(repo.versionCalls, 2);
    expect(repo.summaryCalls, 1);

    // Version changed -> summary re-downloaded.
    repo.version = 2;
    await p.loadImportedSalesSummary(month: '2026-01');
    expect(repo.summaryCalls, 2);
    expect(p.importedSalesVersion, 2);
  });

  test(
    'summary requests supplier data for the Supplier Teratas card',
    () async {
      final repo = _FakeImportedSalesRepository();
      final p = _provider(repo);

      await p.loadImportedSalesSummary(month: '2026-01');

      expect(repo.lastInclude?.split(','), contains('supplier'));
      expect(repo.lastInclude?.split(','), contains('supplier_retur'));
      expect(p.importedSalesSummary?['by_supplier'], isA<List<dynamic>>());
      expect(
        p.importedSalesSummary?['by_supplier_retur'],
        isA<List<dynamic>>(),
      );
    },
  );

  test('return import invalidates the imported-sales summary cache', () async {
    final repo = _FakeImportedSalesRepository();
    final p = _provider(repo);

    await p.loadImportedSalesSummary(month: '2026-01');
    expect(repo.summaryCalls, 1);

    repo.returnImportResult = {
      'success': true,
      'total_rows': 1,
      'inserted': 1,
      'updated': 0,
      'skipped': 0,
      'errors': <dynamic>[],
      'versions': [
        {
          'month': '2026-01',
          'scope': 'BANJARMASIN',
          'version': 2,
          'updated_at': null,
        },
      ],
      'unmatched_suppliers': <dynamic>[],
    };

    expect(await p.importSalesReturnsExcel([1, 2, 3], 'returns.xlsx'), isTrue);
    expect(p.salesReturnImportResult?['success'], isTrue);

    await p.loadImportedSalesSummary(month: '2026-01');
    expect(repo.summaryCalls, 2);
  });

  test('forceRefresh bypasses the version-match shortcut', () async {
    final repo = _FakeImportedSalesRepository();
    final p = _provider(repo);

    await p.loadImportedSalesSummary(month: '2026-01');
    expect(repo.summaryCalls, 1);

    await p.loadImportedSalesSummary(month: '2026-01', forceRefresh: true);
    expect(repo.summaryCalls, 2);
  });

  test(
    'target timestamp change refreshes summary without sales version bump',
    () async {
      final repo = _FakeImportedSalesRepository();
      final p = _provider(repo);

      await p.loadImportedSalesSummary(month: '2026-01');
      expect(repo.summaryCalls, 1);

      repo.targetUpdatedAt = '2026-01-15T10:00:00Z';
      await p.loadImportedSalesSummary(month: '2026-01');

      expect(repo.summaryCalls, 2);
      expect(repo.version, 1);
    },
  );

  test('changing limit uses a separate cache key', () async {
    final repo = _FakeImportedSalesRepository();
    final p = _provider(repo);

    await p.loadImportedSalesSummary(month: '2026-01', limit: 10);
    expect(repo.summaryCalls, 1);

    await p.loadImportedSalesSummary(month: '2026-01', limit: 50);
    expect(repo.summaryCalls, 2);
    expect(p.importedSalesLimit, 50);
  });

  test(
    'range months is sent to version and summary and cached separately',
    () async {
      final repo = _FakeImportedSalesRepository();
      final p = _provider(repo);

      await p.loadImportedSalesSummary(month: '2026-01');
      await p.loadImportedSalesSummary(month: '2026-01', rangeMonths: 3);

      expect(repo.summaryCalls, 2);
      expect(repo.lastRangeMonths, 3);
      expect(p.importedSalesRangeMonths, 3);
    },
  );

  test('successful import invalidates the summary cache', () async {
    final repo = _FakeImportedSalesRepository();
    final p = _provider(repo);

    await p.loadImportedSalesSummary(month: '2026-01');
    expect(repo.summaryCalls, 1);

    repo.importResult = {
      'success': true,
      'total_rows': 1,
      'inserted': 1,
      'updated': 0,
      'skipped': 0,
      'errors': <dynamic>[],
      'versions': [
        {
          'month': '2026-01',
          'scope': 'BANJARMASIN',
          'version': 2,
          'updated_at': null,
        },
      ],
    };
    repo.version = 2;

    final ok = await p.importSalesExcel([1, 2, 3], 'sales.xlsx');
    expect(ok, isTrue);
    expect(p.salesImportResult?['success'], isTrue);

    // Cache cleared: same version but no cached payload -> fetch again.
    await p.loadImportedSalesSummary(month: '2026-01');
    expect(repo.summaryCalls, 2);
  });

  test('changed target import invalidates the summary cache', () async {
    final repo = _FakeImportedSalesRepository();
    final p = _provider(repo);

    await p.loadImportedSalesSummary(month: '2026-01');
    expect(repo.summaryCalls, 1);
    repo.targetImportResult = {
      'success': true,
      'total_rows': 1,
      'inserted': 1,
      'updated': 0,
      'skipped': 0,
      'errors': <dynamic>[],
      'sheets': <dynamic>[],
    };

    expect(await p.importSalesTargetsExcel([1, 2, 3], 'targets.xlsx'), isTrue);
    expect(p.salesTargetImportResult?['success'], isTrue);

    await p.loadImportedSalesSummary(month: '2026-01');
    expect(repo.summaryCalls, 2);
  });

  test('unchanged re-import keeps the summary cache', () async {
    final repo = _FakeImportedSalesRepository();
    final p = _provider(repo);

    await p.loadImportedSalesSummary(month: '2026-01');
    expect(repo.summaryCalls, 1);

    // All rows matched unchanged: no version bump, so the cached snapshot
    // stays valid and the next load only runs the tiny version probe.
    repo.importResult = {
      'success': true,
      'total_rows': 1,
      'inserted': 0,
      'updated': 1,
      'skipped': 0,
      'errors': <dynamic>[],
      'versions': <dynamic>[],
    };

    final ok = await p.importSalesExcel([1, 2, 3], 'sales.xlsx');
    expect(ok, isTrue);

    await p.loadImportedSalesSummary(month: '2026-01');
    expect(repo.versionCalls, 2);
    expect(repo.summaryCalls, 1);
  });

  test('backend success:false returns false and surfaces the reason', () async {
    final repo = _FakeImportedSalesRepository();
    repo.importResult = {
      'success': false,
      'total_rows': 1,
      'inserted': 0,
      'updated': 0,
      'skipped': 1,
      'errors': [
        {
          'row': 2,
          'sku': 'P001',
          'reason': 'Tanggal penjualan tidak valid atau kosong',
        },
      ],
      'versions': <dynamic>[],
    };
    final p = _provider(repo);

    final ok = await p.importSalesExcel([1, 2, 3], 'sales.xlsx');
    expect(ok, isFalse);
    expect(p.errorMessage, contains('Tanggal penjualan'));
  });

  test('switching branch clears cached summary for the old scope', () async {
    final repo = _FakeImportedSalesRepository();
    final p = _provider(repo);

    await p.loadImportedSalesSummary(month: '2026-01');
    expect(repo.summaryCalls, 1);
    expect(p.importedSalesScope, 'BANJARMASIN');

    p.setUserBranch('BARABAI');
    repo.scope = 'BARABAI';
    expect(p.importedSalesSummary, isNull);

    await p.loadImportedSalesSummary(month: '2026-01');
    expect(repo.summaryCalls, 2);
    expect(p.importedSalesScope, 'BARABAI');
  });

  test('global manager branch filter requests and caches per scope', () async {
    final repo = _FakeImportedSalesRepository()..scope = 'GLOBAL';
    final p = AdminProvider(repo)
      ..setUserRole('MANAGER')
      ..setUserBranch(null);
    expect(p.isGlobalManager, isTrue);

    await p.loadImportedSalesSummary(month: '2026-01');
    expect(repo.lastBranch, isNull);
    expect(repo.summaryCalls, 1);
    expect(p.importedSalesScope, 'GLOBAL');

    // Selecting a branch clears the previous payload immediately and scopes
    // both the version probe and the summary request.
    p.setImportedSalesBranchFilter('banjarmasin');
    expect(p.importedSalesBranchFilter, 'BANJARMASIN');
    expect(p.importedSalesSummary, isNull);

    await p.loadImportedSalesSummary(month: '2026-01');
    expect(repo.lastBranch, 'BANJARMASIN');
    expect(repo.summaryCalls, 2);
    expect(p.importedSalesScope, 'BANJARMASIN');

    // Same branch + same version -> probe only.
    await p.loadImportedSalesSummary(month: '2026-01');
    expect(repo.summaryCalls, 2);

    // Back to all branches reuses the cached GLOBAL payload.
    p.setImportedSalesBranchFilter(null);
    await p.loadImportedSalesSummary(month: '2026-01');
    expect(repo.lastBranch, isNull);
    expect(repo.summaryCalls, 2);
    expect(p.importedSalesScope, 'GLOBAL');
  });
}
