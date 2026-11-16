import 'package:flutter/material.dart';

import 'navigator_key.dart';

/// Pembuat layar login, didaftarkan sekali dari `main.dart`.
///
/// Kenapa tidak langsung `import 'login_screen.dart'` saja?
/// `login_screen.dart` meng-import `dashboard_screen.dart` secara *deferred*
/// supaya dashboard + semua tab-nya tidak ikut di bundle awal. Dart melarang
/// siklus import pada deferred library, jadi `dashboard_screen.dart` dan
/// `change_password_dialog.dart` tidak boleh meng-import `login_screen.dart`
/// (kalau tidak, `flutter build web` gagal dengan pesan
/// "Deferred library ... is imported by ...").
Widget Function()? _loginScreenBuilder;

/// Daftarkan pembuat layar login. Dipanggil di `main()` sebelum `runApp`.
void registerLoginScreen(Widget Function() builder) {
  _loginScreenBuilder = builder;
}

/// Ganti seluruh stack navigasi dengan layar login.
///
/// Dipakai untuk logout manual, token kedaluwarsa (401), dan idle timeout —
/// satu jalur supaya perilakunya konsisten: seluruh stack dibersihkan, bukan
/// hanya halaman teratas.
///
/// Return `false` kalau navigator belum siap atau builder belum didaftarkan
/// (mis. widget test yang membangun `DashboardScreen` tanpa lewat `main()`).
bool showLoginScreen() {
  final navigator = rootNavigatorKey.currentState;
  final builder = _loginScreenBuilder;
  if (navigator == null || builder == null) return false;
  navigator.pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => builder()),
    (_) => false,
  );
  return true;
}
