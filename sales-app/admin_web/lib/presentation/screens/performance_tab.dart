import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/design_system.dart';
import '../../core/responsive.dart';
import '../../core/responsive_dialog.dart';
import '../../data/models/sales_performance.dart';
import '../../data/models/sales_target.dart';
import '../../data/models/supplier_performance.dart';
import '../providers/admin_provider.dart';
import '../widgets/supplier_target_edit_dialog.dart';

String _fmt(int amount) => NumberFormat.currency(
  locale: 'id_ID',
  symbol: '',
  decimalDigits: 0,
).format(amount);

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

  // Pagination: KPI per Supplier
  int _supplierPage = 1;
  static const int _supplierPageSize = 10;

  // Branch scope for KPI per Supplier — MANAGER only. '' = semua cabang.
  String _branchFilter = '';

  // Filter status supplier di KPI: null = semua, true = aktif, false = non-aktif.
  bool? _supplierActiveFilter;

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
    setState(() => _supplierPage = 1);
    final provider = context.read<AdminProvider>();
    final ym = _yearMonth(_fromDate);
    provider.loadSalesPerformance(from: _fromDate, to: _toDate);
    provider.loadSalesTargets(
      period: '${_fromDate.year}-${_fromDate.month.toString().padLeft(2, '0')}',
    );
    if (provider.isManager) {
      if (provider.branchOptions.isEmpty) provider.loadBranchOptions();
      provider.loadSupplierPerformance(
        yearMonth: ym,
        branch: _branchFilter.isEmpty ? null : _branchFilter,
      );
    } else {
      provider.loadSupplierPerformance(yearMonth: ym);
    }
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

        final currentPeriod =
            '${_fromDate.year}-${_fromDate.month.toString().padLeft(2, '0')}';

        return LayoutBuilder(
          builder: (context, constraints) {
            final resp = Responsive.of(constraints.maxWidth);
            return SingleChildScrollView(
              padding: EdgeInsets.all(resp.contentPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section: Period Filter + Sort
                  _buildPeriodFilterSection(provider),
                  if (_useCustomRange) ...[
                    const SizedBox(height: 8),
                    Text(
                      'KPI per Supplier dihitung per bulan — memakai '
                      '${DateFormat('MMMM yyyy', 'id_ID').format(_fromDate)}.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Section 1: KPI per Supplier — revenue & target with auto-rollover
                  _buildSectionTitle('KPI per Supplier'),
                  if (provider.isManager) ...[
                    const SizedBox(height: 4),
                    Text(
                      _branchLabel(provider),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
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
                  _buildTargetSection(
                    sorted,
                    provider,
                    currentPeriod,
                    targetsLoading,
                  ),
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

  String _branchLabel(AdminProvider provider) {
    if (_branchFilter.isEmpty) {
      return 'Semua cabang (target dijumlah per supplier)';
    }
    for (final b in provider.branchOptions) {
      if (b.code == _branchFilter) return b.nama;
    }
    return _branchFilter;
  }

  Widget _buildPeriodFilterSection(AdminProvider provider) {
    final monthLabel = DateFormat('MMMM yyyy', 'id_ID').format(_fromDate);
    final rangeLabel =
        '${DateFormat('dd MMM yyyy', 'id_ID').format(_fromDate)} - '
        '${DateFormat('dd MMM yyyy', 'id_ID').format(_toDate)}';

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Branch scope — MANAGER only (dropdown). Other roles are locked to
        // their own branch by the backend.
        if (provider.isManager)
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<String>(
              initialValue: _branchFilter,
              isDense: true,
              isExpanded: true,
              iconSize: 18,
              selectedItemBuilder: (context) => [
                const Text(
                  'Semua Cabang',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                ...provider.branchOptions.map(
                  (b) => Text(
                    b.nama,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              decoration: const InputDecoration(
                labelText: 'Cabang',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
              ),
              items: [
                const DropdownMenuItem(value: '', child: Text('Semua Cabang')),
                ...provider.branchOptions.map(
                  (b) => DropdownMenuItem(
                    value: b.code,
                    child: Text(b.nama, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() => _branchFilter = value ?? '');
                _loadData();
              },
            ),
          ),
        // Monthly picker
        OutlinedButton.icon(
          onPressed: _pickMonth,
          icon: const Icon(Icons.calendar_month, size: 18),
          label: Text(_useCustomRange ? rangeLabel : monthLabel),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryLight,
            backgroundColor: AppColors.primaryLight.withValues(alpha: 0.08),
            side: BorderSide(
              color: AppColors.primaryLight.withValues(alpha: 0.4),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
        // Custom range toggle
        TextButton.icon(
          onPressed: _pickCustomRange,
          icon: const Icon(Icons.date_range, size: 18),
          label: const Text('Custom Range'),
          style: TextButton.styleFrom(
            foregroundColor: _useCustomRange
                ? Colors.white
                : AppColors.textMuted,
            backgroundColor: _useCustomRange ? AppColors.primaryLight : null,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _statusChip(String label, bool selected, VoidCallback onTap) {
    return AppChoiceChip(
      label: label,
      selected: selected,
      dense: true,
      onSelected: onTap,
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

    final allRows = provider.supplierPerformance;
    if (allRows.isEmpty) {
      final err = provider.supplierPerformanceError;
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: Text(
            err != null
                ? 'Gagal memuat data supplier: $err'
                : 'Belum ada data supplier untuk periode ini.',
            style: TextStyle(
              color: err != null ? AppColors.error : AppColors.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final rows = _supplierActiveFilter == null
        ? allRows
        : allRows.where((r) => r.isActive == _supplierActiveFilter).toList();

    final canEdit = provider.isManager || provider.isSupervisor;
    // MANAGER global (branch=null) harus pilih cabang dulu sebelum set target;
    // SUPERVISOR selalu branch-scoped dari token.
    final editBranch = provider.isManager
        ? (_branchFilter.isEmpty ? null : _branchFilter)
        : provider.userBranch;

    // Pagination
    final totalPages = ((rows.length - 1) / _supplierPageSize).ceil().clamp(
      1,
      999999,
    );
    final safePage = _supplierPage.clamp(1, totalPages);
    final start = (safePage - 1) * _supplierPageSize;
    final pageRows = rows.skip(start).take(_supplierPageSize).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _statusChip('Semua', _supplierActiveFilter == null, () {
              setState(() {
                _supplierActiveFilter = null;
                _supplierPage = 1;
              });
            }),
            _statusChip('Aktif', _supplierActiveFilter == true, () {
              setState(() {
                _supplierActiveFilter = true;
                _supplierPage = 1;
              });
            }),
            _statusChip('Non-Aktif', _supplierActiveFilter == false, () {
              setState(() {
                _supplierActiveFilter = false;
                _supplierPage = 1;
              });
            }),
            Text(
              '${rows.length} dari ${allRows.length} supplier',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, tableConstraints) {
            // Desktop: full width. Mobile: min 560 so columns stay readable,
            // horizontal scroll handles the rest.
            final avail = tableConstraints.maxWidth - 2;
            final tableWidth = avail < 560 ? 560.0 : avail;
            return Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                border: Border.all(color: AppColors.border),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: Table(
                    columnWidths: const {
                      0: FlexColumnWidth(3),
                      1: FlexColumnWidth(2),
                      2: FlexColumnWidth(2),
                      3: FlexColumnWidth(1.5),
                      4: FixedColumnWidth(56),
                    },
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    children: [
                      TableRow(
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: AppColors.border,
                              width: 1,
                            ),
                          ),
                        ),
                        children: [
                          const _TableHeaderCell(
                            'Supplier',
                            align: TextAlign.left,
                          ),
                          const _TableHeaderCell(
                            'Target',
                            align: TextAlign.right,
                          ),
                          const _TableHeaderCell(
                            'Value',
                            align: TextAlign.right,
                          ),
                          const _TableHeaderCell(
                            'Pencapaian',
                            align: TextAlign.right,
                          ),
                          const _TableHeaderCell(''),
                        ],
                      ),
                      ...pageRows.map((row) {
                        final pencapaianText = row.pencapaian == null
                            ? '—'
                            : '${row.pencapaian!.toStringAsFixed(0)}%';
                        Color pencapaianColor = AppColors.textMuted;
                        FontWeight pencapaianWeight = FontWeight.normal;
                        if (row.pencapaian != null) {
                          if (row.pencapaian! >= 100) {
                            pencapaianColor = AppColors.success;
                            pencapaianWeight = FontWeight.bold;
                          } else if (row.pencapaian! >= 81) {
                            pencapaianColor = AppColors.warning;
                          } else {
                            pencapaianColor = AppColors.error;
                          }
                        }
                        return TableRow(
                          children: [
                            _TableBodyCell(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    row.supplierName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: row.isActive
                                          ? AppColors.textPrimary
                                          : AppColors.textMuted,
                                    ),
                                  ),
                                  if (!row.isActive ||
                                      !row.isMaster ||
                                      row.orderType == '4P')
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Wrap(
                                        spacing: 4,
                                        children: [
                                          if (!row.isActive)
                                            _badge(
                                              'Non-Aktif',
                                              AppColors.error,
                                            ),
                                          if (!row.isMaster)
                                            _badge(
                                              'Tanpa Master',
                                              AppColors.warning,
                                            ),
                                          if (row.orderType == '4P')
                                            _badge(
                                              '4P',
                                              AppColors.primaryLight,
                                            ),
                                        ],
                                      ),
                                    ),
                                ],
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
                                      tooltip: editBranch == null
                                          ? 'Pilih cabang dulu untuk edit target'
                                          : 'Edit target',
                                      onPressed: editBranch == null
                                          ? null
                                          : () => _openTargetDialog(
                                              provider,
                                              row,
                                              editBranch,
                                            ),
                                    )
                                  : const SizedBox.shrink(),
                              align: TextAlign.center,
                            ),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(12),
            ),
            border: Border(
              left: BorderSide(color: AppColors.border),
              right: BorderSide(color: AppColors.border),
              bottom: BorderSide(color: AppColors.border),
            ),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Total: ${rows.length} supplier',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton(
                    onPressed: safePage > 1
                        ? () => setState(() => _supplierPage = safePage - 1)
                        : null,
                    child: const Icon(Icons.chevron_left),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Halaman $safePage dari $totalPages',
                    style: AppTextStyles.bodySmall,
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: safePage < totalPages
                        ? () => setState(() => _supplierPage = safePage + 1)
                        : null,
                    child: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openTargetDialog(
    AdminProvider provider,
    SupplierPerformanceRow row,
    String branch,
  ) async {
    final ym = _yearMonth(_fromDate);
    await showSupplierTargetEditDialog(
      context,
      provider,
      supplierName: row.supplierName,
      branch: branch,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'Urutkan:',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                      AppChoiceChip(
                        label: 'Revenue',
                        selected: sortBy == 'revenue',
                        onSelected: () =>
                            provider.setPerformanceSort('revenue'),
                      ),
                      AppChoiceChip(
                        label: 'Order',
                        selected: sortBy == 'order_count',
                        onSelected: () =>
                            provider.setPerformanceSort('order_count'),
                      ),
                    ],
                  ),
                ),
                // Table header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: const BoxDecoration(
                    color: AppColors.borderLight,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(11),
                      topRight: Radius.circular(11),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        flex: 2,
                        child: Text('Nama', style: _thStyle),
                      ),
                      const Expanded(
                        child: Text('Tipe Target', style: _thStyle),
                      ),
                      const Expanded(
                        child: Text('Nilai Target', style: _thStyle),
                      ),
                      const Expanded(child: Text('Incentive', style: _thStyle)),
                      const SizedBox(
                        width: 100,
                        child: Text('Aksi', style: _thStyle),
                      ),
                    ],
                  ),
                ),
                // Rows
                ...sorted.map((perf) {
                  final target = provider.getTargetFor(
                    perf.userId,
                    currentPeriod,
                  );
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppColors.border),
                      ),
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
                                ? (target.isRevenue
                                      ? _fmt(target.targetValue)
                                      : target.targetValue.toString())
                                : '-',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            target != null ? _fmt(target.incentiveAmount) : '-',
                            style: TextStyle(
                              fontSize: 13,
                              color:
                                  target != null && target.incentiveAmount > 0
                                  ? AppColors.success
                                  : AppColors.textMuted,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 100,
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
    final targetType = (existing?.isRevenue ?? false)
        ? 'REVENUE'
        : 'ORDER_COUNT';
    final targetValueController = TextEditingController(
      text: existing?.targetValue.toString() ?? '',
    );
    final incentiveController = TextEditingController(
      text: existing?.incentiveAmount.toString() ?? '0',
    );
    final selectedType = ValueNotifier<String>(targetType);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => ResponsiveAlertDialog(
        title: Text(
          existing == null
              ? 'Set Target untuk ${perf.displayName}'
              : 'Edit Target ${perf.displayName}',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Periode: $currentPeriod',
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            const Text(
              'Tipe Target',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<String>(
              valueListenable: selectedType,
              builder: (_, val, _) => Row(
                children: [
                  AppChoiceChip(
                    label: 'Order Count',
                    selected: val == 'ORDER_COUNT',
                    onSelected: () => selectedType.value = 'ORDER_COUNT',
                  ),
                  const SizedBox(width: 8),
                  AppChoiceChip(
                    label: 'Revenue',
                    selected: val == 'REVENUE',
                    onSelected: () => selectedType.value = 'REVENUE',
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
            content: Text(
              ok ? 'Target berhasil disimpan' : 'Gagal menyimpan target',
            ),
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
