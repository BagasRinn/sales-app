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

  /// Alias untuk [mobileMax] — nama "compact" lebih deskriptif saat dipakai
  /// sebagai batas atas zona compact (mobile + tablet).
  static const double compactMax = 600;

  /// Batas atas tablet. Lebar >= 1024 berarti sudah masuk desktop.
  static const double tabletMax = 1024;

  /// Alias untuk [tabletMax] — batas atas zona medium (tablet).
  static const double mediumMax = 1024;
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

  /// Alias untuk [isTablet] — "medium" lebih deskriptif di form/layout helpers.
  bool get isMedium => device == DeviceClass.tablet;

  /// Alias untuk [isDesktop] — "expanded" lebih deskriptif di form/layout helpers.
  bool get isExpanded => device == DeviceClass.desktop;

  /// Padding konten default. Mobile lebih kecil dari desktop supaya kartu/tabel
  /// tidak terlalu mepet ke tepi layar kecil.
  double get contentPadding => isMobile ? 12 : isTablet ? 16 : 24;

  /// Lebar sidebar tetap (desktop) atau nol (compact, karena nav pindah ke drawer).
  double get sidebarWidth => isDesktop ? 240 : 0;

  /// Tinggi top bar. Mobile lebih pendek supaya tidak makan ruang layar kecil.
  double get topBarHeight => isMobile ? 56 : 64;

  /// Padding internal kartu. Lebih kecil di mobile supaya konten tidak terlalu
  /// sesak; lebih besar di desktop supaya kartu "bernapas".
  double get cardPadding => isMobile ? 12 : isTablet ? 16 : 20;

  /// Padding internal dialog. Mobile mengikuti inset layar; desktop lebih
  /// lapang karena dialog tidak full-viewport.
  double get dialogPadding => isMobile ? 16 : isTablet ? 20 : 24;

  /// Jarak vertikal antar field/baris pada form. Compact seragam; desktop
  /// sedikit lebih longgar agar form mudah dibaca.
  double get formGap => isMobile ? 12 : isTablet ? 16 : 20;

  /// Ukuran ikon standar. Mobile sedikit lebih kecil supaya tap-target lain
  /// (chip/button) tetap proporsional.
  double get iconSize => isMobile ? 20 : 24;

  /// Tinggi TextField/input standar. Mobile lebih tinggi untuk memenuhi
  /// rekomendasi tap-target ≥ 48dp pada iOS/Android; desktop cukup 48.
  double get inputHeight => isMobile ? 56 : 48;

  /// Jumlah kolom default untuk layout form. 1 di mobile, 2 di tablet, 3 di
  /// desktop — panggilan dapat override per-form kalau butuh lebih rapat.
  int get columns => isMobile ? 1 : isTablet ? 2 : 3;
}

/// Spacing helpers that adapt to device class.
extension ResponsiveSpacing on Responsive {
  /// Standard gap between elements. Mobile 12px, desktop 16px.
  double get gap => isMobile ? 12 : 16;

  /// Standard gap between sections. Mobile 16px, desktop 24px.
  double get sectionGap => isMobile ? 16 : 24;

  /// Page-level horizontal padding (alias of contentPadding for clarity).
  double get pagePadding => contentPadding;

  /// Jarak antar kartu dalam grid/list. Mobile 12px, desktop 16px — sedikit
  /// lebih rapat dari [gap] supaya daftar kartu tidak terlalu renggang.
  double get cardGap => isMobile ? 12 : 16;

  /// Jarak vertikal antar field pada satu form. Mobile 12px, desktop 16px.
  double get fieldGap => isMobile ? 12 : 16;
}