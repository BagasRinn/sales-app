import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/design_system.dart';
import '../../core/responsive.dart';
import '../../data/models/supplier_sales_pivot.dart';
import '../providers/admin_provider.dart';
import '../widgets/period_filter_bar.dart';

class SupplierPerformancePivotTab extends StatefulWidget {
  const SupplierPerformancePivotTab({super.key});

  @override
  State<SupplierPerformancePivotTab> createState() =>
      _SupplierPerformancePivotTabState();
}

class _SupplierPerformancePivotTabState
    extends State<SupplierPerformancePivotTab> {
  DateTime _month = DateTime.now();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  void _load(AdminProvider provider) {
    final start = DateTime(_month.year, _month.month, 1);
    final end = DateTime(_month.year, _month.month + 1, 0);
    provider.loadSupplierSalesPivot(
      from: start,
      to: end,
      branch: provider.isManager && provider.importedSalesBranchFilter != null
          ? provider.importedSalesBranchFilter
          : null,
    );
    if (provider.isManager && provider.branchOptions.isEmpty) {
      provider.loadBranchOptions();
    }
  }

  void _changeMonth(DateTime next) {
    final normalized = DateTime(next.year, next.month);
    if (normalized == _month) return;
    setState(() => _month = normalized);
    _load(context.read<AdminProvider>());
  }

  Future<void> _pickMonth() async {
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (_) => MonthPickerDialog(initial: _month),
    );
    if (picked != null) _changeMonth(picked);
  }

  @override
  Widget build(BuildContext context) => Consumer<AdminProvider>(
    builder: (context, provider, _) {
      if (!_initialized) {
        _initialized = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _load(context.read<AdminProvider>());
        });
      }
      final pivot = provider.supplierSalesPivot;
      final width = MediaQuery.sizeOf(context).width;
      final responsive = Responsive.of(width);
      return SingleChildScrollView(
        padding: EdgeInsets.all(responsive.contentPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performa Sales ke Supplier',
              style: AppTextStyles.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Rekap penjualan per principal dan salesperson dari data import Dashboard.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSubtle,
              ),
            ),
            const SizedBox(height: 16),
            PeriodFilterBar(
              month: _month,
              enabled: !provider.supplierSalesPivotLoading,
              showBranchFilter: provider.isManager,
              branchOptions: provider.branchOptions,
              selectedBranch: provider.importedSalesBranchFilter,
              onBranchChanged: (value) =>
                  provider.setImportedSalesBranchFilter(value),
              onPrevious: () =>
                  _changeMonth(DateTime(_month.year, _month.month - 1)),
              onNext: () =>
                  _changeMonth(DateTime(_month.year, _month.month + 1)),
              onPick: () => _pickMonth(),
            ),
            const SizedBox(height: 18),
            if (provider.supplierSalesPivotLoading && pivot == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (provider.supplierSalesPivotError != null && pivot == null)
              _message(provider.supplierSalesPivotError!, isError: true)
            else if (pivot == null || pivot.rows.isEmpty)
              _message('Belum ada data penjualan untuk periode ini.')
            else
              _supplierCards(pivot),
          ],
        ),
      );
    },
  );

  Widget _message(String text, {bool isError = false}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: isError ? AppColors.danger : AppColors.textSecondary,
      ),
    ),
  );

  Widget _supplierCards(SupplierSalesPivot pivot) {
    final columns = pivot.columns;
    return Column(
      children: [
        for (final row in pivot.rows)
          AppCard(
            margin: const EdgeInsets.only(bottom: 12),
            clipBehavior: Clip.none,
            child: AppStickyHeader(
              header: _buildSupplierCardHeader(row, columns),
              child: _buildSupplierCardBody(row, columns),
            ),
          ),
      ],
    );
  }

  Widget _buildSupplierCardHeader(
    SupplierSalesPivotRow row,
    List<SupplierSalesPivotColumn> columns,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final count = constraints.maxWidth < 420 ? 1 : 2;
          final gap = 8.0;
          final itemWidth = (constraints.maxWidth - gap * (count - 1)) / count;
          final labels = [for (final column in columns) column.name, 'TOTAL'];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      row.supplier,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      row.channel,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 22),
              Wrap(
                spacing: gap,
                runSpacing: 8,
                children: [
                  for (final label in labels)
                    SizedBox(
                      width: itemWidth,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: label == 'TOTAL'
                              ? AppColors.primarySoft
                              : AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: label == 'TOTAL'
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: label == 'TOTAL'
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSupplierCardBody(
    SupplierSalesPivotRow row,
    List<SupplierSalesPivotColumn> columns,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final count = constraints.maxWidth < 420 ? 1 : 2;
          final gap = 8.0;
          final itemWidth = (constraints.maxWidth - gap * (count - 1)) / count;
          final entries = [
            for (final column in columns)
              MapEntry(column.name, row.cells[column.name]?.value ?? 0),
            MapEntry('TOTAL', row.total.value),
          ];
          return Wrap(
            spacing: gap,
            runSpacing: 8,
            children: entries.map((entry) {
              final isTotal = entry.key == 'TOTAL';
              return SizedBox(
                width: itemWidth,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: isTotal ? AppColors.primarySoft : AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      entry.value == 0 ? '-' : _format(entry.value),
                      maxLines: 1,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isTotal ? FontWeight.w700 : FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  String _format(int amount) => NumberFormat('#,##0', 'id_ID').format(amount);
}
