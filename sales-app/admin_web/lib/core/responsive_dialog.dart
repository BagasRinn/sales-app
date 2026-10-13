import 'package:flutter/material.dart';
import 'responsive.dart';

/// Dialog wrapper that adapts to viewport:
///
/// - Mobile (< 600px): full-viewport (width = maxWidth, height = maxHeight).
///   Rounded corners disabled (borderRadius: 0) so it feels like a full-screen sheet.
/// - Tablet/Desktop: max 960x600, 94% of viewport, 16px rounded corners.
///
/// Usage:
/// ```dart
/// showDialog(
///   context: context,
///   builder: (_) => ResponsiveDialog(
///     child: MyDialogBody(...),
///   ),
/// );
/// ```
///
/// For AlertDialog-style (title + content + actions), use [ResponsiveAlertDialog] instead.
class ResponsiveDialog extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final double maxHeight;
  final double desktopWidthFraction;

  const ResponsiveDialog({
    super.key,
    required this.child,
    this.maxWidth = 960,
    this.maxHeight = 600,
    this.desktopWidthFraction = 0.94,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final resp = Responsive.of(constraints.maxWidth);
          final width = resp.isMobile
              ? constraints.maxWidth
              : (constraints.maxWidth * desktopWidthFraction)
                  .clamp(0.0, maxWidth);
          final height = resp.isMobile
              ? constraints.maxHeight
              : (constraints.maxHeight * 0.9).clamp(0.0, maxHeight);
          return Material(
            color: const Color(0xFFF4F7FB), // AppColors.background
            borderRadius: BorderRadius.circular(resp.isMobile ? 0 : 16),
            elevation: 8,
            child: SizedBox(width: width, height: height, child: child),
          );
        },
      ),
    );
  }
}

/// Convenience AlertDialog-style widget wrapped in [ResponsiveDialog].
///
/// - On mobile: title + content scrollable, actions stack vertically as full-width buttons.
/// - On desktop: same as regular AlertDialog (title + content + row of action buttons).
///
/// The [contentMaxWidth] controls the body width (default 420px). On mobile, this is
/// ignored — the body takes full dialog width minus padding.
class ResponsiveAlertDialog extends StatelessWidget {
  final Widget? title;
  final Widget content;
  final List<Widget> actions;
  final double contentMaxWidth;

  const ResponsiveAlertDialog({
    super.key,
    this.title,
    required this.content,
    required this.actions,
    this.contentMaxWidth = 420,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveDialog(
      maxWidth: 640,
      maxHeight: 480,
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final resp = Responsive.of(constraints.maxWidth);
          final effectiveContentWidth = resp.isMobile
              ? constraints.maxWidth - (resp.contentPadding * 2)
              : contentMaxWidth;

          return Padding(
            padding: EdgeInsets.all(resp.contentPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title row + close button
                if (title != null) ...[
                  Row(
                    children: [
                      Expanded(child: title!),
                      if (resp.isMobile)
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          tooltip: 'Tutup',
                          onPressed: () => Navigator.of(context).pop(),
                          constraints: const BoxConstraints(
                            minWidth: 44,
                            minHeight: 44,
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: resp.gap),
                ],
                // Content
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: effectiveContentWidth),
                  child: content,
                ),
                SizedBox(height: resp.sectionGap),
                // Actions
                if (actions.isNotEmpty) ...[
                  if (resp.isMobile)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int i = 0; i < actions.length; i++) ...[
                          if (i > 0) const SizedBox(height: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 44),
                            child: actions[i],
                          ),
                        ],
                      ],
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        for (int i = 0; i < actions.length; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 44),
                            child: actions[i],
                          ),
                        ],
                      ],
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
