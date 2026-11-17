import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/design_system.dart';
import '../../core/responsive.dart';
import '../../data/models/supplier_sales_pivot.dart';
import '../providers/admin_provider.dart';

class SupplierPerformancePivotTab extends StatefulWidget {
  const SupplierPerformancePivotTab({super.key});

  @override
  State<SupplierPerformancePivotTab> createState() =>
      _SupplierPerformancePivotTabState();
}

class _SupplierPerformancePivotTabState
    extends State<SupplierPerformancePivotTab> {
  late DateTime _from;
  late DateTime _to;
  String _branch = '';
  String _metric = 'value';
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month, 1);
    _to = DateTime(now.year, now.month + 1, 0);
  }

  void _load(AdminProvider provider) {
    provider.loadSupplierSalesPivot(
      from: _from,
      to: _to,
      branch: provider.isManager && _branch.isNotEmpty ? _branch : null,
    );
    if (provider.isManager && provider.branchOptions.isEmpty) {
      provider.loadBranchOptions();
    }
  }

  Future<void> _pickMonth(AdminProvider provider) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _from,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Pilih bulan',
    );
    if (picked == null) return;
    setState(() {
      _from = DateTime(picked.year, picked.month, 1);
      _to = DateTime(picked.year, picked.month + 1, 0);
    });
    _load(provider);
  }

  Future<void> _pickRange(AdminProvider provider) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _from, end: _to),
      helpText: 'Pilih rentang tanggal',
    );
    if (picked == null) return;
    setState(() {
      _from = picked.start;
      _to = picked.end;
    });
    _load(provider);
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
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _pickMonth(provider),
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(DateFormat('MMMM yyyy', 'id_ID').format(_from)),
                ),
                OutlinedButton.icon(
                  onPressed: () => _pickRange(provider),
                  icon: const Icon(Icons.date_range_outlined),
                  label: const Text('Rentang tanggal'),
                ),
                if (provider.isManager)
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String>(
                      initialValue: _branch,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Cabang',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('Semua cabang'),
                        ),
                        ...provider.branchOptions.map(
                          (branch) => DropdownMenuItem(
                            value: branch.code,
                            child: Text(
                              branch.nama,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() => _branch = value ?? '');
                        _load(provider);
                      },
                    ),
                  ),
              ],
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
            else ...[
              _summaryCards(pivot, responsive.contentPadding),
              const SizedBox(height: 18),
              _buildMetricPicker(),
              const SizedBox(height: 12),
              _supplierCards(pivot),
            ],
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

  Widget _summaryCards(SupplierSalesPivot pivot, double padding) {
    final suppliers = pivot.rows.map((r) => r.supplier).toSet().length;
    final topSales = pivot.columns.isEmpty ? null : pivot.columns.first;
    final cards = [
      _SummaryCard(
        label: 'Total VALUES',
        value: _format(pivot.total.value),
        icon: Icons.payments_outlined,
      ),
      _SummaryCard(
        label: 'Total MARGIN',
        value: _format(pivot.total.margin),
        icon: Icons.trending_up,
      ),
      _SummaryCard(
        label: 'Total QTY',
        value: _format(pivot.total.qty),
        icon: Icons.inventory_2_outlined,
      ),
      _SummaryCard(
        label: 'Principal',
        value: '$suppliers',
        icon: Icons.business_outlined,
      ),
      _SummaryCard(
        label: 'Top Sales',
        value: topSales?.name ?? '-',
        subtitle: topSales == null ? null : _format(topSales.total.value),
        icon: Icons.person_outline,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 1250
            ? 5
            : constraints.maxWidth > 820
            ? 3
            : 2;
        final gap = 10.0;
        final cardWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: cards
              .map((card) => SizedBox(width: cardWidth, child: card))
              .toList(),
        );
      },
    );
  }

  Widget _buildMetricPicker() => SegmentedButton<String>(
    segments: const [
      ButtonSegment(value: 'value', label: Text('VALUES')),
      ButtonSegment(value: 'margin', label: Text('MARGIN')),
      ButtonSegment(value: 'qty', label: Text('QTY')),
    ],
    selected: {_metric},
    onSelectionChanged: (value) => setState(() => _metric = value.first),
  );

  Widget _supplierCards(SupplierSalesPivot pivot) {
    final columns = pivot.columns;
    return Column(
      children: [
        for (final row in pivot.rows)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
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
                LayoutBuilder(
                  builder: (context, constraints) {
                    final count = constraints.maxWidth < 420 ? 1 : 2;
                    final gap = 8.0;
                    final itemWidth =
                        (constraints.maxWidth - gap * (count - 1)) / count;
                    final entries = [
                      for (final column in columns)
                        MapEntry(
                          column.name,
                          row.cells[column.name]?.forMetric(_metric) ?? 0,
                        ),
                      MapEntry('TOTAL', row.total.forMetric(_metric)),
                    ];
                    return Wrap(
                      spacing: gap,
                      runSpacing: 8,
                      children: entries.map((entry) {
                        final isTotal = entry.key == 'TOTAL';
                        return Container(
                          width: itemWidth,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: isTotal
                                ? AppColors.primarySoft
                                : AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  entry.key,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isTotal
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isTotal
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                entry.value == 0 ? '-' : _format(entry.value),
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isTotal
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _format(int amount) => NumberFormat('#,##0', 'id_ID').format(amount);
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.value,
    this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 108),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border.all(color: AppColors.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 17, color: AppColors.primary),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSubtle,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            style: const TextStyle(fontSize: 11, color: AppColors.textSubtle),
          ),
      ],
    ),
  );
}
