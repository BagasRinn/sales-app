// Tangkap gambar penuh satu halaman admin (bukan hanya area yang terlihat).
//
// Konten halaman dibungkus [RepaintBoundary] dengan [GlobalKey], lalu
// [captureFullPage] merasterisasi boundary dalam potongan-potongan lewat
// `OffsetLayer.toImage` supaya tidak menabrak batas ukuran kanvas/tekstur
// browser, menggabungkan potongan menjadi satu PNG, dan memicu unduhan via
// [triggerBrowserDownload].
//
// Ukuran akhir dijaga di bawah [kMaxCapturePixels]: kalau konten sangat
// tinggi, pixelRatio diturunkan otomatis sampai batas [kMinPixelRatio];
// lebih dari itu [PageCaptureTooTallException] dilempar agar pemanggil bisa
// menampilkan saran memperkecil filter.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'web_download.dart';

/// Batas luas gambar akhir (lebar * tinggi piksel). 36M piksel ≈ 144 MB RGBA
/// untuk satu bitmap — masih nyaman untuk Chrome desktop.
const int kMaxCapturePixels = 36 * 1024 * 1024;

const double _kMaxPixelRatio = 1.5;
const double _kMinPixelRatio = 0.5;

/// Tinggi potongan logis per rasterisasi. Dikali pixelRatio maksimum (2.0)
/// tetap di bawah batas tekstur GPU browser yang umumnya 8192-16384 px.
const double _kSliceHeight = 3000;

/// Konten melebihi batas gambar satu file walau pixelRatio sudah minimum.
class PageCaptureTooTallException implements Exception {
  PageCaptureTooTallException(this.neededPixelRatio);

  /// PixelRatio yang dibutuhkan agar muat (selalu < [_kMinPixelRatio]).
  final double neededPixelRatio;

  @override
  String toString() =>
      'Konten terlalu tinggi untuk satu gambar. Saring baris lebih dulu, '
      'misalnya per divisi atau supplier.';
}

/// Tangkap seluruh isi [RepaintBoundary] (termasuk bagian di bawah lipatan
/// layar) dan unduh sebagai satu PNG.
///
/// [widthOverride] melebarkan area tangkapan melebihi lebar boundary, dipakai
/// halaman tabel yang saat capture sengaja dilepas dari scroll horizontal.
Future<void> captureFullPage({
  required GlobalKey boundaryKey,
  required String filename,
  double? widthOverride,
}) async {
  final context = boundaryKey.currentContext;
  final renderObject = context?.findRenderObject();
  final boundary = renderObject is RenderRepaintBoundary ? renderObject : null;
  if (boundary == null || !boundary.hasSize || boundary.size.width < 1) {
    throw StateError('Halaman belum siap ditangkap.');
  }
  final size = boundary.size;
  final captureWidth = math.max(size.width, widthOverride ?? size.width);
  final captureHeight = size.height;

  // PixelRatio adaptif: jaga luas akhir di bawah batas kanvas.
  final logicalArea = captureWidth * captureHeight;
  var pixelRatio = _kMaxPixelRatio;
  if (logicalArea * pixelRatio * pixelRatio > kMaxCapturePixels) {
    final needed = math.sqrt(kMaxCapturePixels / logicalArea);
    if (needed < _kMinPixelRatio) {
      throw PageCaptureTooTallException(needed);
    }
    pixelRatio = needed;
  }

  // Rasterisasi per potongan supaya tiap `toImage` kecil.
  final layer = boundary.debugLayer;
  if (layer is! OffsetLayer) {
    throw StateError('Layer halaman belum tersedia.');
  }
  final slices = <ui.Image>[];
  var offset = 0.0;
  while (offset < captureHeight - 0.5) {
    final sliceHeight = math.min(_kSliceHeight, captureHeight - offset);
    final image = await layer.toImage(
      Rect.fromLTWH(0, offset, captureWidth, sliceHeight),
      pixelRatio: pixelRatio,
    );
    slices.add(image);
    offset += sliceHeight;
  }
  if (slices.isEmpty) {
    throw StateError('Tidak ada konten untuk ditangkap.');
  }

  // Gabungkan potongan menjadi satu PNG. Latar putih supaya area transparan
  // tidak terlihat hitam di penampil gambar.
  final outWidth = (captureWidth * pixelRatio).round();
  final outHeight = slices.fold<int>(0, (total, image) => total + image.height);
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(
    recorder,
    Rect.fromLTWH(0, 0, outWidth.toDouble(), outHeight.toDouble()),
  );
  canvas.drawRect(
    Rect.fromLTWH(0, 0, outWidth.toDouble(), outHeight.toDouble()),
    ui.Paint()..color = const ui.Color(0xFFFFFFFF),
  );
  var y = 0.0;
  for (final image in slices) {
    canvas.drawImage(
      image,
      Offset(0, y),
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );
    y += image.height.toDouble();
  }
  final picture = recorder.endRecording();
  final stitched = await picture.toImage(outWidth, outHeight);
  picture.dispose();
  for (final image in slices) {
    image.dispose();
  }
  final byteData = await stitched.toByteData(format: ui.ImageByteFormat.png);
  stitched.dispose();
  if (byteData == null) {
    throw StateError('Gagal menyusun gambar.');
  }
  triggerBrowserDownload(byteData.buffer.asUint8List(), filename);
}
