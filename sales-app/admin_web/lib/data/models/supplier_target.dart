class SupplierTarget {
  final String id;
  final String branch;
  final String supplierName;
  final String period;
  final int targetValue;

  const SupplierTarget({
    required this.id,
    required this.branch,
    required this.supplierName,
    required this.period,
    required this.targetValue,
  });

  factory SupplierTarget.fromJson(Map<String, dynamic> json) => SupplierTarget(
        id: json['id'] as String,
        branch: json['branch'] as String,
        supplierName: json['supplier_name'] as String,
        period: json['period'] as String,
        targetValue: (json['target_value'] as num).toInt(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'branch': branch,
        'supplier_name': supplierName,
        'period': period,
        'target_value': targetValue,
      };
}
