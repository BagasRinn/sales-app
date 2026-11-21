class InventoryTrackerRow {
  // `name` = supplier atau nama produk, tergantung dimension response.
  final String name;
  final int stock;
  final List<int> previousSales;
  final int ap3m;
  final double averagePerWeek;
  final double? weekOfInventory;
  final int salesCurrentMonth;
  final String inventoryStatus;

  const InventoryTrackerRow({
    required this.name,
    required this.stock,
    required this.previousSales,
    required this.ap3m,
    required this.averagePerWeek,
    required this.weekOfInventory,
    required this.salesCurrentMonth,
    required this.inventoryStatus,
  });

  factory InventoryTrackerRow.fromJson(Map<String, dynamic> json) {
    return InventoryTrackerRow(
      name: (json['name'] ?? json['supplier_name'])?.toString() ?? '',
      stock: (json['stock'] as num?)?.toInt() ?? 0,
      previousSales: [
        (json['sales_month_1'] as num?)?.toInt() ?? 0,
        (json['sales_month_2'] as num?)?.toInt() ?? 0,
        (json['sales_month_3'] as num?)?.toInt() ?? 0,
      ],
      ap3m: (json['ap3m'] as num?)?.toInt() ?? 0,
      averagePerWeek: (json['average_per_week'] as num?)?.toDouble() ?? 0,
      weekOfInventory: (json['week_of_inventory'] as num?)?.toDouble(),
      salesCurrentMonth: (json['sales_current_month'] as num?)?.toInt() ?? 0,
      inventoryStatus:
          json['inventory_status']?.toString() ?? 'Tidak ada riwayat',
    );
  }
}

class InventoryTrackerResponse {
  final String month;
  final List<String> previousMonths;
  final String scope;
  final String? division;
  final List<String> divisions;
  final bool stockSnapshotAvailable;
  final bool salesHistoryAvailable;
  final int totalStock;
  final int totalAp3m;
  final double totalAveragePerWeek;
  final int totalSalesCurrentMonth;
  final int supplierCount;
  final int overstockCount;
  final List<InventoryTrackerRow> rows;

  const InventoryTrackerResponse({
    required this.month,
    required this.previousMonths,
    required this.scope,
    required this.division,
    required this.divisions,
    required this.stockSnapshotAvailable,
    required this.salesHistoryAvailable,
    required this.totalStock,
    required this.totalAp3m,
    required this.totalAveragePerWeek,
    required this.totalSalesCurrentMonth,
    required this.supplierCount,
    required this.overstockCount,
    required this.rows,
  });

  factory InventoryTrackerResponse.fromJson(Map<String, dynamic> json) {
    return InventoryTrackerResponse(
      month: json['month']?.toString() ?? '',
      previousMonths: (json['previous_months'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      scope: json['scope']?.toString() ?? '',
      division: json['division']?.toString(),
      divisions: (json['divisions'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      stockSnapshotAvailable: json['stock_snapshot_available'] == true,
      salesHistoryAvailable: json['sales_history_available'] == true,
      totalStock: (json['total_stock'] as num?)?.toInt() ?? 0,
      totalAp3m: (json['total_ap3m'] as num?)?.toInt() ?? 0,
      totalAveragePerWeek:
          (json['total_average_per_week'] as num?)?.toDouble() ?? 0,
      totalSalesCurrentMonth:
          (json['total_sales_current_month'] as num?)?.toInt() ?? 0,
      supplierCount: (json['supplier_count'] as num?)?.toInt() ?? 0,
      overstockCount: (json['overstock_count'] as num?)?.toInt() ?? 0,
      rows: (json['rows'] as List? ?? [])
          .map((e) => InventoryTrackerRow.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
