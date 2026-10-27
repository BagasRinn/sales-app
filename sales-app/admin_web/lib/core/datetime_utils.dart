// Re-export shared datetime utilities with timezone support
export 'package:datetime_utils/datetime_utils.dart';
import 'package:datetime_utils/datetime_utils.dart' as dt_utils;

/// Legacy compatibility - parse WITA ISO string (now uses shared package)
/// @deprecated Use [dt_utils.parseBackendDateTime] from datetime_utils package
DateTime parseWitaIso(String iso) => dt_utils.parseBackendDateTime(iso);

/// Legacy compatibility - null-safe parse backend ISO string
/// @deprecated Use [dt_utils.parseBackendDateTimeOrNull] from datetime_utils package
DateTime? parseWitaIsoOrNull(String? s) =>
    (s == null || s.isEmpty) ? null : dt_utils.parseBackendDateTime(s);

/// Legacy compatibility - format for UI (now uses shared package)
/// @deprecated Use [dt_utils.formatForUi] from datetime_utils package
String witaFormat(DateTime dt, {String pattern = 'dd MMM yyyy HH:mm'}) {
  return dt_utils.formatForUi(dt, pattern: pattern);
}

/// Legacy compatibility - convert date to YYYY-MM-DD in WITA
/// @deprecated Use [dt_utils.dateToYmdString] from datetime_utils package
String witaDateStr(DateTime date) => dt_utils.dateToYmdString(date);
