import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../app_tokens.dart';

/// Container putih standar: border 1px `#E2E8F0`, radius 12, tanpa shadow.
class AppCard extends StatelessWidget {
  final Widget? child;
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Color? borderColor;
  final double? elevation;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    this.child,
    this.title,
    this.subtitle,
    this.trailing,
    this.padding,
    this.margin,
    this.color,
    this.borderColor,
    this.elevation,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasHeader = title != null || subtitle != null || trailing != null;
    final content = Padding(
      padding: padding ??
          (hasHeader ? const EdgeInsets.all(AppSpacing.md) : EdgeInsets.zero),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasHeader) _buildHeader(),
          if (hasHeader && child != null) const SizedBox(height: AppSpacing.md),
          ?child,
        ],
      ),
    );

    return Container(
      margin: margin,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color ?? AppColors.surface,
        borderRadius: AppRadius.lg,
        border: Border.all(color: borderColor ?? AppColors.border),
        boxShadow: elevation != null && elevation! > 0
            ? [
                BoxShadow(
                  color: AppColors.textPrimary.withValues(alpha: 0.04),
                  blurRadius: elevation! * 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        // Transparan: beri ListTile/ExpansionTile di dalam card sebuah Material
        // ancestor sendiri, kalau tidak Flutter menolak (ink tidak terlihat di
        // atas DecoratedBox AppCard).
        type: MaterialType.transparency,
        child: onTap == null
            ? content
            : InkWell(onTap: onTap, child: content),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null) Text(title!, style: AppTextStyles.h2),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: AppTextStyles.caption),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: AppSpacing.sm),
          trailing!,
        ],
      ],
    );
  }
}
