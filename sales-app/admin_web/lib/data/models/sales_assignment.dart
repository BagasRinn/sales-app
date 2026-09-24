class SalesAssignment {
  final String salesId;
  final String? salesUsername;
  final String? salesNama;
  final DateTime assignedAt;

  SalesAssignment({
    required this.salesId,
    this.salesUsername,
    this.salesNama,
    required this.assignedAt,
  });

  factory SalesAssignment.fromJson(Map<String, dynamic> json) {
    return SalesAssignment(
      salesId: json['sales_id'] as String,
      salesUsername: json['sales_username'] as String?,
      salesNama: json['sales_nama'] as String?,
      assignedAt: DateTime.parse(json['assigned_at'] as String),
    );
  }

  String get displayName {
    if (salesNama != null && salesNama!.isNotEmpty) return salesNama!;
    if (salesUsername != null && salesUsername!.isNotEmpty) return salesUsername!;
    return '?';
  }
}