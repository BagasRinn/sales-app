import 'package:flutter_test/flutter_test.dart';
import 'package:admin_web/data/models/sales_performance.dart';
import 'package:admin_web/presentation/screens/stats_tab.dart';

void main() {
  group('aggregateDashboardPerformance', () {
    test('empty list → null', () {
      expect(aggregateDashboardPerformance(const []), isNull);
    });

    test('single item → returned as-is (with empty userId/username)', () {
      const item = SalesPerformanceDashboardItem(
        userId: 'u1',
        username: 'akbar',
        approvedMtdCount: 5,
        approvedMtdRevenue: 100000,
        pendingMtdCount: 2,
        pendingMtdRevenue: 50000,
        rejectedMtdCount: 1,
        rejectedMtdRevenue: 10000,
        approvedTodayCount: 1,
        approvedTodayRevenue: 20000,
        pendingTodayCount: 0,
        pendingTodayRevenue: 0,
        rejectedTodayCount: 0,
        rejectedTodayRevenue: 0,
      );
      final result = aggregateDashboardPerformance([item]);
      expect(result, isNotNull);
      expect(result!.approvedMtdCount, 5);
      expect(result.approvedMtdRevenue, 100000);
      expect(result.pendingMtdCount, 2);
      expect(result.rejectedMtdCount, 1);
      expect(result.approvedTodayCount, 1);
    });

    test('two items → counts and revenues summed field-by-field', () {
      const a = SalesPerformanceDashboardItem(
        userId: 'u1',
        username: 'akbar',
        approvedMtdCount: 5,
        approvedMtdRevenue: 100000,
        pendingMtdCount: 2,
        pendingMtdRevenue: 50000,
        rejectedMtdCount: 1,
        rejectedMtdRevenue: 10000,
        approvedTodayCount: 1,
        approvedTodayRevenue: 20000,
        pendingTodayCount: 1,
        pendingTodayRevenue: 30000,
        rejectedTodayCount: 0,
        rejectedTodayRevenue: 0,
      );
      const b = SalesPerformanceDashboardItem(
        userId: 'u2',
        username: 'nabil',
        approvedMtdCount: 3,
        approvedMtdRevenue: 70000,
        pendingMtdCount: 4,
        pendingMtdRevenue: 60000,
        rejectedMtdCount: 2,
        rejectedMtdRevenue: 15000,
        approvedTodayCount: 2,
        approvedTodayRevenue: 40000,
        pendingTodayCount: 1,
        pendingTodayRevenue: 10000,
        rejectedTodayCount: 1,
        rejectedTodayRevenue: 5000,
      );
      final result = aggregateDashboardPerformance([a, b]);
      expect(result, isNotNull);
      expect(result!.approvedMtdCount, 8);
      expect(result.approvedMtdRevenue, 170000);
      expect(result.pendingMtdCount, 6);
      expect(result.pendingMtdRevenue, 110000);
      expect(result.rejectedMtdCount, 3);
      expect(result.rejectedMtdRevenue, 25000);
      expect(result.approvedTodayCount, 3);
      expect(result.approvedTodayRevenue, 60000);
      expect(result.pendingTodayCount, 2);
      expect(result.pendingTodayRevenue, 40000);
      expect(result.rejectedTodayCount, 1);
      expect(result.rejectedTodayRevenue, 5000);
    });
  });
}
