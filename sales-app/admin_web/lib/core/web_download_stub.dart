// Stub untuk platform non-web — tidak melakukan apa-apa.
// Dipakai oleh web_download.dart lewat conditional import supaya app
// tetap bisa di-build ke platform lain (kalau someday Flutter mendukung).
import 'dart:typed_data';

void triggerBrowserDownload(Uint8List bytes, String filename) {
  throw UnsupportedError(
    'Browser download hanya tersedia di Flutter Web. '
    'Platform lain belum didukung.',
  );
}
