import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_tokens.dart';

/// Status pill: Success, Warning, Danger, Info, Neutral.
class AppBadge extends StatelessWidget {
  final String label;
  final AppBadgeVariant variant;
  final IconData? icon;
  final bool compact;

  const AppBadge({
    super.key,
    required this.label,
    this.variant = AppBadgeVariant.neutral,
    this.icon,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (variant) {
      AppBadgeVariant.success => (AppColors.successSoft, AppColors.successText),
      AppBadgeVariant.warning => (AppColors.warningSoft, AppColors.warningText),
      AppBadgeVariant.danger => (AppColors.dangerSoft, AppColors.dangerText),
      AppBadgeVariant.info => (AppColors.infoSoft, AppColors.infoText),
      AppBadgeVariant.neutral => (
        AppColors.surfaceMuted,
        AppColors.textSecondary,
      ),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : AppSpacing.sm + 2,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.sm,
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
                fontSize: compact ? 11 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum AppBadgeVariant { success, warning, danger, info, neutral }
