import 'package:flutter/widgets.dart';
import '../../core/design_system.dart';
import '../../core/responsive.dart';

class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;

  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final responsive = Responsive.of(constraints.maxWidth);
        final hasActions = actions != null && actions!.isNotEmpty;
        final hasSubtitle = subtitle != null;

        if (responsive.isCompact) {
          return Container(
            padding: EdgeInsets.all(responsive.contentPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    ?leading,
                    if (leading != null) const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: AppTextStyles.headlineSmall.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                if (hasSubtitle)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      subtitle!,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                if (hasActions)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: actions!,
                    ),
                  ),
              ],
            ),
          );
        }

        return Container(
          padding: EdgeInsets.all(responsive.contentPadding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ?leading,
              if (leading != null) const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.headlineSmall.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (hasSubtitle) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (hasActions)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions!,
                ),
            ],
          ),
        );
      },
    );
  }
}
