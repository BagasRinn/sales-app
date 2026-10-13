import 'package:flutter_test/flutter_test.dart';
import 'package:admin_web/data/models/sales_performance.dart';
import 'package:admin_web/presentation/screens/stats_tab.dart';

void main() {
  group('groupDashboardPerformanceByBranch', () {
    test('empty list → empty map', () {
      expect(groupDashboardPerformanceByBranch(const []), isEmpty);
    });

    test('items with null branch go to "" bucket', () {
      const a = SalesPerformanceDashboardItem(
        userId: 'u1',
        username: 'orphan',
        approvedMtdCount: 5,
      );
      const b = SalesPerformanceDashboardItem(
        userId: 'u2',
        username: 'orphan2',
        branch: 'BTL',
        approvedMtdCount: 3,
      );
      final result = groupDashboardPerformanceByBranch([a, b]);
      expect(result.keys, containsAll(['', 'BTL']));
      expect(result['']!.length, 1);
      expect(result['BTL']!.length, 1);
    });

    test('items with same branch are grouped together', () {
      const a = SalesPerformanceDashboardItem(
        userId: 'u1',
        username: 'akbar',
        branch: 'BTL',
        approvedMtdCount: 5,
      );
      const b = SalesPerformanceDashboardItem(
        userId: 'u2',
        username: 'nabil',
        branch: 'BTL',
        approvedMtdCount: 3,
      );
      const c = SalesPerformanceDashboardItem(
        userId: 'u3',
        username: 'haris',
        branch: 'BJM',
        approvedMtdCount: 7,
      );
      final result = groupDashboardPerformanceByBranch([a, b, c]);
      expect(result.keys.toSet(), {'BTL', 'BJM'});
      expect(result['BTL']!.length, 2);
      expect(result['BJM']!.length, 1);
    });

    test('branch order is stable (first-seen order preserved)', () {
      const a = SalesPerformanceDashboardItem(
        userId: 'u1',
        username: 'a',
        branch: 'BJM',
      );
      const b = SalesPerformanceDashboardItem(
        userId: 'u2',
        username: 'b',
        branch: 'BTL',
      );
      const c = SalesPerformanceDashboardItem(
        userId: 'u3',
        username: 'c',
        branch: 'BJM',
      );
      final result = groupDashboardPerformanceByBranch([a, b, c]);
      // BJM seen first → key order: BJM, BTL
      expect(result.keys.toList(), ['BJM', 'BTL']);
    });
  });
}
