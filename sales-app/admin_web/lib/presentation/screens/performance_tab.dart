import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/design_system.dart';
import '../../core/responsive.dart';
import '../../data/models/sales_performance.dart';
import '../../data/models/sales_target.dart';
import '../../data/models/supplier_performance.dart';
import '../providers/admin_provider.dart';
import '../widgets/supplier_target_edit_dialog.dart';

String _fmt(int amount) =>
    NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0).format(amount);

class PerformanceTab extends StatefulWidget {
  const PerformanceTab({super.key});

  @override
  State<PerformanceTab> createState() => _PerformanceTabState();
}

class _PerformanceTabState extends State<PerformanceTab> {
  bool _initialized = false;

  // Period filter state
  // Default: bulan berjalan (WITA)
  late DateTime _fromDate;
  late DateTime _toDate;
  bool _useCustomRange = false;

  @override
  void initState() {
    super.initState();
    _initPeriod();
  }

  void _initPeriod() {
    final now = DateTime.now();
    // Default: current month
    _fromDate = DateTime(now.year, now.month, 1);
    _toDate = DateTime(now.year, now.month + 1, 0);
  }

  void _loadData() {
    final provider = context.read<AdminProvider>();
    final ym = _yearMonth(_fromDate);
    provider.loadSalesPerformance(from: _fromDate, to: _toDate);
    provider.loadSalesTargets(
      period: '${_fromDate.year}-${_fromDate.month.toString().padLeft(2, '0')}',
    );
    provider.loadSupplierPerformance(yearMonth: ym);
  }

