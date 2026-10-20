import 'package:intl/intl.dart';

/// Frontend datetime utilities.
///
/// NOTE: Backend sekarang mengirim semua datetime dalam format WITA (+08:00).
/// Frontend cukup parse dan tampilkan langsung — tidak perlu konversi timezone.
/// Helper di file ini terutama untuk format tanggal saja.
///
/// Contoh format datetime dari backend: "2026-10-20T10:00:00+08:00"
/// Flutter DateTime.parse() handle ini dengan benar — time component langsung
/// dalam WITA, tidak perlu tambahan konversi.

/// Format DateTime ke string. Asumsikan input sudah dalam WITA
/// (datang dari backend).
String witaFormat(DateTime wita, {String pattern = 'dd MMM yyyy HH:mm'}) {
  return DateFormat(pattern).format(wita);
}
