// Helper untuk trigger browser download di Flutter Web.
//
// Pakai conditional import supaya analyzer tidak komplain waktu build
// untuk platform lain. Saat ini admin_web hanya jalan di web, tapi pola
// ini aman kalau someday dibuild untuk platform lain.
//
// ignore: avoid_web_libraries_in_flutter
import 'dart:typed_data';
import 'web_download_stub.dart'
    if (dart.library.html) 'web_download_web.dart' as impl;

void triggerBrowserDownload(Uint8List bytes, String filename) {
  impl.triggerBrowserDownload(bytes, filename);
}
