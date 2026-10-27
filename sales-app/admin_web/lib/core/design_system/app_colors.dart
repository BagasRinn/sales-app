import 'package:flutter/material.dart';

/// Sumber tunggal palet warna: Deep Navy `#183558` + putih / slate.
///
/// Blok "alias kompatibilitas" di bawah dipertahankan karena halaman lama
/// memakai nama field versi sebelumnya lewat `core/design_system.dart`.
class AppColors {
  AppColors._();

  // ── Brand primary (Deep Navy) ────────────────────────────────────────────
  static const Color primary = Color(0xFF183558);
  static const Color primaryHover = Color(0xFF122844);
  static const Color primaryLight = Color(0xFF234B7A);
  static const Color primarySoft = Color(0xFFE8EFF7);
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// Teks/ikon sekunder di atas navy. Pengganti `Colors.white70` (5.9:1) dan
  /// `Colors.white54` (4.3:1 — gagal AA untuk teks kecil).
  static const Color onPrimaryMuted = Color(0xFFB4C2D4);
  static const Color onPrimarySubtle = Color(0xFFC9D4E2);
  static const Color onPrimaryFaint = Color(0x1FFFFFFF);

  // ── Neutral & surfaces ───────────────────────────────────────────────────
  static const Color scaffoldBg = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF1F5F9);
  static const Color border = Color(0xFFE2E8F0);
  static const Color inputBorder = Color(0xFFCBD5E1);

  // ── Typography ───────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);

  /// Teks kecil (caption/label). 4.6:1 di atas putih — `textMuted` hanya untuk
  /// ikon/placeholder dekoratif (2.6:1, tidak lolos WCAG AA untuk teks).
  static const Color textSubtle = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  // ── Semantic status ──────────────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color successSoft = Color(0xFFECFDF5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningSoft = Color(0xFFFFFBEB);
  static const Color danger = Color(0xFFEF4444);
  static const Color dangerSoft = Color(0xFFFEF2F2);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoSoft = Color(0xFFEFF6FF);

  // ── Foreground badge/teks status (versi gelap, lolos kontras di soft bg) ──
  static const Color successText = Color(0xFF047857);
  static const Color warningText = Color(0xFFB45309);
  static const Color dangerText = Color(0xFFB91C1C);
  static const Color infoText = Color(0xFF1D4ED8);

  // ── Alias kompatibilitas (nama field lama) ───────────────────────────────
  static const Color primaryDark = primaryHover;
  static const Color sidebarBg = primary;
  static const Color background = scaffoldBg;
  static const Color textOnPrimary = onPrimary;
  static const Color borderLight = surfaceMuted;

  static const Color successBg = successSoft;
  static const Color successBorder = Color(0xFF6EE7B7);
  static const Color warningBg = warningSoft;
  static const Color warningBorder = Color(0xFFFCD34D);
  static const Color error = danger;
  static const Color errorBg = dangerSoft;
  static const Color errorBorder = Color(0xFFFECACA);
  static const Color infoBg = infoSoft;
  static const Color infoBorder = Color(0xFFBFDBFE);
}
