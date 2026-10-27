import '../../core/datetime_utils.dart';

class Bulletin {
  final String id;
  final String title;
  final String? description;
  final String? pdfUrl;
  final DateTime? expireAt;
  final DateTime createdAt;
  final bool isRead;
  final String? branch;
  final String? branchNama;

  Bulletin({
    required this.id,
    required this.title,
    this.description,
    this.pdfUrl,
    this.expireAt,
    required this.createdAt,
    this.isRead = false,
    this.branch,
    this.branchNama,
  });

  factory Bulletin.fromJson(Map<String, dynamic> json) {
    return Bulletin(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      pdfUrl: json['pdf_url'] as String?,
      // Backend sudah kirim datetime dalam WITA (+08:00), langsung parse
      expireAt: parseWitaIsoOrNull(json['expire_at'] as String?),
      createdAt: parseWitaIso(json['created_at'] as String),
      isRead: json['is_read'] as bool? ?? false,
      branch: json['branch'] as String?,
      branchNama: json['branch_nama'] as String?,
    );
  }
}
