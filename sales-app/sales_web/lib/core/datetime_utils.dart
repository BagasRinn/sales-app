import 'package:intl/intl.dart';

extension DateTimeWita on DateTime {
  /// Convert UTC DateTime to WITA (UTC+8).
  DateTime toWita() {
    return toUtc().add(const Duration(hours: 8));
  }

  /// Format as Indonesian date string.
  String toIdDate() {
    return DateFormat('dd MMM yyyy', 'id').format(toWita());
  }

  /// Format as Indonesian date-time string.
  String toIdDateTime() {
    return DateFormat('dd MMM yyyy, HH:mm', 'id').format(toWita());
  }
}
