import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/config.dart';
import '../../core/api_exception.dart';
import '../../core/jwt_utils.dart';

class TokenExpiredException implements Exception {
  final String message;
  TokenExpiredException([this.message = 'Sesi login berakhir. Silakan masuk kembali.']);
  @override
  String toString() => message;
}

class ApiService {
  String? _accessToken;
  void Function()? onTokenExpired;

  void setAccessToken(String? token) {
    _accessToken = token;
  }

  void clearAccessToken() {
    _accessToken = null;
  }

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    return headers;
  }

  Future<void> _checkTokenExpiry() async {
    if (_accessToken == null) return;
    if (JwtUtils.isExpired(_accessToken)) {
      onTokenExpired?.call();
      throw TokenExpiredException();
    }
  }

  Future<dynamic> _handleResponse(http.Response response) async {
    if (response.statusCode == 401) {
      onTokenExpired?.call();
      throw TokenExpiredException();
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    }

    String message = 'Terjadi kesalahan';
    try {
      final body = jsonDecode(response.body);
      message = body['detail'] ?? body['message'] ?? message;
    } catch (_) {}

    throw ApiException(
      statusCode: response.statusCode,
      message: message,
    );
  }

  Future<dynamic> get(String endpoint, {Map<String, String>? queryParams}) async {
    await _checkTokenExpiry();
    var uri = Uri.parse('${AppConfig.baseUrl}$endpoint');
    if (queryParams != null) {
      uri = uri.replace(queryParameters: queryParams);
    }
    final response = await http
        .get(uri, headers: _headers)
        .timeout(AppConfig.requestTimeout);
    return _handleResponse(response);
  }

  Future<dynamic> post(String endpoint, {Map<String, dynamic>? body}) async {
    await _checkTokenExpiry();
    final response = await http
        .post(
          Uri.parse('${AppConfig.baseUrl}$endpoint'),
          headers: _headers,
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(AppConfig.requestTimeout);
    return _handleResponse(response);
  }

  Future<dynamic> put(String endpoint, {Map<String, dynamic>? body}) async {
    await _checkTokenExpiry();
    final response = await http
        .put(
          Uri.parse('${AppConfig.baseUrl}$endpoint'),
          headers: _headers,
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(AppConfig.requestTimeout);
    return _handleResponse(response);
  }

  Future<dynamic> delete(String endpoint) async {
    await _checkTokenExpiry();
    final response = await http
        .delete(
          Uri.parse('${AppConfig.baseUrl}$endpoint'),
          headers: _headers,
        )
        .timeout(AppConfig.requestTimeout);
    return _handleResponse(response);
  }
}
