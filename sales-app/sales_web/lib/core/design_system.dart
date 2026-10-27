import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary brand
  static const Color primary = Color(0xFF183558);
  static const Color primaryLight = Color(0xFF234B7A);
  static const Color primaryDark = Color(0xFF122844);
  static const Color primarySoft = Color(0xFFE8EFF7);

  // Surface
  static const Color surface = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF8FAFC);
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
        primary: AppColors.primary,
        onPrimary: AppColors.textOnPrimary,
        primaryContainer: AppColors.primarySoft,
        onPrimaryContainer: AppColors.primary,
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
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        surfaceTintColor: Colors.transparent,
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textMuted,
        ),
        labelStyle: AppTextStyles.labelMedium,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: AppColors.textOnPrimary,
          backgroundColor: AppColors.primaryLight,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: AppTextStyles.labelLarge.copyWith(
            color: AppColors.textOnPrimary,
          ),
          elevation: 0,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primarySoft,
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
        contentTextStyle: AppTextStyles.bodyMedium.copyWith(
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      dialogTheme: const DialogThemeData(surfaceTintColor: Colors.transparent),
      bottomSheetTheme: const BottomSheetThemeData(
        surfaceTintColor: Colors.transparent,
        backgroundColor: AppColors.surface,
      ),
    );
  }
}

// ─── Status chip widgets ──────────────────────────────────────────────────────

enum AppBadgeVariant { success, warning, danger, info, neutral }

AppBadgeVariant stockStatusBadgeVariant(int status) => switch (status) {
  0 => AppBadgeVariant.danger,
  1 => AppBadgeVariant.warning,
  _ => AppBadgeVariant.success,
};

AppBadgeVariant orderStatusBadgeVariant(int status) => switch (status) {
  1 => AppBadgeVariant.info,
  2 => AppBadgeVariant.success,
  3 => AppBadgeVariant.danger,
  _ => AppBadgeVariant.neutral,
};

class AppBadge extends StatelessWidget {
  final String label;
  final AppBadgeVariant variant;
  final IconData? icon;
  final bool showDot;

  const AppBadge({
    super.key,
    required this.label,
    this.variant = AppBadgeVariant.neutral,
    this.icon,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (variant) {
      AppBadgeVariant.success => (AppColors.successBg, AppColors.success),
      AppBadgeVariant.warning => (AppColors.warningBg, AppColors.warning),
      AppBadgeVariant.danger => (AppColors.errorBg, AppColors.error),
      AppBadgeVariant.info => (AppColors.infoBg, AppColors.info),
      AppBadgeVariant.neutral => (
        AppColors.borderLight,
        AppColors.textSecondary,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: foreground.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: 4),
          ],
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: foreground,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class StockChip extends StatelessWidget {
  final int available;

  const StockChip({super.key, required this.available});

  @override
  Widget build(BuildContext context) {
    final status = _stockStatus(available);
    return AppBadge(
      label: _stockLabel(status, available),
      variant: stockStatusBadgeVariant(status),
      showDot: true,
    );
  }

  int _stockStatus(int available) {
    if (available <= 0) return 0;
    if (available <= 5) return 1;
    return 2;
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
    return AppBadge(label: _label(status), variant: orderStatusBadgeVariant(s));
  }

  int? _parse(String s) {
    switch (s.toUpperCase()) {
      case 'PENDING':
        return 1;
      case 'APPROVED':
        return 2;
      case 'REJECTED':
        return 3;
      case 'CANCELLED':
        return 4;
      case 'DRAFT':
        return 5;
      default:
        return null;
    }
  }

  String _label(String s) {
    switch (s.toUpperCase()) {
      case 'PENDING':
        return 'Menunggu';
      case 'APPROVED':
        return 'Disetujui';
      case 'REJECTED':
        return 'Ditolak';
      case 'CANCELLED':
        return 'Dibatalkan';
      case 'DRAFT':
        return 'Draft';
      default:
        return s;
    }
  }
}
