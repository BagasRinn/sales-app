import 'dart:convert';

class JwtUtils {
  /// Decode JWT payload without verification (web-safe).
  /// Returns null if invalid format.
  static Map<String, dynamic>? decodePayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = parts[1];
      // Add padding if needed
      final padded = payload.padRight(
        payload.length + (4 - payload.length % 4) % 4,
        '=',
      );
      final normalized = padded.replaceAll('-', '+').replaceAll('_', '/');
      final decoded = utf8.decode(base64.decode(normalized));
      return jsonDecode(decoded) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Check if token is expired.
  static bool isExpired(String? token) {
    if (token == null) return true;
    final payload = decodePayload(token);
    if (payload == null) return true;
    final exp = payload['exp'] as int?;
    if (exp == null) return false;
    return DateTime.fromMillisecondsSinceEpoch(exp * 1000).isBefore(DateTime.now());
  }

  /// Get expiry DateTime from token.
  static DateTime? getExpiryDate(String? token) {
    if (token == null) return null;
    final payload = decodePayload(token);
    if (payload == null) return null;
    final exp = payload['exp'] as int?;
    if (exp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
  }
}
