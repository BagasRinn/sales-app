import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design_system.dart';

class AppResponsive {
  AppResponsive._();

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 600;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return width >= 600 && width < 1024;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 1024;

  static EdgeInsets pagePadding(BuildContext context) {
    if (isDesktop(context)) return const EdgeInsets.all(24);
    if (isTablet(context)) return const EdgeInsets.all(20);
    return const EdgeInsets.all(16);
  }
}

class AppResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int desktopColumns;
  final int tabletColumns;
  final int mobileColumns;
  final double spacing;

  const AppResponsiveGrid({
    super.key,
    required this.children,
    this.desktopColumns = 4,
    this.tabletColumns = 2,
    this.mobileColumns = 2,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 960
            ? desktopColumns
            : constraints.maxWidth >= 540
            ? tabletColumns
            : mobileColumns;
        final itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children)
              SizedBox(width: itemWidth, child: child),
          ],
        );
      },
    );
  }
}

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: AppColors.border),
    );

    return Padding(
      padding: margin,
      child: Material(
        color: AppColors.surface,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

enum AppButtonVariant { primary, secondary, outline, ghost, danger }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;
  final AppButtonVariant variant;

  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
    this.variant = AppButtonVariant.primary,
  });

  @override
  Widget build(BuildContext context) {
    final content = isLoading
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              Text(label),
            ],
          );

    final button = switch (variant) {
      AppButtonVariant.primary => FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        child: content,
      ),
      AppButtonVariant.secondary => FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primarySoft,
          foregroundColor: AppColors.primary,
        ),
        child: content,
      ),
      AppButtonVariant.outline => OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.border),
        ),
        child: content,
      ),
      AppButtonVariant.ghost => TextButton(
        onPressed: isLoading ? null : onPressed,
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
        child: content,
      ),
      AppButtonVariant.danger => FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.error,
          foregroundColor: Colors.white,
        ),
        child: content,
      ),
    };

    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      height: 48,
      child: button,
    );
  }
}

class AppInput extends StatelessWidget {
  final String label;
  final String? hintText;
  final TextEditingController? controller;
  final String? initialValue;
  final FocusNode? focusNode;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final GestureTapCallback? onTap;
  final bool readOnly;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLines;
  final bool enabled;
  final Widget? prefixIcon;
  final Widget? suffixIcon;

  const AppInput({
    super.key,
    required this.label,
    this.hintText,
    this.controller,
    this.initialValue,
    this.focusNode,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.onTap,
    this.readOnly = false,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.maxLines = 1,
    this.enabled = true,
    this.prefixIcon,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelMedium),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          initialValue: initialValue,
          focusNode: focusNode,
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
          onTap: onTap,
          readOnly: readOnly,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          enabled: enabled,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}

class AppChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onSelected;
  final IconData? icon;
  final int? count;

  const AppChoiceChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onSelected,
    this.icon,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.primary : AppColors.textSecondary;
    final borderColor = selected ? AppColors.primary : AppColors.border;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.primarySoft : AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onSelected,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor, width: selected ? 2 : 1),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: foreground),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: foreground,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  if (count != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      '$count',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color accentColor;
  final Color? iconBackgroundColor;
  final String? subtitle;
  final String? extraText;

  const AppStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.accentColor = AppColors.primary,
    this.iconBackgroundColor,
    this.subtitle,
    this.extraText,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color:
                      iconBackgroundColor ?? accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentColor, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: AppTextStyles.headlineSmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                maxLines: 1,
              ),
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            Text(subtitle!, style: AppTextStyles.bodySmall),
          ],
          if (extraText != null) ...[
            const SizedBox(height: 4),
            Text(
              extraText!,
              style: AppTextStyles.bodySmall.copyWith(
                color: accentColor,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class AppPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.headlineLarge),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: AppTextStyles.bodyMedium),
        ],
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading,
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: actions),
              ],
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: heading),
            if (actions.isNotEmpty) Wrap(spacing: 8, children: actions),
          ],
        );
      },
    );
  }
}
