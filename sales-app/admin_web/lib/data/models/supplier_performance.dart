class SupplierPerformanceRow {
  final String supplierName;
  final int target;
  final bool hasTarget;
  final int value;
  final double? pencapaian;

  const SupplierPerformanceRow({
    required this.supplierName,
    required this.target,
    required this.hasTarget,
    required this.value,
    required this.pencapaian,
  });

  factory SupplierPerformanceRow.fromJson(Map<String, dynamic> json) =>
      SupplierPerformanceRow(
        supplierName: json['supplier_name'] as String,
        target: (json['target'] as num).toInt(),
        hasTarget: json['has_target'] as bool,
        value: (json['value'] as num).toInt(),
        pencapaian: (json['pencapaian'] as num?)?.toDouble(),
      );
}
