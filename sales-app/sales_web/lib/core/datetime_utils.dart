const _bulanIndonesia = [
  '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
  'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des',
];

/// Parse ISO string WITA dan buat DateTime UTC dengan field WITA.
/// Ini memastikan DateFormat.format() menampilkan jam WITA dengan benar
/// tanpa peduli timezone perangkat.
DateTime parseWitaIso(String iso) {
  return DateTime.utc(
    int.parse(iso.substring(0, 4)),    // year
    int.parse(iso.substring(5, 7)),   // month
    int.parse(iso.substring(8, 10)),  // day
    int.parse(iso.substring(11, 13)), // hour (WITA)
    int.parse(iso.substring(14, 16)), // minute
  );
}

/// Null-safe version of parseWitaIso.
DateTime? parseWitaIsoOrNull(String? s) =>
    (s == null || s.isEmpty) ? null : parseWitaIso(s);

/// Format DateTime (sudah di-parse dengan parseWitaIso) ke string
/// human-readable dengan nama bulan Bahasa Indonesia.
///
/// Supports patterns:
/// - 'dd MMM yyyy, HH:mm' → "20 Okt 2026, 10:00"
/// - 'dd/MM/yyyy HH:mm'   → "20/10/2026 10:00"
/// - 'dd MMM yyyy'        → "20 Okt 2026"
String witaFormat(DateTime dt, {String pattern = 'dd MMM yyyy, HH:mm'}) {
  final monthName = _bulanIndonesia[dt.month];
  final monthNum = dt.month.toString().padLeft(2, '0');
  final year = dt.year.toString();
  final day = dt.day.toString().padLeft(2, '0');
  final hour = dt.hour.toString().padLeft(2, '0');
  final minute = dt.minute.toString().padLeft(2, '0');

  // Protect month name placeholder first, so 'MMM' doesn't get clobbered
  // by the numeric month replacement.
  final temp = pattern
      .replaceAll('dd MMM yyyy,', 'DDMMMYYYY,')
      .replaceAll('dd MMM yyyy', 'DDMMMYYYY');

  return temp
      .replaceAll('DDMMMYYYY', '$day $monthName $year')
      .replaceAll('MM', monthNum)
      .replaceAll('dd', day)
      .replaceAll('HH', hour)
      .replaceAll('mm', minute)
      .replaceAll('yyyy', year);
}
