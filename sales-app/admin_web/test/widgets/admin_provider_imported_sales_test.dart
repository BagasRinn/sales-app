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
  Map<String, dynamic>? importResult;
  Exception? failImport;

  @override
  Future<Map<String, dynamic>> getImportedSalesVersion({
    required String month,
  }) async {
    versionCalls++;
    return {
      'month': month,
      'scope': scope,
      'version': version,
      'updated_at': null,
    };
  }

  @override
  Future<Map<String, dynamic>> getImportedSalesSummary({
    String? month,
    int limit = 10,
    String? include,
  }) async {
    summaryCalls++;
    return {
      'month': month,
      'scope': scope,
      'version': version,
      'limit': limit,
      'total_revenue': summaryCalls * 1000,
      'total_qty': summaryCalls,
      'imported_rows': summaryCalls,
      'by_product': <dynamic>[],
      'by_sales': <dynamic>[],
      'by_customer': <dynamic>[],
      'by_channel': <dynamic>[],
    };
  }

  @override
  Future<dynamic> importSalesExcel(List<int> fileBytes, String fileName) async {
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

  test('forceRefresh bypasses the version-match shortcut', () async {
    final repo = _FakeImportedSalesRepository();
    final p = _provider(repo);

    await p.loadImportedSalesSummary(month: '2026-01');
    expect(repo.summaryCalls, 1);

    await p.loadImportedSalesSummary(month: '2026-01', forceRefresh: true);
    expect(repo.summaryCalls, 2);
  });

  test('changing limit uses a separate cache key', () async {
    final repo = _FakeImportedSalesRepository();
    final p = _provider(repo);

    await p.loadImportedSalesSummary(month: '2026-01', limit: 10);
    expect(repo.summaryCalls, 1);

    await p.loadImportedSalesSummary(month: '2026-01', limit: 50);
    expect(repo.summaryCalls, 2);
    expect(p.importedSalesLimit, 50);
  });

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
}
