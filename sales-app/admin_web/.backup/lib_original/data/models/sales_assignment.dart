import '../../core/datetime_utils.dart';

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
      salesId: json['sales_id'] ?? '',
      salesUsername: json['sales_username'] as String?,
      salesNama: json['sales_nama'] as String?,
      // Backend sudah kirim datetime dalam WITA (+08:00), langsung parse
      // Backend sudah kirim datetime dalam WITA (+08:00), langsung parse
      assignedAt: parseWitaIsoOrNull(json['assigned_at'] ?? '') ?? DateTime.now(),
    );
  }

  /// Tampilan human-readable — nama > username > '?'.
  String get displayLabel {
    if (salesNama != null && salesNama!.isNotEmpty) return salesNama!;
    if (salesUsername != null && salesUsername!.isNotEmpty) return salesUsername!;
    return '?';
  }
}
