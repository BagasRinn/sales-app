import 'package:flutter/material.dart';
import 'package:admin_web/core/design_system.dart';
import 'package:admin_web/core/responsive.dart';

/// A single button in an [ActionButtonRow].
///
/// Use [primary] for the dominant action (filled); omit it for secondary
/// actions (outlined). Set [destructive] for actions that delete or reject —
/// this colors the button with [AppColors.error].
class ActionButton {
  final Widget label;
  final VoidCallback? onPressed;
  final bool primary;
  final bool destructive;
  final IconData? icon;

  const ActionButton({
    required this.label,
    this.onPressed,
    this.primary = false,
    this.destructive = false,
    this.icon,
  });
}

/// Lays out a list of [ActionButton]s in a row on tablet/desktop and in a
/// stacked column on mobile, so action buttons stay reachable without
/// horizontal scrolling on small viewports.
///
/// - On compact widths (< 600px): buttons stack vertically, each full-width
///   with a 44px minimum tap target and 8px vertical gap.
/// - On medium/expanded widths: buttons sit in a single row with an 8px
///   horizontal gap, aligned by [alignment] (defaults to end-aligned).
class ActionButtonRow extends StatelessWidget {
  final List<ActionButton> actions;
  final MainAxisAlignment alignment;

  const ActionButtonRow({
    super.key,
    required this.actions,
    this.alignment = MainAxisAlignment.end,
  });

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final resp = Responsive.of(constraints.maxWidth);
        if (resp.isMobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: _buildButton(context, actions[i]),
                ),
              ],
            ],
          );
        }
        return Row(
          mainAxisAlignment: alignment,
          children: [
            for (int i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: _buildButton(context, actions[i]),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildButton(BuildContext context, ActionButton action) {
    final isPrimary = action.primary;
    final fg = action.destructive ? AppColors.error : null;
    final bg = action.destructive && isPrimary ? AppColors.error : null;

    final label = DefaultTextStyle(
      style: AppTextStyles.labelLarge.copyWith(
        color: fg ?? (isPrimary ? AppColors.textOnPrimary : AppColors.primaryLight),
      ),
      child: action.label,
    );

    if (isPrimary) {
      final style = FilledButton.styleFrom(
        foregroundColor: fg ?? AppColors.textOnPrimary,
        backgroundColor: bg,
      );
      if (action.icon != null) {
        return FilledButton.icon(
          onPressed: action.onPressed,
          icon: Icon(action.icon, size: 18),
          label: label,
          style: style,
        );
      }
      return FilledButton(
        onPressed: action.onPressed,
        style: style,
        child: label,
      );
    } else {
      final borderColor =
          action.destructive ? AppColors.error : AppColors.primaryLight;
      final style = OutlinedButton.styleFrom(
        foregroundColor: fg,
        side: BorderSide(color: borderColor),
      );
      if (action.icon != null) {
        return OutlinedButton.icon(
          onPressed: action.onPressed,
          icon: Icon(action.icon, size: 18),
          label: label,
          style: style,
        );
      }
      return OutlinedButton(
        onPressed: action.onPressed,
        style: style,
        child: label,
      );
    }
  }
}
