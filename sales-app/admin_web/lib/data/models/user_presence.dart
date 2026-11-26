// Model halaman Status Online (khusus MANAGER global).
//
// `isOnline` dihitung server (threshold 5 menit, lihat backend
// app/core/presence.py); `lastSeenAt` null berarti user belum pernah
// terlihat online sejak fitur aktif.
import '../../core/datetime_utils.dart';

class UserPresenceItem {
  final String userId;
  final String username;
  final String? nama;
  final String role;
  final String? branch;
  final String? branchNama;
  final bool isOnline;
  final DateTime? lastSeenAt;

  UserPresenceItem({
    required this.userId,
    required this.username,
    this.nama,
    required this.role,
    this.branch,
    this.branchNama,
    required this.isOnline,
    this.lastSeenAt,
  });

  factory UserPresenceItem.fromJson(Map<String, dynamic> json) {
    return UserPresenceItem(
      userId: json['user_id'] as String,
      username: json['username'] as String,
      nama: json['nama'] as String?,
      role: json['role'] as String,
      branch: json['branch'] as String?,
      branchNama: json['branch_nama'] as String?,
      isOnline: json['is_online'] as bool? ?? false,
      lastSeenAt: parseWitaIsoOrNull(json['last_seen_at'] as String?),
    );
  }

  String get displayName =>
      (nama != null && nama!.isNotEmpty) ? nama! : username;
}

class UserPresenceResponse {
  final int onlineCount;
  final int offlineCount;
  final int totalUsers;
  final DateTime? serverTime;
  final List<UserPresenceItem> users;

  UserPresenceResponse({
    required this.onlineCount,
    required this.offlineCount,
    required this.totalUsers,
    this.serverTime,
    required this.users,
  });

  factory UserPresenceResponse.fromJson(Map<String, dynamic> json) {
    return UserPresenceResponse(
      onlineCount: (json['online_count'] as num?)?.toInt() ?? 0,
      offlineCount: (json['offline_count'] as num?)?.toInt() ?? 0,
      totalUsers: (json['total_users'] as num?)?.toInt() ?? 0,
      serverTime: parseWitaIsoOrNull(json['server_time'] as String?),
      users: (json['users'] as List? ?? [])
          .map((e) => UserPresenceItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
