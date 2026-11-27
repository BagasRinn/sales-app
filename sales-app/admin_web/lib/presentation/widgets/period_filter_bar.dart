import 'package:flutter/material.dart';

import '../../core/design_system.dart';
import '../../data/models/branch_report.dart';
import 'analytics/sales_analytics_models.dart';

/// Filter periode dengan tampilan yang sama seperti Dashboard:
/// dropdown cabang + tombol bulan sebelumnya/berikutnya + pemilih bulan.
class PeriodFilterBar extends StatelessWidget {
  const PeriodFilterBar({
    super.key,
    required this.month,
    required this.enabled,
    required this.showBranchFilter,
    required this.branchOptions,
    required this.selectedBranch,
    required this.onBranchChanged,
    required this.onPrevious,
    required this.onNext,
    required this.onPick,
  });

  final DateTime month;
  final bool enabled;
  final bool showBranchFilter;
  final List<BranchOption> branchOptions;
  final String? selectedBranch;
  final ValueChanged<String?> onBranchChanged;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (showBranchFilter)
          BranchFilterDropdown(
            options: branchOptions,
            selected: selectedBranch,
            enabled: enabled,
            onChanged: onBranchChanged,
          ),
        MonthNavSelector(
          month: month,
          enabled: enabled,
          onPrevious: onPrevious,
          onNext: onNext,
          onPick: onPick,
        ),
      ],
    );
  }
}

/// Navigasi bulan: `‹  [November 2026 ▾]  ›`.
class MonthNavSelector extends StatelessWidget {
  const MonthNavSelector({
    super.key,
    required this.month,
    required this.enabled,
    required this.onPrevious,
    required this.onNext,
    required this.onPick,
  });

  final DateTime month;
  final bool enabled;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PeriodNavButton(
          icon: Icons.chevron_left,
          tooltip: 'Bulan sebelumnya',
          onPressed: enabled ? onPrevious : null,
        ),
        const SizedBox(width: AppSpacing.sm),
        Material(
          color: AppColors.surface,
          borderRadius: AppRadius.md,
          child: InkWell(
            onTap: enabled ? onPick : null,
            borderRadius: AppRadius.md,
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                borderRadius: AppRadius.md,
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(formatMonthLong(month), style: AppTextStyles.h3),
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(
                    Icons.arrow_drop_down,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        PeriodNavButton(
          icon: Icons.chevron_right,
          tooltip: 'Bulan berikutnya',
          onPressed: enabled ? onNext : null,
        ),
      ],
    );
  }
}

/// Dropdown cabang dengan ikon bank, lebar tetap seperti Dashboard.
class BranchFilterDropdown extends StatelessWidget {
  const BranchFilterDropdown({
    super.key,
    required this.options,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final List<BranchOption> options;
  final String? selected;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final value = (selected == null || selected!.isEmpty) ? '' : selected!;
    final known = value.isEmpty || options.any((b) => b.code == value);

    return Tooltip(
      message: 'Filter cabang',
      child: Container(
        width: 194,
        height: 40,
        padding: const EdgeInsets.only(left: 10, right: 4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.md,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.account_balance_outlined,
              size: 16,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: value,
                  isDense: true,
                  isExpanded: true,
                  borderRadius: AppRadius.md,
                  menuMaxHeight: 320,
                  iconSize: 18,
                  style: AppTextStyles.h3,
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text(
                        'Semua cabang',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Keep the current selection visible even if the branch
                    // list failed to load or the branch became inactive.
                    if (!known)
                      DropdownMenuItem(
                        value: value,
                        child: Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ...options.map(
                      (b) => DropdownMenuItem(
                        value: b.code,
                        child: Text(
                          b.nama.isEmpty ? b.code : b.nama,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: enabled
                      ? (next) => onChanged(
                          next == null || next.isEmpty ? null : next,
                        )
                      : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tombol persegi 40×40 untuk navigasi bulan.
class PeriodNavButton extends StatelessWidget {
  const PeriodNavButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.surface,
        borderRadius: AppRadius.md,
        child: InkWell(
          onTap: onPressed,
          borderRadius: AppRadius.md,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: AppRadius.md,
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(
              icon,
              size: 20,
              color: onPressed == null
                  ? AppColors.textMuted
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Dialog pemilih bulan (tahun + grid 12 bulan).
class MonthPickerDialog extends StatefulWidget {
  const MonthPickerDialog({super.key, required this.initial});

  final DateTime initial;

  @override
  State<MonthPickerDialog> createState() => _MonthPickerDialogState();
}

class _MonthPickerDialogState extends State<MonthPickerDialog> {
  late int _year;

  @override
  void initState() {
    super.initState();
    _year = widget.initial.year;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      title: Row(
        children: [
          const Expanded(child: Text('Pilih periode', style: AppTextStyles.h2)),
          IconButton(
            tooltip: 'Tahun sebelumnya',
            onPressed: () => setState(() => _year--),
            icon: const Icon(Icons.chevron_left, size: 20),
          ),
          Text('$_year', style: AppTextStyles.h3),
          IconButton(
            tooltip: 'Tahun berikutnya',
            onPressed: () => setState(() => _year++),
            icon: const Icon(Icons.chevron_right, size: 20),
          ),
        ],
      ),
      content: SizedBox(
        width: 300,
        child: GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: 1.9,
          children: [
            for (var month = 1; month <= 12; month++)
              _MonthCell(
                label: formatMonthLong(DateTime(_year, month)).split(' ').first,
                selected:
                    widget.initial.year == _year &&
                    widget.initial.month == month,
                onTap: () => Navigator.of(context).pop(DateTime(_year, month)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            final now = DateTime.now();
            Navigator.of(context).pop(DateTime(now.year, now.month));
          },
          child: const Text('Bulan ini'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
      ],
    );
  }
}

class _MonthCell extends StatelessWidget {
  const _MonthCell({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surfaceMuted,
      borderRadius: AppRadius.md,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.md,
        child: Center(
          child: Text(
            label,
            style: AppTextStyles.label.copyWith(
              color: selected ? AppColors.onPrimary : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
