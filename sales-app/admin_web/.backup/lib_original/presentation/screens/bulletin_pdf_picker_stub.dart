import 'dart:typed_data';

/// Result dari picker PDF.
class PickedPdf {
  final String name;
  final Uint8List bytes;
  PickedPdf(this.name, this.bytes);
}

/// Stub untuk platform non-web (Android/iOS/desktop).
/// Tidak dipakai di admin_web (web-only), tapi harus ada untuk compile
/// di platform lain.
Future<PickedPdf?> pickPdfFile() async {
  throw UnsupportedError(
    'pickPdfFile() tidak tersedia di platform ini. '
    'Implementasi hanya untuk web.',
  );
}