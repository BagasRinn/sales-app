import 'package:web/web.dart' as web;
import 'config.dart';

/// Web-safe token storage using sessionStorage.
/// SessionStorage automatically clears when the browser tab/window is closed.
/// This is more secure than localStorage for storing auth tokens.
class WebAuthStorage {
  /// Save access token (in-memory only — not persisted in storage).
  /// Access token is short-lived, so we keep it in memory.
  String? _accessToken;

  /// Get the current access token (from memory).
  String? get accessToken => _accessToken;

  /// Set access token (stored in memory only).
  void setAccessToken(String? token) {
    _accessToken = token;
  }

  /// Clear in-memory access token.
  void clearAccessToken() {
    _accessToken = null;
  }

  // ─── Session Storage (dies on tab close) ───────────────────────────────────

  /// Save access token to sessionStorage (for persistence across hot-restarts).
  Future<void> saveAccessToken(String token) async {
    web.window.sessionStorage.setItem(AppConfig.accessTokenKey, token);
  }

  /// Get access token from sessionStorage.
  String? getAccessToken() {
    return web.window.sessionStorage.getItem(AppConfig.accessTokenKey);
  }

  /// Save refresh token to sessionStorage.
  Future<void> saveRefreshToken(String token) async {
    web.window.sessionStorage.setItem(AppConfig.refreshTokenKey, token);
  }

  /// Get refresh token from sessionStorage.
  String? getRefreshToken() {
    return web.window.sessionStorage.getItem(AppConfig.refreshTokenKey);
  }

  /// Delete refresh token from sessionStorage.
  Future<void> deleteRefreshToken() async {
    web.window.sessionStorage.removeItem(AppConfig.refreshTokenKey);
  }

  /// Save user info to sessionStorage.
  Future<void> saveUserInfo({
    String? role,
    String? id,
    String? username,
    String? nama,
  }) async {
    if (role != null) web.window.sessionStorage.setItem(AppConfig.userRoleKey, role);
    if (id != null) web.window.sessionStorage.setItem(AppConfig.userIdKey, id);
    if (username != null) web.window.sessionStorage.setItem(AppConfig.userUsernameKey, username);
    if (nama != null) web.window.sessionStorage.setItem(AppConfig.userNamaKey, nama);
  }

  /// Get user role from sessionStorage.
  String? getUserRole() {
    return web.window.sessionStorage.getItem(AppConfig.userRoleKey);
  }

  /// Get user ID from sessionStorage.
  String? getUserId() {
    return web.window.sessionStorage.getItem(AppConfig.userIdKey);
  }

  /// Get username from sessionStorage.
  String? getUsername() {
    return web.window.sessionStorage.getItem(AppConfig.userUsernameKey);
  }

  /// Get user nama from sessionStorage.
  String? getNama() {
    return web.window.sessionStorage.getItem(AppConfig.userNamaKey);
  }

  /// Clear all auth data from sessionStorage.
  Future<void> clearAll() async {
    web.window.sessionStorage.removeItem(AppConfig.accessTokenKey);
    web.window.sessionStorage.removeItem(AppConfig.refreshTokenKey);
    web.window.sessionStorage.removeItem(AppConfig.userRoleKey);
    web.window.sessionStorage.removeItem(AppConfig.userIdKey);
    web.window.sessionStorage.removeItem(AppConfig.userUsernameKey);
    web.window.sessionStorage.removeItem(AppConfig.userNamaKey);
    _accessToken = null;
  }

  /// Check if user is logged in (has refresh token in sessionStorage).
  bool isLoggedIn() {
    return getRefreshToken() != null;
  }
}
