import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AuthStorage {
  static const String _key = 'admin_auth';

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required String username,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode({
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'username': username,
    }));
  }

  Future<Map<String, String?>?> getTokens() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_key);
    if (data == null) return null;
    try {
      final map = jsonDecode(data) as Map<String, dynamic>;
      return {
        'access_token': map['access_token'] as String?,
        'refresh_token': map['refresh_token'] as String?,
        'username': map['username'] as String?,
      };
    } catch (_) {
      return null;
    }
  }

  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
