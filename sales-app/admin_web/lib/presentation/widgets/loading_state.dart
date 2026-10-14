import 'package:flutter/material.dart';

import '../../core/design_system.dart';

/// Centered loading indicator for tabs, lists, and cards.
///
/// Default mode shows a [CircularProgressIndicator] (32px) with an optional
/// [label] beneath it. Pass [useSkeleton] = true to render a single rounded
/// light-gray box whose opacity pulses, intended as a placeholder when a
/// screen is waiting for data and you want a calmer look than a spinner.
///
/// Designed to be dropped inside a [Center] + [SingleChildScrollView] when
/// the parent should fill the viewport; otherwise it sizes to its content.
class LoadingState extends StatelessWidget {
  final String? label;
  final bool useSkeleton;
  final double? height;
  final double? width;

  const LoadingState({
    super.key,
    this.label,
    this.useSkeleton = false,
    this.height,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: useSkeleton
          ? _SkeletonBox(height: height, width: width)
          : _Spinner(label: label),
    );
  }
}

class _Spinner extends StatelessWidget {
  final String? label;

  const _Spinner({this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          if (label != null) ...[
            const SizedBox(height: 12),
            Text(
              label!,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Pulses a rounded light-gray box to suggest content is loading.
///
/// Animation is driven by an [AnimationController] repeating in reverse so
/// the box smoothly fades between 0.5 and 0.9 opacity. Defaults to a 24px
/// tall row that fills the available width; pass [height] and [width] to
/// match a specific row layout.
class _SkeletonBox extends StatefulWidget {
  final double? height;
  final double? width;

  const _SkeletonBox({this.height, this.width});

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Opacity(
          opacity: 0.5 + (_controller.value * 0.4),
          child: Container(
            height: widget.height ?? 24,
            width: widget.width,
            decoration: BoxDecoration(
              color: AppColors.borderLight,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.textMuted.withValues(alpha: 0.1),
              ),
            ),
          ),
        );
      },
    );
  }
}
