import '../../core/api_service.dart';
import '../../core/api_exception.dart';
import '../../core/web_auth_storage.dart';

class AuthRepository {
  final ApiService _api;
  final WebAuthStorage _storage;

  AuthRepository(this._api, this._storage);

  Future<Map<String, dynamic>> login(String username, String password) async {
    final data = await _api.post('/auth/login', body: {
      'username': username,
      'password': password,
    });

    final role = data['role']?.toString();

    // Hanya SALES yang boleh login
    if (role != 'SALES') {
      throw ApiException(statusCode: 403, message: 'Aplikasi ini hanya untuk akun sales.');
    }

    final token = data['access_token'] as String;
    final refreshToken = data['refresh_token'] as String;

    // Access token di memory
    _api.setAccessToken(token);
    _storage.setAccessToken(token);
    // Simpan juga ke sessionStorage (bertahan saat hot-restart)
    await _storage.saveAccessToken(token);

    // Refresh token di sessionStorage (die on tab close)
    await _storage.saveRefreshToken(refreshToken);
    await _storage.saveUserInfo(
      role: role,
      id: data['id']?.toString(),
      username: data['username']?.toString(),
      nama: data['nama']?.toString(),
    );

    return data;
  }

  Future<void> logout() async {
    await _storage.clearAll();
    _api.clearAccessToken();
  }

  void logoutSync() {
    _api.clearAccessToken();
    _storage.setAccessToken(null);
  }

  /// Try to rehydrate session from stored refresh token.
  /// Returns true if successful.
  Future<bool> tryRestoreSession() async {
    final refreshToken = _storage.getRefreshToken();
    if (refreshToken == null) return false;

    // Restore access token from sessionStorage (survives hot-restart)
    final storedAccessToken = _storage.getAccessToken();
    if (storedAccessToken != null) {
      _api.setAccessToken(storedAccessToken);
      _storage.setAccessToken(storedAccessToken);
    }

    try {
      // Try to refresh tokens
      final data = await refreshTokens(refreshToken);
      return data != null;
    } catch (_) {
      // Refresh failed — clear everything
      await _storage.clearAll();
      _api.clearAccessToken();
      return false;
    }
  }

  Future<Map<String, dynamic>?> refreshTokens(String refreshToken) async {
    final data = await _api.post('/auth/refresh', body: {
      'refresh_token': refreshToken,
    });

    final newAccessToken = data['access_token'] as String;
    final newRefreshToken = data['refresh_token'] as String?;

    _api.setAccessToken(newAccessToken);
    _storage.setAccessToken(newAccessToken);
    await _storage.saveAccessToken(newAccessToken);
    await _storage.saveRefreshToken(newRefreshToken ?? refreshToken);

    return data;
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    await _api.post('/auth/change-password', body: {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
  }

  String? get accessToken => _storage.accessToken;
  String? get refreshToken => _storage.getRefreshToken();
  String? get username => _storage.getUsername();
  String? get nama => _storage.getNama();
  String? get userId => _storage.getUserId();
  bool get isLoggedIn => _storage.isLoggedIn();
}
