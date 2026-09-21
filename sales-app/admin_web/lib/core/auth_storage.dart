import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const String _accessKey = 'admin_access_token';
  static const String _refreshKey = 'admin_refresh_token';
  static const String _usernameKey = 'admin_username';

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required String username,
  }) async {
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
    await _storage.write(key: _usernameKey, value: username);
  }

  Future<Map<String, String?>?> getTokens() async {
    final access = await _storage.read(key: _accessKey);
    if (access == null) return null;
    return {
      'access_token': access,
      'refresh_token': await _storage.read(key: _refreshKey),
      'username': await _storage.read(key: _usernameKey),
    };
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _usernameKey);
  }
}
