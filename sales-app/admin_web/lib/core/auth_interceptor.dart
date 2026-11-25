import 'package:dio/dio.dart';

import 'auth_session.dart';

/// Interceptor auth admin web.
///
/// - onRequest: pasang `Authorization: Bearer` dari sesi in-memory. Header
///   dibaca ulang setiap request, jadi semua instance ApiService selalu
///   memakai access token terbaru setelah silent refresh.
/// - onError 401: coba pulihkan sesi via cookie httpOnly SEKALI
///   (single-flight — banyak request yang 401 bersamaan menunggu refresh
///   yang sama), lalu replay request dengan token baru. Kalau refresh
///   juga gagal → callback `onUnauthorized` (logout ke layar login).
class AuthInterceptor extends Interceptor {
  /// Dipanggil ketika sesi benar-benar habis (refresh gagal / replay 401).
  void Function()? onUnauthorized;

  /// POST /auth/refresh via cookie — disediakan ApiService.
  /// Return true bila access token baru berhasil diperoleh.
  Future<bool> Function()? refreshSession;

  /// Dio pemilik interceptor ini, dipakai untuk replay request setelah refresh.
  Dio? dio;

  /// Penanda request yang sudah pernah di-replay; mencegah siklus
  /// refresh-replay tanpa akhir bila server menolak token terbaru juga.
  static const String _retriedKey = '__auth_retried';

  /// Refresh yang sedang berjalan (single-flight).
  Future<bool>? _refreshInFlight;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = AuthSession.instance.accessToken;
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    } else {
      options.headers.remove('Authorization');
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final statusCode = err.response?.statusCode;
    final path = options.path;
    // Endpoint auth menangani 401-nya sendiri (password salah, sesi memang
    // habis) — jangan refresh & jangan logout-kan user karena situ itu.
    final isAuthEndpoint = path.contains('/auth/login') ||
        path.contains('/auth/refresh') ||
        path.contains('/auth/logout');

    if (statusCode != 401 ||
        isAuthEndpoint ||
        refreshSession == null ||
        dio == null ||
        options.extra[_retriedKey] == true) {
      if (statusCode == 401 && !isAuthEndpoint) onUnauthorized?.call();
      handler.next(err);
      return;
    }

    // Single-flight: request 401 paralel berbagi satu refresh, lalu
    // masing-masing replay dengan token baru.
    final inFlight = _refreshInFlight ?? _doRefresh();
    _refreshInFlight = inFlight;
    final refreshed = await inFlight;
    // Bersihkan penanda hanya bila masih future yang sama — pemanggil lain
    // mungkin sudah memulai refresh baru selagi ini menunggu.
    if (identical(_refreshInFlight, inFlight)) _refreshInFlight = null;

    if (!refreshed) {
      onUnauthorized?.call();
      handler.next(err);
      return;
    }

    // Replay request asli dengan access token yang sudah diperbarui.
    try {
      options.extra[_retriedKey] = true;
      options.headers['Authorization'] =
          'Bearer ${AuthSession.instance.accessToken}';
      final response = await dio!.fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (replayError) {
      if (replayError.response?.statusCode == 401) onUnauthorized?.call();
      handler.next(replayError);
    }
  }

  Future<bool> _doRefresh() async {
    final refresh = refreshSession;
    if (refresh == null) return false;
    return refresh();
  }
}
