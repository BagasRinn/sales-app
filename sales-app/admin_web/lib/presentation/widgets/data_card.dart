import 'package:flutter/material.dart';
import 'package:admin_web/core/design_system.dart';

/// Label + value pair used in [DataCard.fields].
///
/// Pass [value] for plain text rendering, or [valueWidget] when the value
/// needs custom styling (e.g. chips, status pills, formatted numbers). If
/// both are provided, [valueWidget] wins.
class DataField {
  final String label;
  final String? value;
  final Widget? valueWidget;
  final int flex;

  const DataField({
    required this.label,
    this.value,
    this.valueWidget,
    this.flex = 1,
  });
}

/// Compact summary card showing a title, optional subtitle, a list of
/// label/value fields, and an optional action row.
///
/// The card itself does not handle responsive width — callers place it in a
/// [Wrap] (1 per row in compact, 2 per row in medium+) to get the desired
/// grid behavior.
class DataCard extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final List<Widget>? badges;
  final List<DataField> fields;
  final List<Widget>? actions;
  final VoidCallback? onTap;

  const DataCard({
    super.key,
    this.title,
    this.subtitle,
    this.badges,
    this.fields = const [],
    this.actions,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasHeader = title != null || subtitle != null || (badges?.isNotEmpty ?? false);

    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasHeader) _buildHeader(),
          if (hasHeader && fields.isNotEmpty) const SizedBox(height: 12),
          if (fields.isNotEmpty) _buildFields(),
          if (actions != null && actions!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildActions(),
          ],
        ],
      ),
    );

    final card = Card(
      clipBehavior: onTap != null ? Clip.antiAlias : Clip.none,
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              child: content,
            )
          : content,
    );

    return card;
  }

  Widget _buildHeader() {
    final titleStyle = AppTextStyles.titleLarge;
    final subtitleStyle = AppTextStyles.bodySmall;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (title != null)
                Text(
                  title!,
                  style: titleStyle,
                ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: subtitleStyle,
                ),
              ],
            ],
          ),
        ),
        if (badges != null && badges!.isNotEmpty) ...[
          const SizedBox(width: 12),
          Flexible(
            child: Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: badges!,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFields() {
    // 2-col grid using Wrap. Each field gets ~half the card width. flex is
    // currently fixed to 1 here because Wrap distributes children into rows
    // of equal slots — the prop is kept on [DataField] so callers can build
    // their own layouts later if needed.
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: fields.map((f) => _buildField(f)).toList(),
    );
  }

  Widget _buildField(DataField field) {
    return SizedBox(
      width: _fieldWidth,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            field.label,
            style: AppTextStyles.labelMedium.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 2),
          if (field.valueWidget != null)
            field.valueWidget!
          else if (field.value != null)
            Text(
              field.value!,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
            ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        for (var i = 0; i < actions!.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 36),
            child: actions![i],
          ),
        ],
      ],
    );
  }

  // Half the card width (minus the 12px gap) so two fields fit per row when
  // the card is given a sensible width. Caller can adjust the card's
  // overall width via the parent [Wrap].
  static const double _fieldWidth = 200;
}
