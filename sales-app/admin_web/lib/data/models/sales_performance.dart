class SalesPerformance {
  final String userId;
  final String username;
  final String? nama;
  final int orderCount;
  final int revenue;
  final int submissionCount;

  SalesPerformance({
    required this.userId,
    required this.username,
    this.nama,
    required this.orderCount,
    required this.revenue,
    required this.submissionCount,
  });

  factory SalesPerformance.fromJson(Map<String, dynamic> json) {
    return SalesPerformance(
      userId: json['user_id'] as String,
      username: json['username'] as String,
      nama: json['nama'] as String?,
      orderCount: json['order_count'] as int? ?? 0,
      revenue: json['revenue'] as int? ?? 0,
      submissionCount: json['submission_count'] as int? ?? 0,
    );
  }

  String get displayName =>
      (nama != null && nama!.isNotEmpty) ? nama! : username;
}

/// Per-sales breakdown for manager dashboard — includes MTD + Today
/// for APPROVED, PENDING, and REJECTED orders.
class SalesPerformanceDashboardItem {
  final String userId;
  final String username;
  final String? nama;
  // APPROVED
  final int approvedMtdCount;
  final int approvedMtdRevenue;
  final int approvedTodayCount;
  final int approvedTodayRevenue;
  // PENDING
  final int pendingMtdCount;
  final int pendingMtdRevenue;
  final int pendingTodayCount;
  final int pendingTodayRevenue;
  // REJECTED
  final int rejectedMtdCount;
  final int rejectedMtdRevenue;
  final int rejectedTodayCount;
  final int rejectedTodayRevenue;

  const SalesPerformanceDashboardItem({
    required this.userId,
    required this.username,
    this.nama,
    this.approvedMtdCount = 0,
    this.approvedMtdRevenue = 0,
    this.approvedTodayCount = 0,
    this.approvedTodayRevenue = 0,
    this.pendingMtdCount = 0,
    this.pendingMtdRevenue = 0,
    this.pendingTodayCount = 0,
    this.pendingTodayRevenue = 0,
    this.rejectedMtdCount = 0,
    this.rejectedMtdRevenue = 0,
    this.rejectedTodayCount = 0,
    this.rejectedTodayRevenue = 0,
  });

  factory SalesPerformanceDashboardItem.fromJson(Map<String, dynamic> json) {
    return SalesPerformanceDashboardItem(
      userId: json['user_id'] ?? '',
      username: json['username'] ?? '',
      nama: json['nama'],
      approvedMtdCount: json['approved_mtd_count'] ?? 0,
      approvedMtdRevenue: json['approved_mtd_revenue'] ?? 0,
      approvedTodayCount: json['approved_today_count'] ?? 0,
      approvedTodayRevenue: json['approved_today_revenue'] ?? 0,
      pendingMtdCount: json['pending_mtd_count'] ?? 0,
      pendingMtdRevenue: json['pending_mtd_revenue'] ?? 0,
      pendingTodayCount: json['pending_today_count'] ?? 0,
      pendingTodayRevenue: json['pending_today_revenue'] ?? 0,
      rejectedMtdCount: json['rejected_mtd_count'] ?? 0,
      rejectedMtdRevenue: json['rejected_mtd_revenue'] ?? 0,
      rejectedTodayCount: json['rejected_today_count'] ?? 0,
      rejectedTodayRevenue: json['rejected_today_revenue'] ?? 0,
    );
  }

  String get displayName =>
      (nama != null && nama!.isNotEmpty) ? nama! : username;
}
