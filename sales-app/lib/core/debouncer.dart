import 'dart:async';
import 'package:flutter/foundation.dart';

/// Tunda eksekusi callback: panggilan berturut-turut dalam [delay] hanya
/// mengeksekusi yang terakhir. Dipakai untuk menahan fetch per-keystroke.
class Debouncer {
  Debouncer({this.delay = const Duration(milliseconds: 300)});

  final Duration delay;
  Timer? _timer;

  void call(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => cancel();
}
