/// Helper parsing input angka dari `TextField` (diskon / up price).
///
/// Field diskon & up price memakai keyboard numerik dengan filter
/// `[\d,.]`, jadi user bebas mengetik pemisah ribuan maupun desimal.
/// `double.tryParse` mentah tidak cukup:
///
/// | Input        | `double.tryParse` | Hasil yang diharapkan |
/// |--------------|-------------------|-----------------------|
/// | `10.000`     | 10                | 10000                 |
/// | `10.000,5`   | null (→ 0)        | 10000.5               |
/// | `1.000.000`  | null (→ 0)        | 1000000               |
/// | `10,5`       | null (→ 0)        | 10.5                  |
///
/// Nilai yang salah baca membuat diskon "tersimpan" tapi tidak berefek
/// (mis. Rp 10 dari input "10.000") atau hilang sama sekali (0), sehingga
/// tidak muncul di line item.
library;

/// Parse angka dari input user.
///
/// [allowThousands] `true` untuk nominal rupiah (pemisah + 3 digit dianggap
/// ribuan, mis. "10.000" → 10000). Untuk persen, set `false` supaya
/// "10.000" tetap dibaca 10% (pemisah dianggap desimal).
double parseNumberInput(String raw, {bool allowThousands = true}) {
  var text = raw.replaceAll(RegExp(r'[^0-9,.\-]'), '').trim();
  if (text.isEmpty) return 0;

  final hasComma = text.contains(',');
  final hasDot = text.contains('.');

  if (hasComma && hasDot) {
    // Pemisah yang muncul paling akhir adalah pemisah desimal.
    final useComma = text.lastIndexOf(',') > text.lastIndexOf('.');
    final decimalSep = useComma ? ',' : '.';
    final thousandSep = useComma ? '.' : ',';
    text = text.replaceAll(thousandSep, '').replaceAll(decimalSep, '.');
  } else if (hasComma || hasDot) {
    final sep = hasComma ? ',' : '.';
    final parts = text.split(sep);
    if (parts.length > 2) {
      // Lebih dari satu pemisah → pasti pemisah ribuan.
      text = parts.join();
    } else if (allowThousands &&
        parts.length == 2 &&
        parts[0].isNotEmpty &&
        parts[1].length == 3) {
      // "10.000" / "1,500" → ribuan, bukan desimal.
      text = parts.join();
    } else {
      text = parts.join('.');
    }
  }

  final value = double.tryParse(text);
  if (value == null || value.isNaN || value.isInfinite) return 0;
  // Normalisasi -0.0 agar tidak lolos cek `value <= 0`.
  return value == 0 ? 0 : value;
}

/// Teks awal untuk field diskon / up price: buang `.0` yang tidak perlu.
String formatEditableNumber(num value) {
  if (value == value.roundToDouble()) return '${value.round()}';
  return '$value';
}
