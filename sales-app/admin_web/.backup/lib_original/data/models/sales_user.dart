class SalesUser {
  final String id;
  final String username;
  final String? nama;
  final String role;

  SalesUser({
    required this.id,
    required this.username,
    this.nama,
    required this.role,
  });

  factory SalesUser.fromJson(Map<String, dynamic> json) {
    return SalesUser(
      id: json['id'] as String,
      username: json['username'] as String,
      nama: json['nama'] as String?,
      role: json['role'] as String,
    );
  }

  /// Nama display: pakai `nama` kalau ada, fallback ke `username`.
  String get displayName =>
      (nama != null && nama!.isNotEmpty) ? nama! : username;
}