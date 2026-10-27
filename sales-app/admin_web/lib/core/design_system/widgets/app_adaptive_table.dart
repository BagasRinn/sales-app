import 'package:flutter/material.dart';

import '../app_tokens.dart';
import 'app_card.dart';

class AppTableColumn<T> {
  final String label;
  final Widget Function(T item) cell;
  final bool numeric;
  final double? width;

  const AppTableColumn({
    required this.label,
    required this.cell,
    this.numeric = false,
    this.width,
  });
}

/// Tabel adaptif: `DataTable` di Desktop/Tablet (`>= 600px`) dan daftar
/// `AppCard` vertikal di Mobile, jadi tidak perlu scroll horizontal di HP.
class AppAdaptiveDataView<T> extends StatelessWidget {
  final List<AppTableColumn<T>> columns;
  final List<T> rows;
  final ValueChanged<T>? onRowTap;
  final Widget Function(BuildContext context, T item)? mobileItemBuilder;
  final String emptyText;

  const AppAdaptiveDataView({
    super.key,
    required this.columns,
    required this.rows,
    this.onRowTap,
    this.mobileItemBuilder,
    this.emptyText = 'Belum ada data.',
  });

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xl,
        ),
        child: Center(
          child: Text(emptyText, style: AppTextStyles.bodyMuted),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) return _buildMobile(context);

        return AppCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                showCheckboxColumn: false,
                columns: columns
                    .map(
                      (c) => DataColumn(
                        label: Text(c.label),
                        numeric: c.numeric,
                      ),
                    )
                    .toList(),
                rows: rows
                    .map(
                      (item) => DataRow(
                        onSelectChanged: onRowTap == null
                            ? null
                            : (_) => onRowTap!(item),
                        cells: columns
                            .map(
                              (c) => DataCell(
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: c.width ?? 320,
                                  ),
                                  child: Align(
                                    alignment: c.numeric
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                    child: c.cell(item),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobile(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.sm),
          mobileItemBuilder != null
              ? mobileItemBuilder!(context, rows[i])
              : _buildDefaultMobileCard(rows[i]),
        ],
      ],
    );
  }

  Widget _buildDefaultMobileCard(T item) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onRowTap == null ? null : () => onRowTap!(item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < columns.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 116,
                  child: Text(columns[i].label, style: AppTextStyles.caption),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Align(
                    alignment: columns[i].numeric
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: columns[i].cell(item),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
