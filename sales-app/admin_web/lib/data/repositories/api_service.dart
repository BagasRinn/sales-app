import 'package:dio/dio.dart';
import '../../core/config.dart';
import '../../core/api_exception.dart';
import '../../core/auth_interceptor.dart';

class ApiService {
  late final Dio _dio;
  final AuthInterceptor _authInterceptor = AuthInterceptor();

  String? _refreshToken;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));
    _dio.interceptors.add(_authInterceptor);
  }

  void setTokens({String? access, String? refresh}) {
    _dio.options.headers['Authorization'] = access != null ? 'Bearer $access' : null;
    _refreshToken = refresh;
  }

  void clearTokens() {
    _dio.options.headers.remove('Authorization');
    _refreshToken = null;
  }

  /// Register a callback to be called when the server returns 401.
  void setOnUnauthorized(void Function()? callback) {
    _authInterceptor.onUnauthorized = callback;
  }

  bool get hasToken => _dio.options.headers['Authorization'] != null;
  String? get accessToken => _dio.options.headers['Authorization']?.toString().replaceFirst('Bearer ', '');
  String? get refreshToken => _refreshToken;

  Future<dynamic> get(String endpoint) async {
    try {
      final resp = await _dio.get(endpoint);
      return resp.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<dynamic> post(String endpoint, {Map<String, dynamic>? body}) async {
    try {
      final resp = await _dio.post(endpoint, data: body);
      return resp.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<dynamic> put(String endpoint, {Map<String, dynamic>? body}) async {
    try {
      final resp = await _dio.put(endpoint, data: body);
      return resp.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<dynamic> postFile(String endpoint, List<int> fileBytes, String fileName) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          fileBytes,
          filename: fileName,
        ),
      });
      // Override Content-Type for multipart
      final resp = await _dio.post(
        endpoint,
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
        ),
      );
      return resp.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> delete(String endpoint) async {
    try {
      await _dio.delete(endpoint);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  ApiException _handleError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return ApiException('Koneksi timeout. Pastikan server berjalan.');
    }
    if (e.type == DioExceptionType.connectionError) {
      return ApiException('Tidak dapat terhubung ke server.');
    }
    if (e.response != null) {
      final data = e.response!.data;
      if (data is Map) {
        return ApiException(data['detail'] ?? data['message'] ?? 'Request gagal', statusCode: e.response!.statusCode);
      }
      return ApiException('Request gagal (${e.response!.statusCode})', statusCode: e.response!.statusCode);
    }
    return ApiException('Terjadi kesalahan: ${e.message}');
  }
}
