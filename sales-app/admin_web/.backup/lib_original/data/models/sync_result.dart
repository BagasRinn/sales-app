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
  final String? sku;
  final String reason;
  final String? importType;
  final String? fileName;
  final String? timestamp;

  SyncError({
    required this.row,
    required this.reason,
    this.sku,
    this.importType,
    this.fileName,
    this.timestamp,
  });

  factory SyncError.fromJson(Map<String, dynamic> json) {
    return SyncError(
      row: json['row']?.toString() ?? '',
      sku: json['sku']?.toString(),
      reason: json['reason'] ?? json['error'] ?? '',
      importType: json['import_type']?.toString(),
      fileName: json['file_name']?.toString(),
      timestamp: json['timestamp']?.toString(),
    );
  }

  bool get isStoreImport => importType == 'CUSTOMER';
}
