import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../../core/config.dart';
import '../../core/api_exception.dart';
import '../../core/auth_interceptor.dart';
import '../../core/auth_session.dart';
import '../../core/http_credentials.dart';

class ApiService {
  late final Dio _dio;
  final AuthInterceptor _authInterceptor = AuthInterceptor();

  /// Expose internal Dio — dipakai caller yang butuh kontrol penuh
  /// (mis. download binary dengan ResponseType.bytes).
  Dio get dio => _dio;

  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        // Dashboard comparison requests over 6/12 months can legitimately
        // take 15–20 seconds. Keep connect timeout short, but let GETs finish
        // instead of being canceled by Dio before the API returns 200.
        receiveTimeout: const Duration(seconds: 60),
        headers: {
          'Content-Type': 'application/json',
          'X-Timezone-Offset-Minutes': DateTime.now().timeZoneOffset.inMinutes
              .toString(),
        },
      ),
    );
    _dio.interceptors.add(_authInterceptor);
    // Web: cookie httpOnly (refresh token) ikut setiap request.
    // No-op di platform non-web (stub).
    enableWebCredentials(_dio);
    // Interceptor 401 memanggil silent refresh lalu replay request.
    _authInterceptor.refreshSession = refreshSession;
    _authInterceptor.dio = _dio;
  }

  // Import-excel endpoints can run for minutes on big files; the default
  // 10s receive timeout aborts before the server finishes. Per-call override
  // keeps short timeouts on regular JSON calls.
  static const Duration _importReceiveTimeout = Duration(seconds: 180);

  /// Kompatibilitas pemanggil lama: token hidup di [AuthSession] (memori),
  /// header Authorization dipasang AuthInterceptor per-request.
  /// [refresh] diabaikan — refresh token kini di cookie httpOnly server.
  void setTokens({String? access, String? refresh}) {
    if (access != null) AuthSession.instance.accessToken = access;
  }

  void clearTokens() => AuthSession.instance.clear();

  /// Register a callback to be called when the server returns 401.
  void setOnUnauthorized(void Function()? callback) {
    _authInterceptor.onUnauthorized = callback;
  }

  bool get hasToken => AuthSession.instance.hasSession;
  String? get accessToken => AuthSession.instance.accessToken;

  /// Silent refresh: tukar cookie httpOnly menjadi access token baru.
  ///
  /// Dipakai (1) saat boot untuk memulihkan sesi tanpa login ulang, (2) oleh
  /// interceptor saat 401, (3) timer periodic di dashboard sebelum token
  /// habis. Pakai Dio terpisah tanpa interceptor supaya 401 dari /auth/refresh
  /// tidak memicu interceptor (menghindari loop refresh).
  Future<bool> refreshSession() async {
    final raw = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    enableWebCredentials(raw);
    try {
      final resp = await raw.post<dynamic>(
        '/auth/refresh',
        data: const <String, dynamic>{},
        options: Options(
          // 401/403 = sesi memang habis — bukan kegagalan jaringan.
          validateStatus: (code) => code != null && code < 500,
        ),
      );
      if (resp.statusCode != 200) return false;
      final data = resp.data;
      if (data is! Map || data['access_token'] == null) return false;
      AuthSession.instance.applyLogin(Map<String, dynamic>.from(data));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Bereskan cookie sesi di server (best-effort).
  ///
  /// Juga pakai Dio terpisah tanpa interceptor: logout boleh dipanggil saat
  /// sesi sudah tidak valid, dan 401 di sini tidak boleh memicu alur
  /// refresh/logout berantai.
  Future<void> logoutServer() async {
    final raw = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );
    enableWebCredentials(raw);
    try {
      await raw.post<dynamic>(
        '/auth/logout',
        data: const <String, dynamic>{},
        options: Options(
          validateStatus: (code) => code != null && code < 500,
        ),
      );
    } catch (_) {
      // Best-effort: kegagalan jaringan tidak boleh menghalangi logout lokal.
    }
  }

  Future<dynamic> get(
    String endpoint, {
    CancelToken? cancelToken,
    Duration? receiveTimeout,
  }) async {
    try {
      final opts = receiveTimeout != null
          ? Options(receiveTimeout: receiveTimeout)
          : null;
      final resp = await _dio.get(
        endpoint,
        cancelToken: cancelToken,
        options: opts,
      );
      return resp.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
    CancelToken? cancelToken,
  }) async {
    try {
      final resp = await _dio.post(
        endpoint,
        data: body,
        cancelToken: cancelToken,
      );
      return resp.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<dynamic> put(
    String endpoint, {
    Map<String, dynamic>? body,
    CancelToken? cancelToken,
  }) async {
    try {
      final resp = await _dio.put(
        endpoint,
        data: body,
        cancelToken: cancelToken,
      );
      return resp.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<dynamic> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    CancelToken? cancelToken,
  }) async {
    try {
      final resp = await _dio.patch(
        endpoint,
        data: body,
        cancelToken: cancelToken,
      );
      return resp.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<dynamic> postFile(
    String endpoint,
    List<int> fileBytes,
    String fileName, {
    CancelToken? cancelToken,
    String? jobId,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
      });
      // Override Content-Type for multipart
      final resp = await _dio.post(
        endpoint,
        data: formData,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
            'X-Import-Job-Id': ?jobId,
          },
          receiveTimeout:
              (endpoint.contains('/import-excel') ||
                  endpoint.contains('/sales-imports'))
              ? _importReceiveTimeout
              : null,
        ),
      );
      return resp.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<dynamic> importSalesExcel(List<int> fileBytes, String fileName) async {
    return postFile('/sales-imports/excel', fileBytes, fileName);
  }

  Future<Map<String, dynamic>> getImportedSalesSummary({String? month}) async {
    final m = month ?? DateFormat('yyyy-MM').format(DateTime.now());
    final data = await get('/sales-imports/summary?month=$m');
    return Map<String, dynamic>.from(data);
  }

  Future<dynamic> delete(
    String endpoint, {
    Map<String, dynamic>? data,
    CancelToken? cancelToken,
  }) async {
    try {
      final resp = await _dio.delete(
        endpoint,
        data: data,
        cancelToken: cancelToken,
      );
      return resp.data;
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
        return ApiException(
          data['detail'] ?? data['message'] ?? 'Request gagal',
          statusCode: e.response!.statusCode,
        );
      }
      return ApiException(
        'Request gagal (${e.response!.statusCode})',
        statusCode: e.response!.statusCode,
      );
    }
    return ApiException('Terjadi kesalahan: ${e.message}');
  }
}
