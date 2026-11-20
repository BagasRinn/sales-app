import '../../core/datetime_utils.dart';

/// Status sesi WhatsApp worker Baileys (dipakai halaman pairing QR di admin web).
///
/// Data berasal dari control server worker lewat endpoint backend
/// `GET /api/v1/wa/session`, yang difetch hanya oleh MANAGER global.
class WaSessionStatus {
  final String status; // starting | waiting_qr | connected | disconnected | logged_out | logging_out
  final bool connected;
  final String? qr; // data URI QR code, hanya ada saat waiting_qr
  final String? phone; // nomor terhubung (format internasional, mis. 62812…)
  final String? name; // nama profil WhatsApp
  final DateTime? updatedAt;
  final String? message;

  const WaSessionStatus({
    required this.status,
    required this.connected,
    this.qr,
    this.phone,
    this.name,
    this.updatedAt,
    this.message,
  });

  factory WaSessionStatus.fromJson(Map<String, dynamic> json) {
    return WaSessionStatus(
      status: json['status'] as String? ?? 'unknown',
      connected: json['connected'] as bool? ?? false,
      qr: json['qr'] as String?,
      phone: json['phone'] as String?,
      name: json['name'] as String?,
      updatedAt: parseWitaIsoOrNull(json['updated_at'] as String?),
      message: json['message'] as String?,
    );
  }

  /// Nomor dalam format lokal Indonesia (`08…`), fallback apa adanya.
  String get displayPhone {
    final p = (phone ?? '').trim();
    if (p.startsWith('62') && p.length > 4) {
      return '0${p.substring(2)}';
    }
    return p.isEmpty ? '-' : p;
  }

  bool get isWaitingQr => status == 'waiting_qr' && qr != null;
  bool get isConnected => connected && status == 'connected';
  bool get isLoggedOut => status == 'logged_out';
}
