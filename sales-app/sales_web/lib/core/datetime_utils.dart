import 'package:intl/intl.dart';

/// Sejak backend serialize semua datetime sebagai WITA (`+08:00`),
/// parsing langsung menghasilkan DateTime yang field hour/minute-nya
/// sudah dalam WITA. Frontend cukup format — tidak perlu konversi
/// tambahan atau `.toLocal()` (yang tergantung timezone browser).

/// Format DateTime ke string sesuai pattern. Asumsikan input sudah
/// dalam WITA (datang dari backend).
String witaFormat(DateTime wita, {String pattern = 'dd MMM yyyy HH:mm'}) {
  return DateFormat(pattern).format(wita);
}
