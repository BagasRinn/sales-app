import 'package:intl/intl.dart';

/// Extension untuk convert DateTime ke WITA (Waktu Indonesia Tengah, UTC+8).
///
/// Lebih reliable dari `.toLocal()` karena display selalu WITA, tidak
/// tergantung timezone device. Backend menyimpan timestamp dalam UTC,
/// extension ini convert ke WITA untuk konsistensi dengan sales flow.
///
/// Behavior:
/// - UTC DateTime → ditambah 8 jam, return as local DateTime
/// - Already-local DateTime → diasumsikan sudah di device's timezone (WITA);
///   pass-through supaya tidak double-convert
extension WitaDateTime on DateTime {
  DateTime toWita() {
    if (isUtc) {
      return add(const Duration(hours: 8));
    }
    return this;
  }
}

/// Format WITA DateTime ke string. Use untuk menggantikan
/// `DateFormat.format(dt.toLocal())` — sekarang langsung format ke
/// WITA tanpa intermediate conversion.
String witaFormat(DateTime utc, {String pattern = 'dd MMM yyyy HH:mm'}) {
  return DateFormat(pattern).format(utc.toWita());
}
