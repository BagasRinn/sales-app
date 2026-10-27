import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_tokens.dart';

enum AppButtonVariant { primary, secondary, outline, ghost, danger }

/// Tombol standar. API kompatibel dengan tombol lama: cukup pindahkan
/// `onPressed` + kondisi loading apa adanya.
class AppButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isFullWidth;
  final AppButtonVariant variant;

  const AppButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.isLoading = false,
    this.isFullWidth = false,
    this.variant = AppButtonVariant.primary,
  });

  ({Color bg, Color fg, BorderSide? side}) get _tone {
    switch (variant) {
      case AppButtonVariant.primary:
        return (bg: AppColors.primary, fg: AppColors.onPrimary, side: null);
      case AppButtonVariant.secondary:
        return (bg: AppColors.primarySoft, fg: AppColors.primary, side: null);
      case AppButtonVariant.outline:
        return (
          bg: AppColors.surface,
          fg: AppColors.primary,
          side: const BorderSide(color: AppColors.inputBorder),
        );
      case AppButtonVariant.ghost:
        return (bg: Colors.transparent, fg: AppColors.textSecondary, side: null);
      case AppButtonVariant.danger:
        return (bg: AppColors.danger, fg: AppColors.onPrimary, side: null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tone = _tone;

    final button = ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: tone.bg,
        foregroundColor: tone.fg,
        disabledBackgroundColor: tone.bg.withValues(alpha: 0.55),
        disabledForegroundColor: tone.fg.withValues(alpha: 0.9),
        elevation: 0,
        shadowColor: Colors.transparent,
        side: tone.side,
        minimumSize: const Size(0, 42),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        textStyle: AppTextStyles.h3.copyWith(color: tone.fg),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLoading)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (icon != null)
            Icon(icon, size: 17),
          if (isLoading || icon != null) const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );

    return isFullWidth
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }
}
