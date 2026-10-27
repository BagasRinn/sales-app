import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_tokens.dart';
import 'app_card.dart';

/// Kartu KPI ringkas. `value` dibungkus [FittedBox] agar tidak overflow.
class AppStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData? icon;
  final String? subtitle;
  final String? trendText;
  final bool isPositive;
  final VoidCallback? onTap;

  /// Override warna ikon. Null = navy primary (default seragam).
  final Color? accentColor;

  const AppStatCard({
    super.key,
    required this.title,
    required this.value,
    this.icon,
    this.subtitle,
    this.trendText,
    this.isPositive = true,
    this.onTap,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor ?? AppColors.primary;
    final accentBg = accentColor == null
        ? AppColors.primarySoft
        : accentColor!.withValues(alpha: 0.12);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accentBg,
                borderRadius: AppRadius.md,
              ),
              child: Icon(icon, size: 20, color: accent),
            ),
            const SizedBox(width: AppSpacing.sm + 4),
          ],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: AppTextStyles.metric),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle!,
                    style: AppTextStyles.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (trendText != null) ...[
                  const SizedBox(height: AppSpacing.xs + 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPositive
                            ? Icons.trending_up
                            : Icons.trending_down,
                        size: 14,
                        color: isPositive
                            ? AppColors.success
                            : AppColors.danger,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Flexible(
                        child: Text(
                          trendText!,
                          style: AppTextStyles.caption.copyWith(
                            color: isPositive
                                ? AppColors.success
                                : AppColors.danger,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
