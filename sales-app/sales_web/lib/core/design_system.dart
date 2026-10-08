import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary brand
  static const Color primary = Color(0xFF1E3A5F);
  static const Color primaryLight = Color(0xFF2563EB);
  static const Color primaryDark = Color(0xFF152C4A);

  // Surface
  static const Color surface = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF4F7FB);
  static const Color cardSurface = Color(0xFFFFFFFF);

  // Semantic
  static const Color success = Color(0xFF059669);
  static const Color successBg = Color(0xFFECFDF5);

  static const Color warning = Color(0xFFD97706);
  static const Color warningBg = Color(0xFFFFFBEB);

  static const Color error = Color(0xFFDC2626);
  static const Color errorBg = Color(0xFFFEF2F2);

  static const Color info = Color(0xFF2563EB);
  static const Color infoBg = Color(0xFFEFF6FF);

  // Text
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Borders
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFF1F5F9);
}

class AppTextStyles {
  AppTextStyles._();

  static const String fontFamily = 'Plus Jakarta Sans';
  static const String monoFontFamily = 'JetBrains Mono';

  static const TextStyle headlineLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    height: 1.3,
    color: AppColors.textPrimary,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.35,
    color: AppColors.textPrimary,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.textSecondary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: AppColors.textMuted,
  );

  static const TextStyle labelLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: 0.3,
    color: AppColors.textSecondary,
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: AppTextStyles.fontFamily,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryLight,
        onPrimary: AppColors.textOnPrimary,
        primaryContainer: AppColors.primary,
        onPrimaryContainer: AppColors.textOnPrimary,
        secondary: AppColors.primary,
        onSecondary: AppColors.textOnPrimary,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: AppColors.error,
        onError: AppColors.textOnPrimary,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.cardSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primaryLight, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
        labelStyle: AppTextStyles.labelMedium,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: AppColors.textOnPrimary,
          backgroundColor: AppColors.primaryLight,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: AppTextStyles.labelLarge.copyWith(color: AppColors.textOnPrimary),
          elevation: 0,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.infoBg,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 68,
        elevation: 0,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primaryLight, size: 24);
          }
          return const IconThemeData(color: AppColors.textMuted, size: 24);
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
    );
  }
}

// ─── Status chip widgets ──────────────────────────────────────────────────────

class StockChip extends StatelessWidget {
  final int available;

  const StockChip({super.key, required this.available});

  @override
  Widget build(BuildContext context) {
    final status = _stockStatus(available);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _stockBg(status),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: _stockColor(status),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _stockLabel(status, available),
            style: TextStyle(
              fontFamily: AppTextStyles.fontFamily,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _stockColor(status),
            ),
          ),
        ],
      ),
    );
  }

  int _stockStatus(int available) {
    if (available <= 0) return 0;
    if (available <= 5) return 1;
    return 2;
  }

  Color _stockColor(int status) {
    if (status == 0) return AppColors.error;
    if (status == 1) return AppColors.warning;
    return AppColors.success;
  }

  Color _stockBg(int status) {
    if (status == 0) return AppColors.errorBg;
    if (status == 1) return AppColors.warningBg;
    return AppColors.successBg;
  }

  String _stockLabel(int status, int available) {
    if (status == 0) return 'Stok Habis';
    if (status == 1) return 'Stok Rendah';
    return 'Tersedia ($available)';
  }
}

class OrderStatusChip extends StatelessWidget {
  final String status;

  const OrderStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final s = _parse(status);
    if (s == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _bg(s),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _label(status),
        style: TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _color(s),
        ),
      ),
    );
  }

  int? _parse(String s) {
    switch (s.toUpperCase()) {
      case 'PENDING': return 1;
      case 'APPROVED': return 2;
      case 'REJECTED': return 3;
      case 'CANCELLED': return 4;
      case 'DRAFT': return 5;
      default: return null;
    }
  }

  Color _color(int s) {
    if (s == 1) return AppColors.info;
    if (s == 2) return AppColors.success;
    if (s == 3) return AppColors.error;
    if (s == 4 || s == 5) return AppColors.textMuted;
    return AppColors.textMuted;
  }

  Color _bg(int s) {
    if (s == 1) return AppColors.infoBg;
    if (s == 2) return AppColors.successBg;
    if (s == 3) return AppColors.errorBg;
    if (s == 4) return AppColors.borderLight;
    if (s == 5) return AppColors.borderLight;
    return AppColors.borderLight;
  }

  String _label(String s) {
    switch (s.toUpperCase()) {
      case 'PENDING': return 'Menunggu';
      case 'APPROVED': return 'Disetujui';
      case 'REJECTED': return 'Ditolak';
      case 'CANCELLED': return 'Dibatalkan';
      case 'DRAFT': return 'Draft';
      default: return s;
    }
  }
}
