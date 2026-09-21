import 'dart:convert';

class JwtUtils {
  JwtUtils._();

  static Map<String, dynamic>? decodePayload(String? token) {
    if (token == null || token.isEmpty) return null;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = parts[1];
      final normalized = _base64UrlDecode(payload);
      return jsonDecode(normalized) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static bool isExpired(String? token) {
    final payload = decodePayload(token);
    if (payload == null) return true;
    final exp = payload['exp'];
    if (exp == null) return true;
    return DateTime.fromMillisecondsSinceEpoch(exp * 1000).isBefore(DateTime.now());
  }

  static String _base64UrlDecode(String input) {
    String output = input.replaceAll('-', '+').replaceAll('_', '/');
    final padLen = (4 - output.length % 4) % 4;
    output = output.padRight(output.length + padLen, '=');
    return utf8.decode(base64Decode(output));
  }
}
