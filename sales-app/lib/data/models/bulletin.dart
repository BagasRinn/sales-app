import '../../core/datetime_utils.dart';

class Bulletin {
  final String id;
  final String title;
  final String? description;
  final String? pdfUrl;
  final DateTime? expireAt;
  final DateTime createdAt;
  final bool isRead;

  Bulletin({
    required this.id,
    required this.title,
    this.description,
    this.pdfUrl,
    this.expireAt,
    required this.createdAt,
    this.isRead = false,
  });

  factory Bulletin.fromJson(Map<String, dynamic> json) {
    return Bulletin(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      pdfUrl: json['pdf_url'] as String?,
      expireAt: json['expire_at'] != null
          ? DateTime.parse(json['expire_at'] as String).toWita()
          : null,
      createdAt: DateTime.parse(json['created_at'] as String).toWita(),
      isRead: json['is_read'] as bool? ?? false,
    );
  }
}
