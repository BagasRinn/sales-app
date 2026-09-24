class UserItem {
  final String id;
  final String username;
  final String? nama;
  final String role;
  final bool isActive;

  UserItem({
    required this.id,
    required this.username,
    this.nama,
    required this.role,
    required this.isActive,
  });

  factory UserItem.fromJson(Map<String, dynamic> json) {
    return UserItem(
      id: json['id'] as String,
      username: json['username'] as String,
      nama: json['nama'] as String?,
      role: json['role'] as String,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  String get displayName =>
      (nama != null && nama!.isNotEmpty) ? nama! : username;
}