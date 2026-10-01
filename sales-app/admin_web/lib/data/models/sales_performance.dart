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
