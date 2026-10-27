import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_tokens.dart';

/// ThemeData global: Deep Navy + putih, datar (tanpa shadow tebal) dan
/// `surfaceTintColor` transparan supaya putih tidak berubah keunguan (M3).
class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    const scheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primarySoft,
      onPrimaryContainer: AppColors.primary,
      secondary: AppColors.primaryLight,
      onSecondary: AppColors.onPrimary,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.surfaceMuted,
      error: AppColors.danger,
      onError: AppColors.onPrimary,
      outline: AppColors.border,
      outlineVariant: AppColors.inputBorder,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: AppTextStyles.fontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.scaffoldBg,
      canvasColor: AppColors.scaffoldBg,
      visualDensity: VisualDensity.standard,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        iconTheme: IconThemeData(color: AppColors.textSecondary, size: 20),
        titleTextStyle: TextStyle(
          fontFamily: AppTextStyles.fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.lg,
          side: BorderSide(color: AppColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      iconTheme: const IconThemeData(color: AppColors.textSecondary, size: 20),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 13,
        ),
        hintStyle: AppTextStyles.bodyMuted.copyWith(color: AppColors.textMuted),
        labelStyle: AppTextStyles.bodyMuted,
        helperStyle: AppTextStyles.caption,
        errorStyle: AppTextStyles.caption.copyWith(color: AppColors.danger),
        border: const OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: AppColors.inputBorder),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: AppColors.inputBorder),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: AppColors.danger, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
          disabledForegroundColor: AppColors.onPrimary,
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          minimumSize: const Size(0, 42),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          textStyle: AppTextStyles.h3,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
          textStyle: AppTextStyles.h3,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.inputBorder),
          minimumSize: const Size(0, 42),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          textStyle: AppTextStyles.h3,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: AppTextStyles.h3,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 4),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          highlightColor: AppColors.primarySoft,
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lg),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(AppColors.scaffoldBg),
        headingRowHeight: 44,
        dataRowMinHeight: 44,
        dataRowMaxHeight: 56,
        horizontalMargin: AppSpacing.md,
        columnSpacing: AppSpacing.lg,
        dividerThickness: 1,
        headingTextStyle: AppTextStyles.label.copyWith(
          color: AppColors.textSecondary,
        ),
        dataTextStyle: AppTextStyles.body,
        dataRowColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) {
            return AppColors.primarySoft.withValues(alpha: 0.6);
          }
          return null;
        }),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.xl),
        titleTextStyle: AppTextStyles.h1,
        contentTextStyle: AppTextStyles.bodyMuted,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: AppColors.border,
        labelStyle: AppTextStyles.h3,
        unselectedLabelStyle: AppTextStyles.bodyMuted,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceMuted,
        side: const BorderSide(color: AppColors.border),
        labelStyle: AppTextStyles.caption.copyWith(color: AppColors.textPrimary),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.sm),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: AppRadius.sm,
        ),
        textStyle: AppTextStyles.caption.copyWith(color: AppColors.onPrimary),
        waitDuration: const Duration(milliseconds: 400),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.surfaceMuted,
        circularTrackColor: AppColors.surfaceMuted,
      ),
      checkboxTheme: CheckboxThemeData(
        side: const BorderSide(color: AppColors.inputBorder),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return AppColors.surface;
        }),
        checkColor: WidgetStateProperty.all(AppColors.onPrimary),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.sm),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.onPrimary;
          return AppColors.surface;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return AppColors.inputBorder;
        }),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.primary,
        contentTextStyle: AppTextStyles.body.copyWith(
          color: AppColors.onPrimary,
        ),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
      ),
      textTheme: const TextTheme(
        headlineLarge: AppTextStyles.headlineLarge,
        headlineMedium: AppTextStyles.headlineMedium,
        headlineSmall: AppTextStyles.headlineSmall,
        titleLarge: AppTextStyles.titleLarge,
        titleMedium: AppTextStyles.h2,
        titleSmall: AppTextStyles.h3,
        bodyLarge: AppTextStyles.bodyLarge,
        bodyMedium: AppTextStyles.bodyMedium,
        bodySmall: AppTextStyles.bodySmall,
        labelLarge: AppTextStyles.labelLarge,
        labelMedium: AppTextStyles.labelMedium,
        labelSmall: AppTextStyles.labelSmall,
      ),
    );
  }
}
