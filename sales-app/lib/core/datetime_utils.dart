// Re-export shared datetime utilities with timezone support
export 'package:datetime_utils/datetime_utils.dart';
import 'package:datetime_utils/datetime_utils.dart' as dt_utils;

/// Legacy compatibility - parse backend datetime (now uses shared package)
/// @deprecated Use [dt_utils.parseBackendDateTime] from datetime_utils package
DateTime parseBackendDateTime(String iso) => dt_utils.parseBackendDateTime(iso);

/// Legacy compatibility - format for UI (now uses shared package)
/// @deprecated Use [dt_utils.formatForUi] from datetime_utils package
String witaFormat(DateTime wita, {String pattern = 'dd MMM yyyy HH:mm'}) {
  return dt_utils.formatForUi(wita, pattern: pattern);
}
