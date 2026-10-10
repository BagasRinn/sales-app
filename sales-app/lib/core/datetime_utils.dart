import 'package:intl/intl.dart';

/// Sejak backend serialize semua datetime sebagai WITA (`+08:00`),
/// parsing langsung menghasilkan DateTime yang field hour/minute-nya
/// sudah dalam WITA. Frontend cukup format — tidak perlu konversi
/// tambahan.
///
/// `toWita()` dipertahankan sebagai no-op untuk backward compat dengan
/// call sites yang sudah ada; tidak melakukan shift apapun.

extension WitaDateTime on DateTime {
  /// No-op. Backend sudah mengirim WITA. Return `this` supaya call
  /// sites lama yang memanggil `.toWita()` tidak error dan tidak
  /// double-shift waktu.
  DateTime toWita() => this;
}

/// Format DateTime ke string. Asumsikan input sudah dalam WITA
/// (datang dari backend).
String witaFormat(DateTime wita, {String pattern = 'dd MMM yyyy HH:mm'}) {
  return DateFormat(pattern).format(wita);
}
