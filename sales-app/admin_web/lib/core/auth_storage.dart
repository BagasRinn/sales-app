import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const String _accessKey = 'admin_access_token';
  static const String _refreshKey = 'admin_refresh_token';
  static const String _usernameKey = 'admin_username';
  static const String _namaKey = 'admin_nama';
  static const String _roleKey = 'admin_role';
  static const String _branchKey = 'admin_branch';
  static const String _branchNamaKey = 'admin_branch_nama';

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required String username,
    String? nama,
    String? role,
    String? branch,
    String? branchNama,
  }) async {
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
    await _storage.write(key: _usernameKey, value: username);
    if (nama != null && nama.isNotEmpty) {
      await _storage.write(key: _namaKey, value: nama);
    }
    if (role != null && role.isNotEmpty) {
      await _storage.write(key: _roleKey, value: role);
    }
    if (branch != null && branch.isNotEmpty) {
      await _storage.write(key: _branchKey, value: branch);
    }
    if (branchNama != null && branchNama.isNotEmpty) {
      await _storage.write(key: _branchNamaKey, value: branchNama);
    }
  }

  Future<Map<String, String?>?> getTokens() async {
    final access = await _storage.read(key: _accessKey);
    if (access == null) return null;
    return {
      'access_token': access,
      'refresh_token': await _storage.read(key: _refreshKey),
      'username': await _storage.read(key: _usernameKey),
      'nama': await _storage.read(key: _namaKey),
      'role': await _storage.read(key: _roleKey),
      'branch': await _storage.read(key: _branchKey),
      'branch_nama': await _storage.read(key: _branchNamaKey),
    };
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _usernameKey);
    await _storage.delete(key: _namaKey);
    await _storage.delete(key: _roleKey);
    await _storage.delete(key: _branchKey);
    await _storage.delete(key: _branchNamaKey);
  }
}