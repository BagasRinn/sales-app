import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/config.dart';
import 'api_service.dart';

class AuthRepository {
  final ApiService _api;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  AuthRepository(this._api);

  Future<Map<String, dynamic>> login(String username, String password) async {
    final data = await _api.post('/auth/login', body: {
      'username': username,
      'password': password,
    });

    final token = data['access_token'] as String;
    final refreshToken = data['refresh_token'] as String;
    _api.setAccessToken(token);

    await _storage.write(key: AppConfig.tokenKey, value: token);
    await _storage.write(key: AppConfig.refreshTokenKey, value: refreshToken);

    return data;
  }

  Future<void> logout() async {
    await _storage.delete(key: AppConfig.tokenKey);
    await _storage.delete(key: AppConfig.refreshTokenKey);
    await _storage.delete(key: AppConfig.userRoleKey);
    await _storage.delete(key: AppConfig.userIdKey);
    _api.clearAccessToken();
  }

  /// Synchronous logout — clears in-memory token only, no storage/API.
  void logoutSync() {
    _api.clearAccessToken();
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: AppConfig.tokenKey);
    if (token != null) {
      _api.setAccessToken(token);
      return true;
    }
    return false;
  }

  Future<String?> getToken() async {
    return _storage.read(key: AppConfig.tokenKey);
  }

  Future<String?> getRefreshToken() async {
    return _storage.read(key: AppConfig.refreshTokenKey);
  }

  Future<void> saveTokens(String accessToken, String refreshToken) async {
    _storage.write(key: AppConfig.tokenKey, value: accessToken);
    _storage.write(key: AppConfig.refreshTokenKey, value: refreshToken);
  }

  Future<Map<String, dynamic>?> refreshTokens(String refreshToken) async {
    final data = await _api.post('/auth/refresh', body: {
      'refresh_token': refreshToken,
    });
    final newAccessToken = data['access_token'] as String;
    final newRefreshToken = data['refresh_token'] as String?;
    _api.setAccessToken(newAccessToken);
    await _storage.write(key: AppConfig.tokenKey, value: newAccessToken);
    if (newRefreshToken != null) {
      await _storage.write(key: AppConfig.refreshTokenKey, value: newRefreshToken);
    }
    return data;
  }

  Future<Map<String, dynamic>?> register({
    required String username,
    required String password,
    required String role,
  }) async {
    final data = await _api.post('/auth/register', body: {
      'username': username,
      'password': password,
      'role': role,
    });
    return data;
  }
}
