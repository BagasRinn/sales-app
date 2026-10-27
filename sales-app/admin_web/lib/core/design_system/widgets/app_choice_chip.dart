import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_tokens.dart';

class AppChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onSelected;
  final IconData? icon;
  final bool dense;

  const AppChoiceChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onSelected,
    this.icon,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.primary : AppColors.textSecondary;
    final background = selected ? AppColors.primarySoft : AppColors.surface;

    return Material(
      color: background,
      borderRadius: AppRadius.sm,
      child: InkWell(
        onTap: onSelected,
        borderRadius: AppRadius.sm,
        child: Container(
          height: dense ? 30 : 34,
          padding: EdgeInsets.symmetric(horizontal: dense ? 10 : 12),
          decoration: BoxDecoration(
            borderRadius: AppRadius.sm,
            border: Border.all(
              color: selected
                  ? AppColors.primaryLight.withValues(alpha: 0.45)
                  : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: dense ? 14 : 16, color: foreground),
                SizedBox(width: dense ? 5 : 6),
              ],
              Text(
                label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: foreground,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppRemovableChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  final IconData? icon;

  const AppRemovableChip({
    super.key,
    required this.label,
    required this.onRemove,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.only(left: 10, right: 5),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: AppRadius.sm,
        border: Border.all(
          color: AppColors.primaryLight.withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: AppColors.primary),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 2),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 14),
            color: AppColors.primary,
            tooltip: 'Hapus filter $label',
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
