import 'package:dio/dio.dart';

/// Dio interceptor that catches 401 responses and triggers logout redirect.
class AuthInterceptor extends Interceptor {
  /// Called when a 401 Unauthorized response is received.
  void Function()? onUnauthorized;

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (response.statusCode == 401) {
      onUnauthorized?.call();
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      onUnauthorized?.call();
    }
    handler.next(err);
  }
}
