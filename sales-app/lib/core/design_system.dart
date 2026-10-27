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
  static const Color success = Color(0xFF059669); // stock available, approved
  static const Color successBg = Color(0xFFECFDF5);
  static const Color successBorder = Color(0xFF6EE7B7);

  static const Color warning = Color(0xFFD97706); // low stock, perlu ditinjau
  static const Color warningBg = Color(0xFFFFFBEB);
  static const Color warningBorder = Color(0xFFFCD34D);

  static const Color error = Color(0xFFDC2626); // out of stock, rejected
  static const Color errorBg = Color(0xFFFEF2F2);
  static const Color errorBorder = Color(0xFFFECACA);

  static const Color info = Color(0xFF2563EB); // pending, informational
  static const Color infoBg = Color(0xFFEFF6FF);
  static const Color infoBorder = Color(0xFFBFDBFE);

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

  // Display / Hero
  static const TextStyle displayLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    height: 1.2,
    color: AppColors.textPrimary,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.25,
    color: AppColors.textPrimary,
  );

  // Headings
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

  // Body
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

  // Labels
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

  // Mono (SKU, numbers)
  static const TextStyle mono = TextStyle(
    fontFamily: monoFontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    color: AppColors.textMuted,
  );

  static const TextStyle monoLarge = TextStyle(
    fontFamily: monoFontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
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
        scrolledUnderElevation: 1,
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
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
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
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
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: const BorderSide(color: AppColors.primaryLight, width: 1.5),
          textStyle: AppTextStyles.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: AppTextStyles.labelLarge,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primarySoft,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTextStyles.labelMedium.copyWith(
              color: AppColors.primaryLight,
              fontWeight: FontWeight.w700,
            );
          }
          return AppTextStyles.labelMedium.copyWith(color: AppColors.textMuted);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primaryLight, size: 24);
          }
          return const IconThemeData(color: AppColors.textMuted, size: 24);
        }),
        height: 68,
        elevation: 0,
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
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        labelStyle: AppTextStyles.labelMedium,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }
}

// ─── Status chip widget (shared across app & admin) ─────────────────────────

enum StockStatus { available, low, outOfStock }

Color statusColor(StockStatus s) {
  switch (s) {
    case StockStatus.available:
      return AppColors.success;
    case StockStatus.low:
      return AppColors.warning;
    case StockStatus.outOfStock:
      return AppColors.error;
  }
}

Color statusBgColor(StockStatus s) {
  switch (s) {
    case StockStatus.available:
      return AppColors.successBg;
    case StockStatus.low:
      return AppColors.warningBg;
    case StockStatus.outOfStock:
      return AppColors.errorBg;
  }
}

String statusLabel(StockStatus s) {
  switch (s) {
    case StockStatus.available:
      return 'Tersedia';
    case StockStatus.low:
      return 'Stok Rendah';
    case StockStatus.outOfStock:
      return 'Stok Habis';
  }
}

StockStatus stockStatusFromValue(int available) {
  if (available <= 0) return StockStatus.outOfStock;
  if (available <= 5) return StockStatus.low;
  return StockStatus.available;
}

enum AppBadgeVariant { success, warning, danger, info, neutral }

AppBadgeVariant stockStatusBadgeVariant(StockStatus status) => switch (status) {
  StockStatus.available => AppBadgeVariant.success,
  StockStatus.low => AppBadgeVariant.warning,
  StockStatus.outOfStock => AppBadgeVariant.danger,
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

String stockStatusDisplayLabel(StockStatus status) => switch (status) {
  StockStatus.available => 'Tersedia',
  StockStatus.low => 'Stok Rendah',
  StockStatus.outOfStock => 'Stok Habis',
};

class StockStatusChip extends StatelessWidget {
  final StockStatus status;
  final String? label;

  const StockStatusChip({super.key, required this.status, this.label});

  @override
  Widget build(BuildContext context) {
    return AppBadge(
      label: label ?? stockStatusDisplayLabel(status),
      variant: stockStatusBadgeVariant(status),
    );
  }
}

class StockChip extends StatelessWidget {
  final int available;
  final bool showCount;

  const StockChip({super.key, required this.available, this.showCount = true});

  @override
  Widget build(BuildContext context) {
    final status = stockStatusFromValue(available);
    return StockStatusChip(
      status: status,
      label: showCount
          ? '${statusLabel(status)} ($available)'
          : statusLabel(status),
    );
  }
}

// ─── Order status chip ────────────────────────────────────────────────────────

enum OrderStatus { draft, pending, approved, rejected, cancelled }

AppBadgeVariant orderStatusBadgeVariant(OrderStatus status) => switch (status) {
  OrderStatus.draft => AppBadgeVariant.neutral,
  OrderStatus.pending => AppBadgeVariant.info,
  OrderStatus.approved => AppBadgeVariant.success,
  OrderStatus.rejected => AppBadgeVariant.danger,
  OrderStatus.cancelled => AppBadgeVariant.neutral,
};

Color orderStatusColor(OrderStatus s) {
  switch (s) {
    case OrderStatus.draft:
      return AppColors.textMuted;
    case OrderStatus.pending:
      return AppColors.info;
    case OrderStatus.approved:
      return AppColors.success;
    case OrderStatus.rejected:
      return AppColors.error;
    case OrderStatus.cancelled:
      return AppColors.textMuted;
  }
}

Color orderStatusBgColor(OrderStatus s) {
  switch (s) {
    case OrderStatus.draft:
      return AppColors.borderLight;
    case OrderStatus.pending:
      return AppColors.infoBg;
    case OrderStatus.approved:
      return AppColors.successBg;
    case OrderStatus.rejected:
      return AppColors.errorBg;
    case OrderStatus.cancelled:
      return AppColors.border;
  }
}

String orderStatusLabel(String status) {
  switch (status.toUpperCase()) {
    case 'DRAFT':
      return 'Draft';
    case 'PENDING':
      return 'Menunggu';
    case 'APPROVED':
      return 'Disetujui';
    case 'REJECTED':
      return 'Ditolak';
    case 'CANCELLED':
      return 'Dibatalkan';
    default:
      return status;
  }
}

OrderStatus? orderStatusFromString(String? s) {
  if (s == null) return null;
  switch (s.toUpperCase()) {
    case 'DRAFT':
      return OrderStatus.draft;
    case 'PENDING':
      return OrderStatus.pending;
    case 'APPROVED':
      return OrderStatus.approved;
    case 'REJECTED':
      return OrderStatus.rejected;
    case 'CANCELLED':
      return OrderStatus.cancelled;
    default:
      return null;
  }
}

class OrderStatusChip extends StatelessWidget {
  final String status;
  final String? label;

  const OrderStatusChip({super.key, required this.status, this.label});

  @override
  Widget build(BuildContext context) {
    final s = orderStatusFromString(status);
    if (s == null) return const SizedBox.shrink();
    return AppBadge(
      label: label ?? orderStatusLabel(status),
      variant: orderStatusBadgeVariant(s),
    );
  }
}
