class SyncResult {
  final String message;
  final int totalProducts;
  final int inserted;
  final int updated;
  final int skipped;
  final bool needsReview;

  SyncResult({
    required this.message,
    required this.totalProducts,
    required this.inserted,
    required this.updated,
    required this.skipped,
    required this.needsReview,
  });

  factory SyncResult.fromJson(Map<String, dynamic> json) {
    return SyncResult(
      message: json['message'] ?? json['detail'] ?? 'Sync completed',
      totalProducts: json['total_rows'] ?? json['total_products'] ?? json['total'] ?? 0,
      inserted: json['inserted'] ?? 0,
      updated: json['updated'] ?? 0,
      skipped: json['skipped'] ?? 0,
      needsReview: json['needs_review'] ?? false,
    );
  }
}

class SyncError {
  final String row;
  final String reason;

  SyncError({required this.row, required this.reason});

  factory SyncError.fromJson(Map<String, dynamic> json) {
    return SyncError(
      row: json['row']?.toString() ?? '',
      reason: json['reason'] ?? json['error'] ?? '',
    );
  }
}
