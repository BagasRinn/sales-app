import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;

/// Initialize timezone database. Call once at app startup.
void initTimezone() {
  tzdata.initializeTimeZones();
}

/// Parse ISO-8601 datetime string from backend.
/// Naive database values are UTC; values with an offset keep their instant.
DateTime parseBackendDateTime(String iso) {
  final parsed = DateTime.parse(iso);
  if (parsed.isUtc) return parsed;
  if (!iso
      .trim()
      .contains(RegExp(r'(Z|[+-]\d{2}:?\d{2})$', caseSensitive: false))) {
    return parsed.toUtc();
  }
  return parsed;
}

/// Null-safe version of [parseBackendDateTime].
DateTime? parseBackendDateTimeOrNull(String? s) =>
    (s == null || s.isEmpty) ? null : parseBackendDateTime(s);

/// Convert a datetime to the user's timezone.
/// If [iana] is provided, use that explicit Indonesian timezone.
/// Otherwise, use the device timezone automatically (WIB, WITA, or WIT).
DateTime toUserZone(DateTime value, {String? iana}) {
  final utcValue = value.isUtc ? value : value.toUtc();
  if (iana == null) return utcValue.toLocal();

  final location = tz.getLocation(iana);
  final tzValue = tz.TZDateTime.from(utcValue, location);
  return DateTime(
    tzValue.year,
    tzValue.month,
    tzValue.day,
    tzValue.hour,
    tzValue.minute,
    tzValue.second,
    tzValue.millisecond,
    tzValue.microsecond,
  );
}

/// Format DateTime for UI display in user's timezone.
///
/// [utc] - DateTime in UTC (as parsed from backend)
/// [pattern] - intl DateFormat pattern (default: 'dd MMM yyyy, HH:mm')
/// [locale] - locale for month names (default: 'id_ID')
/// [userIana] - IANA timezone identifier (e.g., 'Asia/Jakarta', 'Asia/Makassar', 'Asia/Jayapura')
///              If null, uses device local timezone.
String formatForUi(
  DateTime utc, {
  String pattern = 'dd MMM yyyy, HH:mm',
  String locale = 'id_ID',
  String? userIana,
}) {
  final local = toUserZone(utc, iana: userIana);
  return DateFormat(pattern, locale).format(local);
}

/// Format just the date portion for UI.
String formatDateForUi(
  DateTime utc, {
  String pattern = 'dd MMM yyyy',
  String locale = 'id_ID',
  String? userIana,
}) {
  return formatForUi(utc, pattern: pattern, locale: locale, userIana: userIana);
}

/// Format just the time portion for UI.
String formatTimeForUi(
  DateTime utc, {
  String pattern = 'HH:mm',
  String locale = 'id_ID',
  String? userIana,
}) {
  return formatForUi(utc, pattern: pattern, locale: locale, userIana: userIana);
}

/// Convert a date-only DateTime (from date picker) to YYYY-MM-DD string in user's timezone.
/// Used for sending date parameters to backend.
String dateToYmdString(DateTime date, {String? userIana}) {
  final local = toUserZone(date, iana: userIana);
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

/// Common IANA timezone identifiers for Indonesia.
class IndonesiaTimezones {
  static const String wib = 'Asia/Jakarta'; // UTC+7
  static const String wita = 'Asia/Makassar'; // UTC+8
  static const String wit = 'Asia/Jayapura'; // UTC+9

  static const List<String> all = [wib, wita, wit];

  static String getDisplayName(String iana) {
    switch (iana) {
      case wib:
        return 'WIB (UTC+7)';
      case wita:
        return 'WITA (UTC+8)';
      case wit:
        return 'WIT (UTC+9)';
      default:
        return iana;
    }
  }
}
