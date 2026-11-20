import '../../core/datetime_utils.dart';

/// Satu baris absensi kunjungan outlet yang dikirim worker WhatsApp.
///
/// Nama sales memakai `sales_name` hasil resolve backend (nama user terdaftar,
/// fallback `pushName`). `is_registered_sales` menandai apakah nomor pengirim
/// cocok dengan user ber-role SALES.
class SalesAttendance {
  final String id;
  final String? salesId;
  final String? salesName;
  final String senderPhone;
  final String? senderPushName;
  final bool isRegisteredSales;
  final String outletCode;
  final String outletName;
  final String outletChannel;
  final bool hasPhotoProof;
  final String? waGroupId;
  final String? waMessageId;
  final DateTime visitedAt;
  final DateTime? createdAt;

  const SalesAttendance({
    required this.id,
    this.salesId,
    this.salesName,
    required this.senderPhone,
    this.senderPushName,
    required this.isRegisteredSales,
    required this.outletCode,
    required this.outletName,
    required this.outletChannel,
    this.hasPhotoProof = false,
    this.waGroupId,
    this.waMessageId,
    required this.visitedAt,
    this.createdAt,
  });

  factory SalesAttendance.fromJson(Map<String, dynamic> json) {
    return SalesAttendance(
      id: json['id'] as String,
      salesId: json['sales_id'] as String?,
      salesName: json['sales_name'] as String?,
      senderPhone: json['sender_phone'] as String? ?? '',
      senderPushName: json['sender_push_name'] as String?,
      isRegisteredSales: json['is_registered_sales'] as bool? ?? false,
      outletCode: json['outlet_code'] as String? ?? '',
      outletName: json['outlet_name'] as String? ?? '',
      outletChannel: json['outlet_channel'] as String? ?? '',
      hasPhotoProof: json['has_photo_proof'] as bool? ?? false,
      waGroupId: json['wa_group_id'] as String?,
      waMessageId: json['wa_message_id'] as String?,
      visitedAt: parseWitaIso(json['visited_at'] as String),
      createdAt: parseWitaIsoOrNull(json['created_at'] as String?),
    );
  }

  /// Nama untuk ditampilkan: nama sales terdaftar, lalu pushName WhatsApp.
  String get displayName {
    final name = salesName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final push = senderPushName?.trim();
    if (push != null && push.isNotEmpty) return push;
    return 'Tanpa nama';
  }

  /// Nomor pengirim dalam format lokal Indonesia (`08…`), fallback apa adanya.
  String get displayPhone {
    final phone = senderPhone.trim();
    if (phone.startsWith('62') && phone.length > 4) {
      return '0${phone.substring(2)}';
    }
    return phone;
  }
}
