import 'package:flutter/widgets.dart';

/// Breakpoint dan helper responsif untuk admin_web.
///
/// Tiga zona:
/// - mobile: lebar < 600px   → drawer + konten single-column
/// - tablet: 600-1024px      → drawer opsional + konten adaptif
/// - desktop: > 1024px       → layout sidebar 240px (tidak berubah dari versi lama)
///
/// Pakai [Responsive.of] di dalam [LayoutBuilder] untuk dapat nilai tipe
/// [Responsive] yang sudah di-resolve — tidak perlu hitung breakpoint manual.
class Breakpoints {
  Breakpoints._();

  /// Batas atas mobile. Lebar >= 600 berarti sudah masuk tablet.
  static const double mobileMax = 600;

  /// Batas atas tablet. Lebar >= 1024 berarti sudah masuk desktop.
  static const double tabletMax = 1024;
}

enum DeviceClass { mobile, tablet, desktop }

/// Helper yang sudah menghitung `classResponsive` + `classDevice` dari lebar.
/// Lebih simple dipakai berulang daripada ngecek `width < 600` di setiap widget.
class Responsive {
  final double width;
  final DeviceClass device;

  const Responsive._(this.width, this.device);

  /// Resolusi dari lebar (px). Aman dipakai di dalam [LayoutBuilder].
  factory Responsive.of(double width) {
    final device = width < Breakpoints.mobileMax
        ? DeviceClass.mobile
        : width < Breakpoints.tabletMax
            ? DeviceClass.tablet
            : DeviceClass.desktop;
    return Responsive._(width, device);
  }

  bool get isMobile => device == DeviceClass.mobile;
  bool get isTablet => device == DeviceClass.tablet;
  bool get isDesktop => device == DeviceClass.desktop;

  /// True di mobile dan tablet — saat shell pakai drawer, bukan sidebar fixed.
  bool get isCompact => device != DeviceClass.desktop;

  /// Padding konten default. Mobile lebih kecil dari desktop supaya kartu/tabel
  /// tidak terlalu mepet ke tepi layar kecil.
  double get contentPadding => isMobile ? 12 : isTablet ? 16 : 24;

  /// Lebar sidebar tetap (desktop) atau nol (compact, karena nav pindah ke drawer).
  double get sidebarWidth => isDesktop ? 240 : 0;

  /// Tinggi top bar. Mobile lebih pendek supaya tidak makan ruang layar kecil.
  double get topBarHeight => isMobile ? 56 : 64;
}