import 'dart:convert';

class JwtUtils {
  JwtUtils._();

  /// Decode JWT payload without signature verification.
  /// Returns null if token is invalid/empty.
  static Map<String, dynamic>? decodePayload(String? token) {
    if (token == null || token.isEmpty) return null;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      // JWT payload is base64url encoded — add padding if needed
      final payload = parts[1];
      final normalized = _base64UrlDecode(payload);
      return jsonDecode(normalized) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Check if token is expired. Returns true if expired or invalid.
  static bool isExpired(String? token) {
    final payload = decodePayload(token);
    if (payload == null) return true;
    final exp = payload['exp'];
    if (exp == null) return true;
    // exp is unix timestamp in seconds
    return DateTime.fromMillisecondsSinceEpoch(exp * 1000).isBefore(DateTime.now());
  }

  /// Get expiry DateTime from token. Returns null if invalid.
  static DateTime? getExpiry(String? token) {
    final payload = decodePayload(token);
    if (payload == null) return null;
    final exp = payload['exp'];
    if (exp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
  }

  static String _base64UrlDecode(String input) {
    // Convert base64url to base64
    String output = input.replaceAll('-', '+').replaceAll('_', '/');
    // Add padding
    final padLen = (4 - output.length % 4) % 4;
    output = output.padRight(output.length + padLen, '=');
    return utf8.decode(base64Decode(output));
  }
}
