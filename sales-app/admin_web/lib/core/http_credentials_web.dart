import 'package:dio/browser.dart';
import 'package:dio/dio.dart';

/// Web: ikutkan cookie lintas origin pada setiap request Dio.
///
/// `withCredentials = true` = browser menyimpan `Set-Cookie` dari API dan
/// mengirim cookie itu kembali (termasuk yang httpOnly — tetap tak terbaca
/// JS, hanya ikut terkirim).
void enableWebCredentials(Dio dio) {
  final adapter = dio.httpClientAdapter;
  if (adapter is BrowserHttpClientAdapter) {
    adapter.withCredentials = true;
  }
}
