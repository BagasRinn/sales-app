import 'package:flutter/material.dart';
import 'package:admin_web/core/design_system.dart';

/// Centered placeholder shown when a list/table is empty.
///
/// Provides a muted icon, a short [title], an optional longer [description],
/// and an optional [action] (typically a button) the user can take to
/// recover from the empty state.
///
/// Designed to be dropped inside a scrollable list, a [Card], or used as
/// the body of a tab — it does not try to fill its parent. Wrap it in a
/// [Center] + [SingleChildScrollView] if you need it centered in a viewport.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: AppTextStyles.headlineSmall.copyWith(
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          if (description != null) ...[
            const SizedBox(height: 8),
            Text(
            description!,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          ],
          if (action != null) ...[
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: action,
            ),
          ],
        ],
      ),
    );
  }
}
