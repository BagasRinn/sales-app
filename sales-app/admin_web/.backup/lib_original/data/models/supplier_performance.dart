class SupplierPerformanceRow {
  final String supplierName;
  final int target;
  final bool hasTarget;
  final int value;
  final double? pencapaian;

  /// Nama terdaftar di master `suppliers`. False = supplier lama yang hanya
  /// ada di `products` (belum di-import ke halaman Supplier).
  final bool isMaster;
  final bool isActive;
  final String orderType;

  const SupplierPerformanceRow({
    required this.supplierName,
    required this.target,
    required this.hasTarget,
    required this.value,
    required this.pencapaian,
    this.isMaster = true,
    this.isActive = true,
    this.orderType = 'REGULER',
  });

  factory SupplierPerformanceRow.fromJson(Map<String, dynamic> json) =>
      SupplierPerformanceRow(
        supplierName: json['supplier_name'] as String,
        target: (json['target'] as num).toInt(),
        hasTarget: json['has_target'] as bool,
        value: (json['value'] as num).toInt(),
        pencapaian: (json['pencapaian'] as num?)?.toDouble(),
        isMaster: json['is_master'] as bool? ?? true,
        isActive: json['is_active'] as bool? ?? true,
        orderType: json['order_type'] as String? ?? 'REGULER',
      );
}
