/// Branch-level summaries returned by /reports/cross-branch/* endpoints.
/// Only accessible to global MANAGER role.
class BranchSalesSummary {
  final String branch;
  final String branchNama;
  final int approvedCount;
  final int approvedRevenue;
  final int pendingCount;
  final int customerCount;
  final int salesCount;

  const BranchSalesSummary({
    required this.branch,
    required this.branchNama,
    required this.approvedCount,
    required this.approvedRevenue,
    required this.pendingCount,
    required this.customerCount,
    required this.salesCount,
  });

  factory BranchSalesSummary.fromJson(Map<String, dynamic> json) {
    return BranchSalesSummary(
      branch: json['branch'] ?? '',
      branchNama: json['branch_nama'] ?? '',
      approvedCount: json['approved_count'] ?? 0,
      approvedRevenue: json['approved_revenue'] ?? 0,
      pendingCount: json['pending_count'] ?? 0,
      customerCount: json['customer_count'] ?? 0,
      salesCount: json['sales_count'] ?? 0,
    );
  }
}

class BranchStockSummary {
  final String branch;
  final String branchNama;
  final int skuCount;
  final int totalStockValue;
  final int lowStockCount;

  const BranchStockSummary({
    required this.branch,
    required this.branchNama,
    required this.skuCount,
    required this.totalStockValue,
    required this.lowStockCount,
  });

  factory BranchStockSummary.fromJson(Map<String, dynamic> json) {
    return BranchStockSummary(
      branch: json['branch'] ?? '',
      branchNama: json['branch_nama'] ?? '',
      skuCount: json['sku_count'] ?? 0,
      totalStockValue: json['total_stock_value'] ?? 0,
      lowStockCount: json['low_stock_count'] ?? 0,
    );
  }
}
