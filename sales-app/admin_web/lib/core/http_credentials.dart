/// Aktifkan pengiriman cookie pada request Dio.
///
/// Wajib di web supaya cookie httpOnly (refresh token) yang dipasang backend
/// ikut tersimpan dan dikirim browser pada setiap request API.
/// Tanpa ini `Set-Cookie` dari response API akan diabaikan browser.
library;

export 'http_credentials_stub.dart'
    if (dart.library.html) 'http_credentials_web.dart';
