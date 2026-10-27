import 'dart:async';
import 'dart:typed_data';
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'bulletin_pdf_picker_stub.dart' show PickedPdf;

/// Buka file picker native browser untuk PDF. Return null kalau user cancel.
Future<PickedPdf?> pickPdfFile() async {
  final completer = Completer<PickedPdf?>();
  final input = html.FileUploadInputElement()
    ..accept = 'application/pdf,.pdf'
    ..style.display = 'none';

  html.document.body?.append(input);

  void onChange(html.Event _) {
    input.remove();
    final files = input.files;
    if (files == null || files.isEmpty) {
      completer.complete(null);
      return;
    }
    final file = files.first;
    final reader = html.FileReader();

    reader.onLoadEnd.listen((_) {
      final result = reader.result;
      if (result is Uint8List) {
        completer.complete(PickedPdf(file.name, result));
      } else {
        completer.complete(null);
      }
    });
    reader.onError.listen((_) {
      completer.complete(null);
    });

    reader.readAsArrayBuffer(file);
  }

  input.onChange.listen(onChange);

  // Trigger klik — FilePicker native browser
  input.click();

  return completer.future;
}