  String _yearMonth(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Pilih bulan',
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null) {
      setState(() {
        _useCustomRange = false;
        _fromDate = DateTime(picked.year, picked.month, 1);
        _toDate = DateTime(picked.year, picked.month + 1, 0);
      });
      _loadData();
    }
  }

  Future<void> _pickCustomRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Pilih rentang tanggal',
      initialDateRange: DateTimeRange(start: _fromDate, end: _toDate),
    );
    if (picked != null) {
      setState(() {
        _useCustomRange = true;
        _fromDate = picked.start;
        _toDate = picked.end;
      });
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminProvider>(
      builder: (context, provider, _) {
        // Initial load
        if (!_initialized) {
          _initialized = true;
          WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
        }

        final loading = provider.performanceLoading;
        final targetsLoading = provider.targetsLoading;
        final perfList = provider.performanceList;
        final sortBy = provider.performanceSort;

        final sorted = List<SalesPerformance>.from(perfList)
          ..sort((a, b) {
            if (sortBy == 'order_count') {
              return b.orderCount.compareTo(a.orderCount);
            }
            return b.revenue.compareTo(a.revenue);
          });

        final currentPeriod = '${_fromDate.year}-${_fromDate.month.toString().padLeft(2, '0')}';

        return LayoutBuilder(
          builder: (context, constraints) {
            final resp = Responsive.of(constraints.maxWidth);
            return SingleChildScrollView(
              padding: EdgeInsets.all(resp.contentPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section: Period Filter + Sort
              _buildPeriodFilterSection(),
              const SizedBox(height: 24),

              // Section 1: KPI per Supplier — revenue & target with auto-rollover
              _buildSectionTitle('KPI per Supplier'),
              const SizedBox(height: 12),
              _buildSupplierPerformanceTable(provider),
              const SizedBox(height: 32),

              // Section 2: Leaderboard
              _buildSectionTitle('Leaderboard'),
              const SizedBox(height: 12),
              _buildLeaderboard(sorted, provider, sortBy, loading),
              const SizedBox(height: 32),

              // Section 3: Target & Incentive
              _buildSectionTitle('Target & Incentive'),
              const SizedBox(height: 12),
              _buildTargetSection(sorted, provider, currentPeriod, targetsLoading),
            ],
          ),
            );
          },
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildPeriodFilterSection() {
    final monthLabel = DateFormat('MMMM yyyy', 'id_ID').format(_fromDate);
    final rangeLabel =
        '${DateFormat('dd MMM yyyy', 'id_ID').format(_fromDate)} - '
        '${DateFormat('dd MMM yyyy', 'id_ID').format(_toDate)}';

    return Row(
      children: [
        // Monthly picker
        OutlinedButton.icon(
          onPressed: _pickMonth,
          icon: const Icon(Icons.calendar_month, size: 18),
          label: Text(_useCustomRange ? rangeLabel : monthLabel),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryLight,
            backgroundColor: AppColors.primaryLight.withValues(alpha: 0.08),
            side: BorderSide(color: AppColors.primaryLight.withValues(alpha: 0.4)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
        const SizedBox(width: 8),
        // Custom range toggle
        TextButton.icon(
          onPressed: _pickCustomRange,
          icon: const Icon(Icons.date_range, size: 18),
          label: const Text('Custom Range'),
          style: TextButton.styleFrom(
            foregroundColor: _useCustomRange ? Colors.white : AppColors.textMuted,
            backgroundColor: _useCustomRange ? AppColors.primaryLight : null,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _buildSupplierPerformanceTable(AdminProvider provider) {
    if (provider.supplierPerformanceLoading) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final rows = provider.supplierPerformance;
    if (rows.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Text(
            'Belum ada data supplier untuk periode ini.',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      );
    }

    final canEdit = provider.isAdmin || provider.isSupervisor;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      // Use Table (not DataTable) so columns stretch to fill the parent
      // width via FlexColumnWidth — DataTable sizes each column to its
      // content and leaves white space on the right on wide screens.
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(3), // Supplier (long text)
          1: FlexColumnWidth(2), // Target
          2: FlexColumnWidth(2), // Value
          3: FlexColumnWidth(1.5), // Pencapaian
          4: FixedColumnWidth(56), // Edit icon
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.border, width: 1),
              ),
            ),
            children: [
              const _TableHeaderCell('Supplier', align: TextAlign.left),
              const _TableHeaderCell('Target', align: TextAlign.right),
              const _TableHeaderCell('Value', align: TextAlign.right),
              const _TableHeaderCell('Pencapaian', align: TextAlign.right),
              const _TableHeaderCell(''),
            ],
          ),
          ...rows.map((row) {
            final pencapaianText = row.pencapaian == null
                ? '—'
                : '${row.pencapaian!.toStringAsFixed(0)}%';
            Color pencapaianColor = AppColors.textMuted;
            FontWeight pencapaianWeight = FontWeight.normal;
            if (row.pencapaian != null) {
              if (row.pencapaian! >= 100) {
                // 100%+ → hijau (target tercapai)
                pencapaianColor = AppColors.success;
                pencapaianWeight = FontWeight.bold;
              } else if (row.pencapaian! >= 81) {
                // 81% - 99% → kuning (mendekati target)
                pencapaianColor = AppColors.warning;
              } else {
                // 0% - 80% → merah (jauh dari target)
                pencapaianColor = AppColors.error;
              }
            }
            return TableRow(
              children: [
                _TableBodyCell(
                  Text(
                    row.supplierName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  align: TextAlign.left,
                ),
                _TableBodyCell(
                  Text('Rp ${_fmt(row.target)}'),
                  align: TextAlign.right,
                ),
                _TableBodyCell(
                  Text('Rp ${_fmt(row.value)}'),
                  align: TextAlign.right,
                ),
                _TableBodyCell(
                  Text(
                    pencapaianText,
                    style: TextStyle(
                      color: pencapaianColor,
                      fontWeight: pencapaianWeight,
                    ),
                  ),
                  align: TextAlign.right,
                ),
                _TableBodyCell(
                  canEdit
                      ? IconButton(
                          icon: const Icon(Icons.edit, size: 18),
                          tooltip: 'Edit target',
                          onPressed: () => _openTargetDialog(provider, row),
                        )
                      : const SizedBox.shrink(),
                  align: TextAlign.center,
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Future<void> _openTargetDialog(
    AdminProvider provider,
    SupplierPerformanceRow row,
  ) async {
    final ym = _yearMonth(_fromDate);
    await showSupplierTargetEditDialog(
      context,
      provider,
      supplierName: row.supplierName,
      period: ym,
    );
  }

  Widget _buildLeaderboard(
    List<SalesPerformance> sorted,
    AdminProvider provider,
    String sortBy,
    bool loading,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          : sorted.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'Tidak ada data leaderboard.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Sort toggle header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: AppColors.border),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Text(
                            'Urutkan:',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Revenue', style: TextStyle(fontSize: 12)),
                            selected: sortBy == 'revenue',
                            onSelected: (_) => provider.setPerformanceSort('revenue'),
                            selectedColor: AppColors.primaryLight,
                            backgroundColor: AppColors.background,
                            side: BorderSide(
                              color: sortBy == 'revenue'
                                  ? AppColors.primaryLight
                                  : AppColors.border,
                            ),
                            labelStyle: TextStyle(
                              color: sortBy == 'revenue'
                                  ? Colors.white
                                  : AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('Order', style: TextStyle(fontSize: 12)),
                            selected: sortBy == 'order_count',
                            onSelected: (_) => provider.setPerformanceSort('order_count'),
                            selectedColor: AppColors.primaryLight,
                            backgroundColor: AppColors.background,
                            side: BorderSide(
                              color: sortBy == 'order_count'
                                  ? AppColors.primaryLight
                                  : AppColors.border,
                            ),
                            labelStyle: TextStyle(
                              color: sortBy == 'order_count'
                                  ? Colors.white
                                  : AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Table header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: const BoxDecoration(
                        color: AppColors.borderLight,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(11),
                          topRight: Radius.circular(11),
                        ),
                      ),
                      child: const Row(
                        children: [
                          SizedBox(width: 36, child: Text('#', style: _thStyle)),
                          Expanded(flex: 2, child: Text('Nama', style: _thStyle)),
                          Expanded(child: Text('Order', style: _thStyle)),
                          Expanded(child: Text('Revenue', style: _thStyle)),
                          Expanded(child: Text('Submission', style: _thStyle)),
                        ],
                      ),
                    ),
                    // Rows
                    ...sorted.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final perf = entry.value;
                      final rowBg = idx % 2 == 0
                          ? AppColors.surface
                          : AppColors.borderLight.withValues(alpha: 0.5);

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: rowBg,
                          border: const Border(
                            bottom: BorderSide(color: AppColors.border),
                          ),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 36,
                              child: Text(
                                '#${idx + 1}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: idx == 0
                                      ? AppColors.primaryLight
                                      : AppColors.textMuted,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                perf.displayName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                perf.orderCount.toString(),
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                _fmt(perf.revenue),
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                perf.submissionCount.toString(),
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
    );
  }

  static const _thStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
  );

  Widget _buildTargetSection(
    List<SalesPerformance> sorted,
    AdminProvider provider,
    String currentPeriod,
    bool loading,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: loading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          : sorted.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'Tidak ada sales untuk diset target.',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: const BoxDecoration(
                        color: AppColors.borderLight,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(11),
                          topRight: Radius.circular(11),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Expanded(flex: 2, child: Text('Nama', style: _thStyle)),
                          const Expanded(child: Text('Tipe Target', style: _thStyle)),
                          const Expanded(child: Text('Nilai Target', style: _thStyle)),
                          const Expanded(child: Text('Incentive', style: _thStyle)),
                          const SizedBox(width: 80, child: Text('Aksi', style: _thStyle)),
                        ],
                      ),
                    ),
                    // Rows
                    ...sorted.map((perf) {
                      final target = provider.getTargetFor(perf.userId, currentPeriod);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: AppColors.border)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                perf.displayName,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                target?.isRevenue == true
                                    ? 'Revenue'
                                    : target?.isOrderCount == true
                                        ? 'Order Count'
                                        : '-',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                target != null
                                    ? (target.isRevenue ? _fmt(target.targetValue) : target.targetValue.toString())
                                    : '-',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                target != null ? _fmt(target.incentiveAmount) : '-',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: target != null && target.incentiveAmount > 0
                                      ? AppColors.success
                                      : AppColors.textMuted,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 80,
                              child: TextButton(
                                onPressed: () => _showTargetDialog(
                                  context,
                                  provider,
                                  perf,
                                  currentPeriod,
                                  target,
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.primaryLight,
                                  padding: EdgeInsets.zero,
                                ),
                                child: Text(
                                  target == null ? 'Set Target' : 'Edit',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
    );
  }

  Future<void> _showTargetDialog(
    BuildContext context,
    AdminProvider provider,
    SalesPerformance perf,
    String currentPeriod,
    SalesTarget? existing,
  ) async {
    final targetType = (existing?.isRevenue ?? false) ? 'REVENUE' : 'ORDER_COUNT';
    final targetValueController = TextEditingController(
      text: existing?.targetValue.toString() ?? '',
    );
    final incentiveController = TextEditingController(
      text: existing?.incentiveAmount.toString() ?? '0',
    );
    final selectedType = ValueNotifier<String>(targetType);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          existing == null
              ? 'Set Target untuk ${perf.displayName}'
              : 'Edit Target ${perf.displayName}',
        ),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Periode: $currentPeriod',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              const Text('Tipe Target', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              ValueListenableBuilder<String>(
                valueListenable: selectedType,
                builder: (_, val, _) => Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Order Count', style: TextStyle(fontSize: 12)),
                      selected: val == 'ORDER_COUNT',
                      onSelected: (_) => selectedType.value = 'ORDER_COUNT',
                      selectedColor: AppColors.primary.withValues(alpha: 0.15),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Revenue', style: TextStyle(fontSize: 12)),
                      selected: val == 'REVENUE',
                      onSelected: (_) => selectedType.value = 'REVENUE',
                      selectedColor: AppColors.primary.withValues(alpha: 0.15),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: targetValueController,
                decoration: InputDecoration(
                  labelText: selectedType.value == 'REVENUE'
                      ? 'Target Revenue (Rp)'
                      : 'Target Order Count',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: incentiveController,
                decoration: const InputDecoration(
                  labelText: 'Incentive / Bonus (Rp)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (result == true) {
      final targetValue = int.tryParse(targetValueController.text) ?? 0;
      final incentive = int.tryParse(incentiveController.text) ?? 0;
      final ok = await provider.updateSalesTarget(
        userId: perf.userId,
        period: currentPeriod,
        targetType: selectedType.value,
        targetValue: targetValue,
        incentiveAmount: incentive,
      );
      if (mounted) {
        // ignore: use_build_context_synchronously — mounted is State.mounted, context is State.context
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? 'Target berhasil disimpan' : 'Gagal menyimpan target'),
            backgroundColor: ok ? AppColors.success : AppColors.error,
          ),
        );
      }
    }
  }
}

/// Header cell for the per-supplier performance Table. Pads and aligns its
/// label; bold font matches the original DataTable heading style.
class _TableHeaderCell extends StatelessWidget {
  final String text;
  final TextAlign align;
  const _TableHeaderCell(this.text, {this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Text(
        text,
        textAlign: align,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

/// Body cell for the per-supplier performance Table. Pads the child and
/// aligns it. Keeps default row height consistent.
class _TableBodyCell extends StatelessWidget {
  final Widget child;
  final TextAlign align;
  const _TableBodyCell(this.child, {this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Align(
        alignment: align == TextAlign.right
            ? Alignment.centerRight
            : align == TextAlign.center
                ? Alignment.center
                : Alignment.centerLeft,
        child: child,
      ),
    );
  }
}
